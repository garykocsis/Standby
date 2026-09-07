// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../../src/demo/ActorAwareTestRouter.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseAuthenticBackingTest} from "../shared/BaseAuthenticBackingTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for F6B O3 enforcement against an authentic positive Aggregate Capacity
///         Obligation (G6B-1 through G6B-21).
/// @dev This is the central Standby economic claim, proven on the real execution stack: shared AMM
///      liquidity can back a future execution obligation without being reserved, so ordinary use that
///      remains compatible with the obligation proceeds untouched and only use that would destroy the
///      backing is refused.
///
///      Every obligation here is authentic. It is created by the production `establishCommitment`
///      transition, from the canonical bootstrap state, through the trusted authority — never by a setter,
///      a harness, a direct storage write, or a fabricated aggregate. Every transition attempt is a real
///      Uniswap v4 pool transition through the trusted perimeter and the real pinned `PoolManager`.
///
///      Two independent yardsticks are used throughout, because a comparison of the production derivation
///      against itself would prove nothing. The frozen canonical expectations — 80,000 / 65,000 / 45,000
///      MockUSDC — come from `demo-spec.md` and are asserted directly. And both live derivations are
///      cross-checked against `ReferenceCalculations`, which recomputes Supporting Capacity from
///      authoritative PoolManager state and Aggregate Capacity Obligation from the persisted commitment
///      facts.
///
///      The rejections are matched on the exact `(prospectiveCapacity, obligation)` pair the Hook
///      compared, so a refusal cannot be credited to backing when it was really eligibility, allowance,
///      balance, slippage, topology, the service domain, or an unrelated v4 failure.
contract O3AuthenticBackingEnforcementTest is BaseAuthenticBackingTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The protected exact-output request that lands prospective capacity exactly on the canonical
    ///      obligation: 80,000 - 30,000 = 50,000 MockUSDC.
    uint256 internal constant EQUALITY_BOUNDARY_SWAP_OUTPUT = 30_000_000_000;

    /// @dev The protected exact-output request that leaves prospective capacity at 40,000 MockUSDC.
    uint256 internal constant AGGREGATE_DESTRUCTIVE_SWAP_OUTPUT = 40_000_000_000;

    /// @dev The prospective Supporting Capacity that request implies: 80,000 - 40,000 MockUSDC.
    uint256 internal constant EXPECTED_AGGREGATE_DESTRUCTIVE_S = 40_000_000_000;

    /// @dev Three authentic commitments whose entitlements are individually far below the capacity a
    ///      destructive transition would leave, and whose aggregate is not.
    uint128 internal constant AGGREGATE_Q_ONE = 20_000_000_000;
    uint128 internal constant AGGREGATE_Q_TWO = 15_000_000_000;
    uint128 internal constant AGGREGATE_Q_THREE = 10_000_000_000;

    /// @dev The aggregate those three commitments establish: 45,000 MockUSDC.
    uint256 internal constant EXPECTED_AGGREGATE_O = 45_000_000_000;

    /// @dev An eighth of the canonical position: leaves seven eighths active, so 70,000 MockUSDC.
    uint128 internal constant SAFE_REMOVAL_LIQUIDITY = StandbyFixtureConfig.CANONICAL_LIQUIDITY / 8;

    /// @dev The Supporting Capacity that removal leaves behind.
    uint256 internal constant EXPECTED_SAFE_REMOVAL_S = 70_000_000_000;

    /// @dev Three eighths of the canonical position: leaves five eighths active, so exactly the canonical
    ///      obligation of 50,000 MockUSDC.
    uint128 internal constant BOUNDARY_REMOVAL_LIQUIDITY = (StandbyFixtureConfig.CANONICAL_LIQUIDITY * 3) / 8;

    /// @dev Half the canonical position: leaves half active, so 40,000 MockUSDC.
    uint128 internal constant DESTRUCTIVE_REMOVAL_LIQUIDITY = StandbyFixtureConfig.CANONICAL_LIQUIDITY / 2;

    /// @dev The Supporting Capacity that removal would leave behind.
    uint256 internal constant EXPECTED_DESTRUCTIVE_REMOVAL_S = 40_000_000_000;

    /// @dev A modest supplementary position, used where the question is admission rather than size.
    int256 internal constant SUPPLEMENTARY_LIQUIDITY = 1_000_000_000;

    /*//////////////////////////////////////////////////////////////
             G6B-1..2 — AUTHENTIC OBLIGATION, DERIVED IN PLACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the obligation ordinary transitions are measured against arises only from real O1.
    /// @dev Ordinary O3 activity of every enabled family runs first — a protected swap, an opposite-
    ///      direction swap, a liquidity addition, and a liquidity removal — and the obligation stays zero
    ///      through all of it. It becomes positive at exactly one point: the production admission
    ///      transition. Nothing else in the reachable system can produce a positive obligation, which is
    ///      what makes every later F6B result about an authentic one.
    function test_authenticObligation_arisesOnlyFromTheProductionAdmissionTransition() public {
        assertEq(hook.aggregateObligation(), 0, "no authentic commitment exists at the canonical bootstrap");
        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_INITIAL_S, "canonical bootstrap capacity");

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT));
        _swapAs(eligibleTrader, _oppositeSwapParams(1_000 * 10 ** 6));

        _modifyLiquidityAs(
            exitingProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            )
        );
        _modifyLiquidityAs(
            exitingProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, -SUPPLEMENTARY_LIQUIDITY
            )
        );

        assertEq(hook.aggregateObligation(), 0, "no ordinary O3 transition may create an obligation");
        assertEq(hook.nextCommitmentId(), 1, "no ordinary O3 transition may consume a commitment identity");

        uint256 commitmentId = _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "the production O1 transition is what makes the obligation positive"
        );
        assertGt(commitmentId, 0, "the admitted identity must be authentic");

        _assertDerivationsMatchOracles("production derivations must equal their independent reconstructions");
    }

    /*//////////////////////////////////////////////////////////////
                  G6B-4, G6B-7 — CANONICAL A2 / COMPATIBLE USE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the canonical compatible ordinary swap succeeds against a live 50,000 obligation.
    /// @dev Canonical A2, and the primary non-reservation proof. From `S = 80,000`, `O = 50,000`,
    ///      `Remaining = 50,000`, an ordinary trader with no relationship to the commitment asks the pool
    ///      for 15,000 MockUSDC and gets it. The outstanding obligation did not freeze the liquidity, did
    ///      not segregate it, and did not make the trader wait: it only bounded how far the shared resource
    ///      may be drawn down, and 65,000 is still comfortably inside that bound.
    ///
    ///      Every number is checked against the frozen canonical expectation rather than against the
    ///      derivation that produced it, and the commitment comes out of the transition byte-for-byte
    ///      unchanged.
    function test_canonicalA2_compatibleOrdinarySwap_succeedsAgainstAuthenticObligation() public {
        uint256 commitmentId = _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        _assertCanonicalA1State();

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);

        SwapParams memory params = _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT);

        assertEq(
            hook.prospectiveSupportingCapacityAfterSwap(params),
            StandbyFixtureConfig.EXPECTED_A2_S,
            "A2 must be predicted to leave S' = 65,000 MockUSDC"
        );
        assertGe(
            StandbyFixtureConfig.EXPECTED_A2_S,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "A2 must be a compatible transition: 65,000 >= 50,000"
        );

        uint256 traderOutputBefore = usdc.balanceOf(eligibleTrader);
        uint256 traderInputBefore = ustb.balanceOf(eligibleTrader);

        _swapAs(eligibleTrader, params);

        assertEq(
            usdc.balanceOf(eligibleTrader) - traderOutputBefore,
            StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT,
            "the ordinary trader must receive exactly the requested protected output"
        );
        assertLt(ustb.balanceOf(eligibleTrader), traderInputBefore, "the ordinary trader must have paid the input");

        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_A2_S, "A2 must end at S = 65,000 MockUSDC");
        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "an ordinary swap fulfils nothing, so O must remain 50,000 MockUSDC"
        );

        _assertDerivationsMatchOracles("A2 post-state derivations must equal their reconstructions");
        _assertCommitmentFactsUnchanged(commitmentId, admitted, "A2 must not touch any commitment fact");

        assertEq(hook.nextCommitmentId(), commitmentId + 1, "A2 must consume no commitment identity");
        assertEq(_occupiedReferenceCount(), 1, "A2 must not change the bounded enforcement index");
    }

    /// @notice Proves a successful ordinary swap leaves every commitment fact and every reference intact.
    /// @dev Fulfillment does not exist yet and must not appear by accident. A sequence of ordinary swaps in
    ///      both directions moves the pool repeatedly, and the commitment records, the bounded index, the
    ///      identity counter, and the derived obligation come out of it exactly as they went in.
    function test_successfulOrdinarySwaps_leaveEveryCommitmentFactIntact() public {
        uint256 first = _establish(AGGREGATE_Q_ONE);
        uint256 second = _establish(AGGREGATE_Q_TWO);

        StandbyHook.Commitment memory firstBefore = hook.commitment(first);
        StandbyHook.Commitment memory secondBefore = hook.commitment(second);

        uint256[MAX_LIVE_COMMITMENTS] memory referencesBefore = hook.enforcementReferences();
        uint256 obligationBefore = hook.aggregateObligation();

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT));
        _swapAs(eligibleTrader, _oppositeSwapParams(5_000 * 10 ** 6));
        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(1_000 * 10 ** 6));

        _assertCommitmentFactsUnchanged(first, firstBefore, "ordinary swaps must not touch commitment facts");
        _assertCommitmentFactsUnchanged(second, secondBefore, "ordinary swaps must not touch commitment facts");

        uint256[MAX_LIVE_COMMITMENTS] memory referencesAfter = hook.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(referencesAfter[slot], referencesBefore[slot], "ordinary swaps must not touch the bounded index");
        }

        assertEq(hook.aggregateObligation(), obligationBefore, "ordinary swaps must not reduce the obligation");
        assertEq(hook.nextCommitmentId(), second + 1, "ordinary swaps must consume no commitment identity");
    }

    /*//////////////////////////////////////////////////////////////
             G6B-5 — EXACT BOUNDARY, S' = O, MUST BE PERMITTED
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an ordinary swap that leaves capacity exactly equal to the obligation is permitted.
    /// @dev The boundary is proven directly rather than inferred from the strict cases either side of it.
    ///      Exact sufficiency preserves backing: the obligation can still be met in full from what remains,
    ///      so refusing the transition would deny ordinary use the frozen semantics allow.
    ///
    ///      Equality is established twice — as the prediction enforcement acted on, and as an authoritative
    ///      post-state fact re-derived from real PoolManager state after execution.
    function test_exactBoundarySwap_whereProspectiveCapacityEqualsTheObligation_isPermitted() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        _assertCanonicalA1State();

        SwapParams memory params = _protectedExactOutputSwapParams(EQUALITY_BOUNDARY_SWAP_OUTPUT);

        assertEq(
            hook.prospectiveSupportingCapacityAfterSwap(params),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "the boundary transition must be predicted to leave S' exactly equal to O"
        );

        _swapAs(eligibleTrader, params);

        assertEq(
            hook.supportingCapacity(),
            hook.aggregateObligation(),
            "the permitted boundary transition must end with S exactly equal to O"
        );
        assertEq(
            hook.supportingCapacity(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "and that common value must be the canonical 50,000 MockUSDC"
        );

        _assertDerivationsMatchOracles("boundary post-state derivations must equal their reconstructions");
    }

    /// @notice Proves one raw unit beyond the boundary is refused, for insufficient backing.
    /// @dev The complement of the equality case, and what makes it sharp: a single additional raw unit of
    ///      requested output takes prospective capacity one unit below the obligation, and the transition
    ///      is refused on exactly that pair.
    function test_oneRawUnitBeyondTheBoundary_isRejectedForInsufficientBacking() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        SwapParams memory params = _protectedExactOutputSwapParams(EQUALITY_BOUNDARY_SWAP_OUTPUT + 1);

        _expectBackingRejection(
            IHooks.beforeSwap.selector,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q - 1,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
        _swapAs(eligibleTrader, params);

        assertEq(
            hook.supportingCapacity(),
            StandbyFixtureConfig.EXPECTED_INITIAL_S,
            "the refused transition must leave capacity untouched"
        );
    }

    /*//////////////////////////////////////////////////////////////
          G6B-6, G6B-8, G6B-9 — CANONICAL A3 / DESTRUCTIVE USE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the canonical destructive ordinary swap is refused, specifically for backing.
    /// @dev Canonical A3, executed from the authoritative state canonical A2 actually left behind rather
    ///      than from a reconstructed one. The request is otherwise entirely valid — eligible trader,
    ///      trusted perimeter, funded, approved, inside the service domain, no slippage constraint — and it
    ///      is refused because the 45,000 MockUSDC it would leave cannot support the 50,000 MockUSDC the
    ///      service already owes.
    ///
    ///      The prospective 45,000 is asserted as a prediction and then proven never to have become
    ///      authoritative: after the revert the service still stands at the canonical A2 state.
    function test_canonicalA3_destructiveOrdinarySwap_isRejectedForInsufficientBacking() public {
        uint256 commitmentId = _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT));

        _assertCanonicalA2State();

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);

        SwapParams memory params = _protectedExactOutputSwapParams(StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT);

        assertEq(
            hook.prospectiveSupportingCapacityAfterSwap(params),
            StandbyFixtureConfig.EXPECTED_A3_PROSPECTIVE_S,
            "A3 must be predicted to leave S' = 45,000 MockUSDC"
        );
        assertLt(
            StandbyFixtureConfig.EXPECTED_A3_PROSPECTIVE_S,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "A3 must be a destructive transition: 45,000 < 50,000"
        );

        AdmissionState memory before = _admissionState();

        uint256 traderInputBefore = ustb.balanceOf(eligibleTrader);
        uint256 traderOutputBefore = usdc.balanceOf(eligibleTrader);

        _expectBackingRejection(
            IHooks.beforeSwap.selector,
            StandbyFixtureConfig.EXPECTED_A3_PROSPECTIVE_S,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
        _swapAs(eligibleTrader, params);

        _assertNoAdmissionResidue(before, "a refused A3 must leave no authoritative residue");
        _assertActorBalancesUnchanged(eligibleTrader, traderInputBefore, traderOutputBefore);
        _assertCommitmentFactsUnchanged(commitmentId, admitted, "a refused A3 must not touch any commitment fact");

        _assertCanonicalA2State();
    }

    /// @notice Proves the same trader's compatible request still succeeds after the destructive refusal.
    /// @dev The refusal is a bound on the transition, not a ban on the actor or a freeze on the pool. The
    ///      identical trader, immediately afterwards, draws the largest output the obligation still leaves
    ///      room for and the pool serves it.
    function test_afterTheDestructiveRefusal_aCompatibleRequestBySameTraderStillSucceeds() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT));

        _expectBackingRejection(
            IHooks.beforeSwap.selector,
            StandbyFixtureConfig.EXPECTED_A3_PROSPECTIVE_S,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT));

        uint256 headroom = StandbyFixtureConfig.EXPECTED_A2_S - StandbyFixtureConfig.CANONICAL_COMMITMENT_Q;

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(headroom));

        assertEq(
            hook.supportingCapacity(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "the compatible remainder must be drawable down to exact sufficiency"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    G6B-11 — OPPOSITE-DIRECTION DOMAIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an ordinary opposite-direction swap remains permitted and increases capacity.
    function test_oppositeDirectionSwap_withAuthenticObligation_isPermittedAndIncreasesCapacity() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        uint256 capacityBefore = hook.supportingCapacity();

        _swapAs(eligibleTrader, _oppositeSwapParams(10_000 * 10 ** 6));

        assertGt(hook.supportingCapacity(), capacityBefore, "the opposite direction must add Supporting Capacity");
        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "adding capacity must not change the obligation"
        );

        _assertDerivationsMatchOracles("opposite-direction post-state derivations must match");
    }

    /// @notice Proves a domain-leaving opposite-direction swap is still refused under a live obligation.
    /// @dev The transition would improve backing, so no numeric comparison could refuse it. It is refused
    ///      because the state it would produce is one for which no authoritative Standby capacity exists at
    ///      all — a realization-domain requirement that a positive obligation neither creates nor relaxes.
    function test_oppositeDirectionSwap_leavingTheServiceDomain_isRejectedForDomainNotBacking() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        assertGt(hook.aggregateObligation(), 0, "the obligation must be positive for this to prove anything");

        AdmissionState memory before = _admissionState();

        SwapParams memory params = _swapParams(false, -int256(300_000 * 10 ** 6), StandbyFixtureConfig.LP_TICK_UPPER);

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProspectivePriceOutsideServiceDomain.selector,
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.LP_TICK_UPPER),
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q),
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_O)
            )
        );
        _swapAs(eligibleTrader, params);

        _assertNoAdmissionResidue(before, "a refused domain-leaving swap must leave no authoritative residue");
    }

    /*//////////////////////////////////////////////////////////////
                 G6B-12..15 — LIQUIDITY REMOVAL UNDER LIVE O
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a safe liquidity removal succeeds while a real obligation is outstanding.
    /// @dev The provider withdraws an eighth of the canonical position, leaving 70,000 MockUSDC of
    ///      Supporting Capacity against a 50,000 MockUSDC obligation. Backing survives, so the exit is
    ///      permitted: an outstanding commitment binds the pool's capacity, not the provider's capital.
    function test_safeLiquidityRemoval_withAuthenticObligation_isPermitted() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        ModifyLiquidityParams memory removal = _canonicalRemovalParams(SAFE_REMOVAL_LIQUIDITY);

        assertEq(
            hook.prospectiveSupportingCapacityAfterLiquidityRemoval(removal),
            EXPECTED_SAFE_REMOVAL_S,
            "the safe removal must be predicted to leave S' = 70,000 MockUSDC"
        );

        uint256 providerInputBefore = ustb.balanceOf(canonicalProvider);

        _modifyLiquidityAs(canonicalProvider, removal);

        assertEq(hook.supportingCapacity(), EXPECTED_SAFE_REMOVAL_S, "the removal must end at S = 70,000 MockUSDC");
        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "a removal fulfils nothing, so O must remain 50,000 MockUSDC"
        );
        assertGt(ustb.balanceOf(canonicalProvider), providerInputBefore, "the provider must receive the position back");

        _assertDerivationsMatchOracles("safe-removal post-state derivations must match");
    }

    /// @notice Proves a removal that lands capacity exactly on the obligation is permitted.
    /// @dev The removal boundary is proven directly, like the swap boundary: withdrawing three eighths of
    ///      the canonical position leaves exactly the 50,000 MockUSDC the service owes, and exact
    ///      sufficiency is sufficiency.
    function test_exactBoundaryLiquidityRemoval_whereProspectiveCapacityEqualsTheObligation_isPermitted() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        ModifyLiquidityParams memory removal = _canonicalRemovalParams(BOUNDARY_REMOVAL_LIQUIDITY);

        assertEq(
            hook.prospectiveSupportingCapacityAfterLiquidityRemoval(removal),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "the boundary removal must be predicted to leave S' exactly equal to O"
        );

        _modifyLiquidityAs(canonicalProvider, removal);

        assertEq(
            hook.supportingCapacity(),
            hook.aggregateObligation(),
            "the permitted boundary removal must end with S exactly equal to O"
        );
        assertEq(
            hook.supportingCapacity(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "and that common value must be the canonical 50,000 MockUSDC"
        );
    }

    /// @notice Proves a destructive liquidity removal is refused, specifically for backing.
    /// @dev Withdrawing half the canonical position would leave 40,000 MockUSDC against a 50,000 MockUSDC
    ///      obligation. Ordinary Uniswap behavior would permit it; Standby refuses it, and refuses it on
    ///      the backing comparison rather than on eligibility or topology, both of which this removal
    ///      satisfies.
    function test_destructiveLiquidityRemoval_isRejectedForInsufficientBacking() public {
        uint256 commitmentId = _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        ModifyLiquidityParams memory removal = _canonicalRemovalParams(DESTRUCTIVE_REMOVAL_LIQUIDITY);

        assertEq(
            hook.prospectiveSupportingCapacityAfterLiquidityRemoval(removal),
            EXPECTED_DESTRUCTIVE_REMOVAL_S,
            "the destructive removal must be predicted to leave S' = 40,000 MockUSDC"
        );

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);

        AdmissionState memory before = _admissionState();

        uint256 providerInputBefore = ustb.balanceOf(canonicalProvider);
        uint256 providerOutputBefore = usdc.balanceOf(canonicalProvider);

        _expectBackingRejection(
            IHooks.beforeRemoveLiquidity.selector,
            EXPECTED_DESTRUCTIVE_REMOVAL_S,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
        _modifyLiquidityAs(canonicalProvider, removal);

        _assertNoAdmissionResidue(before, "a refused removal must leave no authoritative residue");
        _assertActorBalancesUnchanged(canonicalProvider, providerInputBefore, providerOutputBefore);
        _assertCommitmentFactsUnchanged(commitmentId, admitted, "a refused removal must not touch a commitment fact");
    }

    /// @notice Proves a safe exit remains possible after the provider loses liquidity-action eligibility.
    /// @dev The mandatory sequence, now with a real obligation outstanding: contribute while eligible, lose
    ///      eligibility, withdraw an economically safe amount anyway. Permissioning governs introducing
    ///      liquidity; it must never become a lock on capital, and a live commitment does not turn it into
    ///      one. The same provider is then shown to be genuinely barred from adding, so the exit was not
    ///      succeeding because eligibility quietly survived.
    function test_safeLiquidityRemoval_afterProviderEligibilityLoss_stillExecutes() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        _setLiquidityEligibility(canonicalProvider, false);

        assertFalse(registry.canProvideLiquidity(canonicalProvider), "the provider must genuinely be ineligible");
        assertGt(hook.aggregateObligation(), 0, "the obligation must be positive for this to prove anything");

        uint256 providerInputBefore = ustb.balanceOf(canonicalProvider);
        uint256 providerOutputBefore = usdc.balanceOf(canonicalProvider);

        _modifyLiquidityAs(canonicalProvider, _canonicalRemovalParams(SAFE_REMOVAL_LIQUIDITY));

        assertGt(ustb.balanceOf(canonicalProvider), providerInputBefore, "the exiting provider must receive currency0");
        assertGt(usdc.balanceOf(canonicalProvider), providerOutputBefore, "the exiting provider must receive currency1");
        assertEq(hook.supportingCapacity(), EXPECTED_SAFE_REMOVAL_S, "the safe exit must reach authoritative state");

        _expectHookRejection(
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__LiquidityProviderNotEligible.selector, canonicalProvider)
        );
        _modifyLiquidityAs(
            canonicalProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            )
        );
    }

    /// @notice Proves an ineligible provider's destructive removal is still refused for backing.
    /// @dev Removal consults no eligibility predicate, so losing eligibility must not change which removals
    ///      are economically admissible in either direction. The refusal names the backing comparison, not
    ///      the provider.
    function test_destructiveLiquidityRemoval_afterEligibilityLoss_isStillRejectedForBacking() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        _setLiquidityEligibility(canonicalProvider, false);

        _expectBackingRejection(
            IHooks.beforeRemoveLiquidity.selector,
            EXPECTED_DESTRUCTIVE_REMOVAL_S,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
        _modifyLiquidityAs(canonicalProvider, _canonicalRemovalParams(DESTRUCTIVE_REMOVAL_LIQUIDITY));
    }

    /*//////////////////////////////////////////////////////////////
                    G6B-16 — LIQUIDITY ADDITION PRESERVED
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an eligible, topology-valid addition is permitted and changes no obligation.
    function test_liquidityAddition_withAuthenticObligation_isPermittedAndLeavesTheObligationAlone() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        uint256 capacityBefore = hook.supportingCapacity();

        _modifyLiquidityAs(
            exitingProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            )
        );

        assertGt(hook.supportingCapacity(), capacityBefore, "an active addition must increase Supporting Capacity");
        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "improving backing must not change the obligation"
        );

        _assertDerivationsMatchOracles("post-addition derivations must match");
    }

    /// @notice Proves an ineligible provider's addition is refused even though it would improve backing.
    function test_liquidityAddition_byIneligibleProvider_isStillRejectedUnderAuthenticObligation() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        AdmissionState memory before = _admissionState();

        _expectHookRejection(
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__LiquidityProviderNotEligible.selector, ineligibleProvider)
        );
        _modifyLiquidityAs(
            ineligibleProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            )
        );

        _assertNoAdmissionResidue(before, "a refused addition must leave no authoritative residue");
    }

    /// @notice Proves an interior liquidity boundary is refused even though the addition would improve
    ///         backing.
    /// @dev A positive obligation makes the topology requirement more important, not less: the
    ///      single-active-region basis is what makes the obligation's own backing derivable.
    function test_liquidityAddition_withAnInteriorBoundary_isStillRejectedUnderAuthenticObligation() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        _expectHookRejection(
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProhibitedInteriorLiquidityBoundary.selector,
                int24(-100),
                StandbyFixtureConfig.LP_TICK_UPPER
            )
        );
        _modifyLiquidityAs(
            exitingProvider, _liquidityParams(-100, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY)
        );
    }

    /*//////////////////////////////////////////////////////////////
                            G6B-17 — EXPIRY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves expiry releases the obligation purely by derivation, without touching Remaining.
    /// @dev No transaction is sent to expire anything: the obligation is recomputed from the recorded facts
    ///      and the current time on every use, so it is 50,000 MockUSDC one second before `validUntil` and
    ///      zero at `validUntil` itself. The commitment record is unchanged across that boundary —
    ///      Remaining Entitlement in particular — because expiry changes what the facts mean and not the
    ///      facts.
    ///
    ///      The economic consequence is then proven behaviorally: the transition that was refused for
    ///      insufficient backing while the commitment was live is permitted once it is not.
    function test_expiry_releasesTheObligationByDerivationWithoutChangingRemaining() public {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        uint256 commitmentId =
            _establishWithWindow(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q), exercisableFrom, validUntil);

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);

        vm.warp(uint256(validUntil) - 1);

        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "the obligation must survive to the last instant of validity"
        );
        _assertDerivationsMatchOracles("pre-expiry derivations must match");

        _expectBackingRejection(
            IHooks.beforeSwap.selector, EXPECTED_AGGREGATE_DESTRUCTIVE_S, StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(AGGREGATE_DESTRUCTIVE_SWAP_OUTPUT));

        vm.warp(uint256(validUntil));

        assertEq(hook.aggregateObligation(), 0, "validity is half-open, so O must be zero at validUntil");
        _assertCommitmentFactsUnchanged(commitmentId, admitted, "expiry must not rewrite any commitment fact");
        assertEq(
            uint256(hook.commitment(commitmentId).remainingEntitlement),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "expiry must leave Remaining Entitlement at 50,000 MockUSDC"
        );
        _assertDerivationsMatchOracles("post-expiry derivations must match");

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(AGGREGATE_DESTRUCTIVE_SWAP_OUTPUT));

        assertEq(
            hook.supportingCapacity(),
            EXPECTED_AGGREGATE_DESTRUCTIVE_S,
            "the transition refused while the obligation was live must now execute"
        );
        assertEq(
            uint256(hook.commitment(commitmentId).remainingEntitlement),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "and it must still not touch Remaining Entitlement"
        );
    }

    /*//////////////////////////////////////////////////////////////
                  G6B-18 — BENEFICIARY INELIGIBILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves losing Beneficiary eligibility neither reduces the obligation nor lifts protection.
    /// @dev Eligibility governs who may receive protected service; it is not a release from an obligation
    ///      already outstanding. If it were, an administrator could strand a Beneficiary and free the
    ///      shared liquidity in the same action. The destructive transition is therefore still refused, on
    ///      exactly the same pair, and Remaining Entitlement is untouched throughout.
    function test_beneficiaryIneligibility_neitherReducesTheObligationNorRemovesProtection() public {
        uint256 commitmentId = _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);

        _setBeneficiaryEligibility(beneficiary, false);

        assertFalse(registry.canReceiveProtectedService(beneficiary), "the Beneficiary must genuinely be ineligible");
        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "ineligibility must not release the obligation"
        );
        _assertCommitmentFactsUnchanged(commitmentId, admitted, "ineligibility must not rewrite a commitment fact");

        _expectBackingRejection(
            IHooks.beforeSwap.selector, EXPECTED_AGGREGATE_DESTRUCTIVE_S, StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(AGGREGATE_DESTRUCTIVE_SWAP_OUTPUT));

        _setBeneficiaryEligibility(beneficiary, true);

        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "restoring eligibility must not change the obligation either"
        );
        _assertDerivationsMatchOracles("derivations must be indifferent to Beneficiary eligibility");
    }

    /*//////////////////////////////////////////////////////////////
             G6B-20 — F6A STRUCTURAL BEHAVIOR UNDER A LIVE O
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an untrusted perimeter still cannot authorize a transition under a live obligation.
    /// @dev The perimeter is a byte-identical copy of the trusted one carrying a genuinely eligible
    ///      originating user, and the requested swap is comfortably within backing. It is refused on the
    ///      identity of the perimeter alone, before any economics are consulted — a positive obligation
    ///      neither strengthens nor weakens that.
    function test_untrustedPerimeter_isStillRefusedUnderAuthenticObligation() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        ActorAwareTestRouter untrustedPerimeter = new ActorAwareTestRouter(poolManager);

        vm.startPrank(eligibleTrader);
        ustb.approve(address(untrustedPerimeter), type(uint256).max);
        usdc.approve(address(untrustedPerimeter), type(uint256).max);
        vm.stopPrank();

        AdmissionState memory before = _admissionState();

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__UntrustedSwapPerimeter.selector, address(untrustedPerimeter)
            )
        );
        vm.prank(eligibleTrader);
        untrustedPerimeter.swap(
            servicePoolKey,
            _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT),
            bytes("")
        );

        _assertNoAdmissionResidue(before, "a refused untrusted transition must leave no authoritative residue");
    }

    /// @notice Proves a forged hook payload still cannot establish the actor under a live obligation.
    /// @dev The payload names an eligible trader and arrives through the genuinely trusted perimeter. The
    ///      authoritative actor stays the one the perimeter authenticated, so the transition is refused
    ///      under that actor's own eligibility rather than the claimed one's.
    function test_forgedHookData_stillCannotEstablishTheActorUnderAuthenticObligation() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__TraderNotEligible.selector, ineligibleTrader)
        );
        _swapAs(
            ineligibleTrader,
            _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT),
            abi.encode(eligibleTrader)
        );
    }

    /// @notice Proves permissioning and backing stay distinct refusals under a live obligation.
    /// @dev The same fully backed request is refused for eligibility when an ineligible trader makes it and
    ///      admitted when an eligible one does; the same eligible trader is then refused for backing on a
    ///      destructive request. Neither reason is ever reported in place of the other, so an operator
    ///      cannot mistake a permission problem for an economic one or the reverse.
    function test_permissioningAndBackingRemainDistinctRefusals() public {
        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        SwapParams memory compatible =
            _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT);

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__TraderNotEligible.selector, ineligibleTrader)
        );
        _swapAs(ineligibleTrader, compatible);

        _expectBackingRejection(
            IHooks.beforeSwap.selector, EXPECTED_AGGREGATE_DESTRUCTIVE_S, StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(AGGREGATE_DESTRUCTIVE_SWAP_OUTPUT));

        _swapAs(eligibleTrader, compatible);

        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_A2_S, "the compatible request must execute");
    }

    /*//////////////////////////////////////////////////////////////
                      G6B-19 — AGGREGATE OBLIGATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves enforcement protects the aggregate obligation, not any single commitment.
    /// @dev Three authentic commitments are admitted, none larger than 20,000 MockUSDC. A transition that
    ///      would leave 40,000 MockUSDC comfortably covers every one of them individually and is refused
    ///      anyway, because together they oblige 45,000. A transition that leaves 50,000 is permitted. The
    ///      obligation the Hook compared is named in the refusal, so the aggregate is proven to be the
    ///      quantity enforcement actually used.
    function test_aggregateObligation_ofMultipleAuthenticCommitments_isWhatEnforcementProtects() public {
        uint256 first = _establish(AGGREGATE_Q_ONE);
        uint256 second = _establish(AGGREGATE_Q_TWO);
        uint256 third = _establishAs(
            establishmentAuthority,
            secondBeneficiary,
            commitmentExerciseAuthority,
            AGGREGATE_Q_THREE,
            uint64(block.timestamp) + DEFAULT_EXERCISE_DELAY,
            uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION
        );

        assertEq(hook.aggregateObligation(), EXPECTED_AGGREGATE_O, "three authentic commitments must oblige 45,000");
        assertEq(hook.commitmentObligation(first), uint256(AGGREGATE_Q_ONE), "the largest single obligation is 20,000");
        assertEq(hook.commitmentObligation(second), uint256(AGGREGATE_Q_TWO), "the second obligation is 15,000");
        assertEq(hook.commitmentObligation(third), uint256(AGGREGATE_Q_THREE), "the third obligation is 10,000");
        assertEq(_occupiedReferenceCount(), 3, "each admission must occupy its own bounded reference");

        _assertDerivationsMatchOracles("the aggregate must equal its independent reconstruction");

        assertGt(
            EXPECTED_AGGREGATE_DESTRUCTIVE_S,
            uint256(AGGREGATE_Q_ONE),
            "the destructive transition must be safe against every single commitment"
        );

        AdmissionState memory before = _admissionState();

        _expectBackingRejection(IHooks.beforeSwap.selector, EXPECTED_AGGREGATE_DESTRUCTIVE_S, EXPECTED_AGGREGATE_O);
        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(AGGREGATE_DESTRUCTIVE_SWAP_OUTPUT));

        _assertNoAdmissionResidue(before, "the refused aggregate transition must leave no residue");

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(EQUALITY_BOUNDARY_SWAP_OUTPUT));

        assertEq(
            hook.supportingCapacity(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "a transition that keeps capacity above the aggregate must be permitted"
        );
        assertEq(hook.aggregateObligation(), EXPECTED_AGGREGATE_O, "and must leave the aggregate alone");
    }

    /// @notice Proves the aggregate shrinks by derivation as its members expire, one at a time.
    /// @dev The transition refused against 45,000 is still refused against 25,000 and permitted once the
    ///      aggregate falls to 10,000, with no transaction sent to release anything and no Remaining
    ///      Entitlement touched.
    function test_aggregateObligation_shrinksByDerivationAsMembersExpire() public {
        uint64 shortValidity = uint64(block.timestamp) + 1 days;
        uint64 longValidity = uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION;

        _establishWithWindow(AGGREGATE_Q_ONE, uint64(block.timestamp) + DEFAULT_EXERCISE_DELAY, shortValidity);
        _establishWithWindow(AGGREGATE_Q_TWO, uint64(block.timestamp) + DEFAULT_EXERCISE_DELAY, shortValidity);
        uint256 third =
            _establishWithWindow(AGGREGATE_Q_THREE, uint64(block.timestamp) + DEFAULT_EXERCISE_DELAY, longValidity);

        assertEq(hook.aggregateObligation(), EXPECTED_AGGREGATE_O, "the initial aggregate must be 45,000");

        vm.warp(uint256(shortValidity));

        assertEq(
            hook.aggregateObligation(), uint256(AGGREGATE_Q_THREE), "only the surviving commitment may still contribute"
        );
        _assertDerivationsMatchOracles("the shrunken aggregate must equal its independent reconstruction");

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(AGGREGATE_DESTRUCTIVE_SWAP_OUTPUT));

        assertEq(
            hook.supportingCapacity(),
            EXPECTED_AGGREGATE_DESTRUCTIVE_S,
            "the transition must now be permitted against the reduced aggregate"
        );
        assertEq(
            uint256(hook.commitment(third).remainingEntitlement),
            uint256(AGGREGATE_Q_THREE),
            "no Remaining Entitlement may have moved"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Asserts the canonical post-A1 authoritative state, against frozen expectations and oracles.
    function _assertCanonicalA1State() internal view {
        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_INITIAL_S, "A1 state requires S = 80,000");
        assertEq(
            hook.aggregateObligation(), StandbyFixtureConfig.CANONICAL_COMMITMENT_Q, "A1 state requires O = 50,000"
        );
        assertEq(
            uint256(hook.commitment(1).remainingEntitlement),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "A1 state requires Remaining = 50,000"
        );

        _assertDerivationsMatchOracles("A1 state derivations must equal their reconstructions");
    }

    /// @dev Asserts the canonical post-A2 authoritative state, against frozen expectations and oracles.
    function _assertCanonicalA2State() internal view {
        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_A2_S, "A2 state requires S = 65,000");
        assertEq(
            hook.aggregateObligation(), StandbyFixtureConfig.CANONICAL_COMMITMENT_Q, "A2 state requires O = 50,000"
        );
        assertEq(
            uint256(hook.commitment(1).remainingEntitlement),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "A2 state requires Remaining = 50,000"
        );

        _assertDerivationsMatchOracles("A2 state derivations must equal their reconstructions");
    }
}
