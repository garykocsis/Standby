// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {BaseAuthenticBackingTest} from "../shared/BaseAuthenticBackingTest.t.sol";
import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Focused fuzz evidence for the F6B backing decision boundary under an authentic live obligation
///         (G6B-23).
/// @dev The property under test is the whole F6B claim, stated as a biconditional rather than as two
///      one-sided examples: a backing-affecting ordinary transition becomes authoritative if and only if
///      the Supporting Capacity it would leave behind still covers the Aggregate Capacity Obligation.
///
///      Both sides of that comparison are supplied independently on every run. The obligation is
///      reconstructed by `ReferenceCalculations` from the persisted commitment facts, and the prospective
///      capacity is stated from the frozen canonical geometry rather than obtained from the derivation
///      under test:
///
///      - the canonical position spans the entire service domain as one constant-liquidity interval, so an
///        exact-output protected swap of `out` protected-currency units draws exactly `out` units out of
///        the capacity-bearing region, leaving `S - out` — and nothing at all once the request exceeds
///        what the domain can deliver, because the price limit is the protected boundary itself;
///      - a removal cannot move the price, so removing `delta` liquidity from an active domain-spanning
///        position leaves the same price with `L - delta` active, and the independent capacity oracle
///        measures that state directly.
///
///      Rejections are matched on the exact `(prospectiveCapacity, obligation)` pair, so a run that
///      expects a refusal only passes when the Hook refused for the independently predicted reason and on
///      the independently predicted numbers. Accepted runs are checked against authoritative post-state.
///
///      The generated amounts are deliberately biased toward the decision boundary — half the runs aim
///      within a few raw units of exact sufficiency — because that is the region where an off-by-one or an
///      inclusive/exclusive slip would live. Every generated case is otherwise valid: an eligible trader
///      or the canonical provider, the trusted perimeter, funded and approved, inside the service domain,
///      with no slippage constraint, so nothing unrelated can mask the backing result.
contract O3AuthenticBackingFuzzTest is BaseAuthenticBackingTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Upper bound on a fuzzed exact-output request. Larger than the whole service domain can
    ///      deliver, so runs reach the protected boundary as well as staying well inside it.
    uint256 internal constant MAX_FUZZED_OUTPUT = 120_000 * 10 ** 6;

    /// @dev The widest deliberate miss, in raw protected-output units, when a run aims at the boundary.
    int256 internal constant MAX_BOUNDARY_NUDGE = 3;

    /*//////////////////////////////////////////////////////////////
                        SWAP DECISION BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice An ordinary protected swap becomes authoritative exactly when the capacity it would leave
    ///         still covers the authentic aggregate obligation.
    /// @dev Up to three authentic commitments are admitted through production O1 first, so the obligation
    ///      the transition is measured against is a real aggregate rather than one selected commitment.
    ///      A permitted run must end at exactly the predicted capacity with the obligation and every
    ///      Remaining Entitlement untouched; a refused run must leave no authoritative residue at all.
    function testFuzz_protectedSwap_isAdmittedExactlyWhenProspectiveCapacityCoversTheObligation(
        uint128 _firstSeed,
        uint128 _secondSeed,
        uint128 _thirdSeed,
        uint256 _outputSeed,
        bool _aimAtBoundary,
        int8 _nudgeSeed
    ) public {
        uint256 obligation = _establishFuzzedCommitments(_firstSeed, _secondSeed, _thirdSeed);
        uint256 capacity = _referenceSupportingCapacity();

        uint256 amountOut = _boundedOutput(_outputSeed, _aimAtBoundary, _nudgeSeed, capacity, obligation);
        uint256 expectedProspective = amountOut >= capacity ? 0 : capacity - amountOut;

        SwapParams memory params = _protectedExactOutputSwapParams(amountOut);

        if (expectedProspective >= obligation) {
            _swapAs(eligibleTrader, params);

            assertEq(hook.supportingCapacity(), expectedProspective, "an admitted swap must leave the expected S");
            assertEq(_referenceSupportingCapacity(), expectedProspective, "reconstructed from authoritative state");
            assertEq(hook.aggregateObligation(), obligation, "an ordinary swap must not change the obligation");
            assertEq(_referenceAggregateObligation(), obligation, "reconstructed from the commitment facts");
        } else {
            AdmissionState memory before = _admissionState();

            uint256 inputBefore = ustb.balanceOf(eligibleTrader);
            uint256 outputBefore = usdc.balanceOf(eligibleTrader);

            _expectBackingRejection(IHooks.beforeSwap.selector, expectedProspective, obligation);
            _swapAs(eligibleTrader, params);

            _assertNoAdmissionResidue(before, "a refused swap must leave no authoritative residue");
            _assertActorBalancesUnchanged(eligibleTrader, inputBefore, outputBefore);
        }
    }

    /*//////////////////////////////////////////////////////////////
                      REMOVAL DECISION BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice A liquidity removal becomes authoritative exactly when the capacity it would leave still
    ///         covers the authentic aggregate obligation, whatever the provider's current eligibility is.
    /// @dev Liquidity-action eligibility is revoked on half the runs, between contributing and exiting.
    ///      Nothing about the outcome may depend on it: withdrawal is not a permissioned act, and a live
    ///      obligation must bound the exit economically without turning eligibility administration into a
    ///      capital trap.
    function testFuzz_liquidityRemoval_isAdmittedExactlyWhenProspectiveCapacityCoversTheObligation(
        uint128 _firstSeed,
        uint128 _secondSeed,
        uint128 _thirdSeed,
        uint256 _removalSeed,
        bool _aimAtBoundary,
        int8 _nudgeSeed,
        bool _revokeEligibility
    ) public {
        uint256 obligation = _establishFuzzedCommitments(_firstSeed, _secondSeed, _thirdSeed);

        if (_revokeEligibility) _setLiquidityEligibility(canonicalProvider, false);

        (uint160 sqrtPriceX96,, uint128 liquidityBefore) = _servicePoolState();

        uint128 removed =
            _boundedRemoval(_removalSeed, _aimAtBoundary, _nudgeSeed, sqrtPriceX96, liquidityBefore, obligation);

        uint256 expectedProspective = ReferenceCalculations.referenceSupportingCapacity(
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            sqrtPriceX96,
            StandbyFixtureConfig.TICK_Q,
            liquidityBefore - removed
        );

        ModifyLiquidityParams memory removal = _canonicalRemovalParams(removed);

        if (expectedProspective >= obligation) {
            _modifyLiquidityAs(canonicalProvider, removal);

            assertEq(hook.supportingCapacity(), expectedProspective, "an admitted removal must leave the expected S");
            assertEq(hook.aggregateObligation(), obligation, "a removal must not change the obligation");

            (,, uint128 liquidityAfter) = _servicePoolState();

            assertEq(
                uint256(liquidityAfter),
                uint256(liquidityBefore) - uint256(removed),
                "the removal must reach authoritative PoolManager state"
            );
        } else {
            AdmissionState memory before = _admissionState();

            _expectBackingRejection(IHooks.beforeRemoveLiquidity.selector, expectedProspective, obligation);
            _modifyLiquidityAs(canonicalProvider, removal);

            _assertNoAdmissionResidue(before, "a refused removal must leave no authoritative residue");
        }
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Admits up to three authentic commitments through the production O1 transition.
    ///
    ///      Each entitlement is bounded to a third of the canonical bootstrap capacity, so the aggregate
    ///      admission condition is always satisfiable and no run can be passing because admission itself
    ///      failed. The returned obligation is the independent reconstruction, not the Hook's own.
    function _establishFuzzedCommitments(uint128 _firstSeed, uint128 _secondSeed, uint128 _thirdSeed)
        internal
        returns (uint256 obligation)
    {
        uint256 maxEntitlement = StandbyFixtureConfig.EXPECTED_INITIAL_S / 3;

        _establish(uint128(_bound(uint256(_firstSeed), 1, maxEntitlement)));
        _establish(uint128(_bound(uint256(_secondSeed), 1, maxEntitlement)));
        _establishAs(
            establishmentAuthority,
            secondBeneficiary,
            commitmentExerciseAuthority,
            uint128(_bound(uint256(_thirdSeed), 1, maxEntitlement)),
            uint64(block.timestamp) + DEFAULT_EXERCISE_DELAY,
            uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION
        );

        obligation = _referenceAggregateObligation();

        assertGt(obligation, 0, "the fuzzed obligation must be authentically positive");
    }

    /// @dev Bounds a fuzzed exact-output request, optionally aiming it at the decision boundary.
    ///
    ///      Exact sufficiency is reached at `capacity - obligation` protected-output units, so a boundary
    ///      run asks for that plus a small signed miss and lands within a few raw units of the decision on
    ///      either side of it.
    function _boundedOutput(
        uint256 _outputSeed,
        bool _aimAtBoundary,
        int8 _nudgeSeed,
        uint256 _capacity,
        uint256 _obligation
    ) internal pure returns (uint256 amountOut) {
        if (!_aimAtBoundary) return _bound(_outputSeed, 1, MAX_FUZZED_OUTPUT);

        int256 aimed = int256(_capacity - _obligation) + _boundedNudge(_nudgeSeed);

        amountOut = aimed < int256(1) ? 1 : uint256(aimed);
    }

    /// @dev Bounds a fuzzed removal, optionally aiming it at the decision boundary.
    ///
    ///      The liquidity that would leave capacity exactly at the obligation is recovered from the frozen
    ///      capacity relation `S = L * (sqrtP - sqrtQ) / 2^96`, inverted for `L`. This chooses an input to
    ///      explore; the expected outcome is computed afterwards by the independent capacity oracle, so an
    ///      imprecise aim costs coverage and can never make a run pass.
    function _boundedRemoval(
        uint256 _removalSeed,
        bool _aimAtBoundary,
        int8 _nudgeSeed,
        uint160 _sqrtPriceX96,
        uint128 _liquidity,
        uint256 _obligation
    ) internal pure returns (uint128 removed) {
        if (!_aimAtBoundary) return uint128(_bound(_removalSeed, 1, uint256(_liquidity)));

        uint256 priceGap = uint256(_sqrtPriceX96) - uint256(TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q));

        uint256 boundaryLiquidity =
            priceGap == 0 ? 0 : FullMath.mulDiv(_obligation, ReferenceCalculations.Q96, priceGap);

        int256 aimed = int256(uint256(_liquidity)) - int256(boundaryLiquidity) - _boundedNudge(_nudgeSeed);

        if (aimed < int256(1)) return 1;
        if (aimed > int256(uint256(_liquidity))) return _liquidity;

        removed = uint128(uint256(aimed));
    }

    /// @dev Bounds a fuzzed deliberate miss to a few raw units either side of the decision boundary.
    function _boundedNudge(int8 _nudgeSeed) internal pure returns (int256 nudge) {
        nudge = bound(int256(_nudgeSeed), -MAX_BOUNDARY_NUDGE, MAX_BOUNDARY_NUDGE);
    }
}
