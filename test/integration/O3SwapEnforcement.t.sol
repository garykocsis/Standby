// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {ImmutableState} from "v4-periphery/src/base/ImmutableState.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../../src/demo/ActorAwareTestRouter.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseActorAwareStandbyTest} from "../shared/BaseActorAwareStandbyTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for ordinary O3 swap enforcement while the obligation is authentically zero.
/// @dev Everything here runs the real path end to end: an originating user, the trusted ordinary-swap
///      perimeter, the real pinned `PoolManager`, and the production `StandbyHook`. No harness participates,
///      because every claim made here is a claim about whether a real pool transition became authoritative.
///
///      Two things must be visible at once and are deliberately tested together. Valid ordinary activity is
///      positively permitted — a permissioned realization that quietly rejected everything would satisfy
///      every rejection test and be useless. And rejection is attributable: each refusal is matched against
///      the specific Standby reason, so a test cannot pass because of an unrelated allowance, balance, or
///      slippage failure.
contract O3SwapEnforcementTest is BaseActorAwareStandbyTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A moderate protected-direction input that stays well inside the service domain.
    uint256 internal constant ORDINARY_SWAP_INPUT = 10_000 * 10 ** 6;

    /// @dev An input large enough to reach whatever price limit the swap carries.
    uint256 internal constant DOMAIN_REACHING_INPUT = 300_000 * 10 ** 6;

    /*//////////////////////////////////////////////////////////////
                  G6A-11 — VALID ORDINARY SWAP PERMITTED
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an eligible trader's protected-direction ordinary swap becomes authoritative.
    /// @dev The complete F6A evidence path in one transaction: eligible actor, trusted perimeter,
    ///      transaction-local originator, real PoolManager dispatch, Hook authentication, `canSwap`, the F5
    ///      prospective derivation, the authentically derived zero obligation, the backing comparison, real
    ///      execution, and `afterSwap` completing without creating exercise semantics.
    ///
    ///      The prediction is taken before the transition and compared with authoritative post-transition
    ///      state afterwards, so this is also direct evidence that what enforcement decided on is what the
    ///      pool actually did.
    function test_protectedDirectionSwap_byEligibleTrader_becomesAuthoritative() public {
        assertEq(hook.aggregateObligation(), 0, "no authentic commitment can exist yet");
        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_INITIAL_S, "canonical bootstrap capacity");

        SwapParams memory params = _protectedSwapParams(ORDINARY_SWAP_INPUT);

        uint256 predictedCapacity = hook.prospectiveSupportingCapacityAfterSwap(params);

        (uint160 sqrtPriceBefore,, uint128 liquidityBefore) = _servicePoolState();

        uint256 usdcBefore = usdc.balanceOf(eligibleTrader);

        _swapAs(eligibleTrader, params);

        (uint160 sqrtPriceAfter,, uint128 liquidityAfter) = _servicePoolState();

        assertLt(sqrtPriceAfter, sqrtPriceBefore, "a protected-direction swap must move the authoritative price");
        assertEq(liquidityAfter, liquidityBefore, "an in-domain swap crosses no liquidity boundary");
        assertGt(usdc.balanceOf(eligibleTrader), usdcBefore, "the originating user must receive the output");

        assertEq(hook.supportingCapacity(), predictedCapacity, "post-state capacity must equal the F5 prediction");
        assertLt(predictedCapacity, StandbyFixtureConfig.EXPECTED_INITIAL_S, "the swap must actually consume capacity");
        assertEq(hook.aggregateObligation(), 0, "the obligation stays authentically derived and zero");
    }

    /// @notice Proves a valid opposite-direction ordinary swap is permitted and increases capacity.
    /// @dev Direction classification is not cosmetic: the same enforcement path measures the two directions
    ///      against the direction-relative capacity boundary, so an implementation that confused them could
    ///      not produce both this result and the protected-direction one above.
    function test_oppositeDirectionSwap_byEligibleTrader_becomesAuthoritative() public {
        SwapParams memory params = _oppositeSwapParams(ORDINARY_SWAP_INPUT);

        uint256 predictedCapacity = hook.prospectiveSupportingCapacityAfterSwap(params);

        (uint160 sqrtPriceBefore,,) = _servicePoolState();

        _swapAs(eligibleTrader, params);

        (uint160 sqrtPriceAfter,,) = _servicePoolState();

        assertGt(sqrtPriceAfter, sqrtPriceBefore, "an opposite-direction swap must move the price the other way");
        assertEq(hook.supportingCapacity(), predictedCapacity, "post-state capacity must equal the F5 prediction");
        assertGt(predictedCapacity, StandbyFixtureConfig.EXPECTED_INITIAL_S, "the opposite direction adds capacity");
    }

    /// @notice Proves a swap that exhausts capacity exactly at the boundary is still permitted.
    /// @dev Zero Supporting Capacity at `P_Q` is an ordinary valid domain state, not an invalid basis, and
    ///      exact sufficiency satisfies backing. A realization that refused this would reject behavior the
    ///      frozen semantics permit.
    function test_protectedDirectionSwap_toTheCapacityBoundary_isPermitted() public {
        SwapParams memory params = _protectedSwapParams(DOMAIN_REACHING_INPUT);

        _swapAs(eligibleTrader, params);

        (uint160 sqrtPriceAfter,,) = _servicePoolState();

        assertEq(
            sqrtPriceAfter,
            TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q),
            "the swap must stop exactly on the capacity boundary"
        );
        assertEq(hook.supportingCapacity(), 0, "capacity at the boundary is exactly zero and still valid");
        assertEq(hook.aggregateObligation(), 0, "the obligation remains authentically zero");
    }

    /*//////////////////////////////////////////////////////////////
                   G6A-4 — ORDINARY SWAP REQUIRES canSwap
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an otherwise valid swap by an ineligible trader cannot become authoritative.
    function test_protectedDirectionSwap_byIneligibleTrader_isRejected() public {
        SwapParams memory params = _protectedSwapParams(ORDINARY_SWAP_INPUT);

        (uint160 sqrtPriceBefore, int24 tickBefore, uint128 liquidityBefore) = _servicePoolState();

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__TraderNotEligible.selector, ineligibleTrader)
        );
        _swapAs(ineligibleTrader, params);

        _assertPoolStateUnchanged(sqrtPriceBefore, tickBefore, liquidityBefore);
    }

    /// @notice Proves the identical swap succeeds once the registry makes the same actor eligible.
    /// @dev The rejection above is therefore attributable to Standby permissioning and to nothing else:
    ///      the actor, the amount, the direction, the funding, and the approvals are all unchanged here.
    function test_protectedDirectionSwap_succeedsForTheSameActorOnceEligible() public {
        SwapParams memory params = _protectedSwapParams(ORDINARY_SWAP_INPUT);

        _setTraderEligibility(ineligibleTrader, true);

        _swapAs(ineligibleTrader, params);

        assertLt(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_INITIAL_S, "the swap must have executed");
    }

    /// @notice Proves revoked trader eligibility stops further ordinary swaps.
    function test_protectedDirectionSwap_isRejectedAfterEligibilityIsRevoked() public {
        _swapAs(eligibleTrader, _protectedSwapParams(ORDINARY_SWAP_INPUT));

        _setTraderEligibility(eligibleTrader, false);

        (uint160 sqrtPriceBefore, int24 tickBefore, uint128 liquidityBefore) = _servicePoolState();

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__TraderNotEligible.selector, eligibleTrader)
        );
        _swapAs(eligibleTrader, _protectedSwapParams(ORDINARY_SWAP_INPUT));

        _assertPoolStateUnchanged(sqrtPriceBefore, tickBefore, liquidityBefore);
    }

    /*//////////////////////////////////////////////////////////////
              G6A-8 — DOMAIN ENFORCEMENT SURVIVES A ZERO O
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an opposite-direction swap that would leave the service domain is rejected at O = 0.
    /// @dev Backing sufficiency and realization-domain validity are different requirements. This transition
    ///      would satisfy any numeric comparison against a zero obligation; it is refused because the state
    ///      it would produce is one for which no authoritative Standby capacity exists at all.
    function test_oppositeDirectionSwap_leavingTheServiceDomain_isRejectedWhileObligationIsZero() public {
        assertEq(hook.aggregateObligation(), 0, "the obligation must be zero for this to prove anything");

        SwapParams memory params =
            _swapParams(false, -int256(DOMAIN_REACHING_INPUT), StandbyFixtureConfig.LP_TICK_UPPER);

        (uint160 sqrtPriceBefore, int24 tickBefore, uint128 liquidityBefore) = _servicePoolState();

        _expectHookRejection(IHooks.beforeSwap.selector, _expectedDomainViolation(StandbyFixtureConfig.LP_TICK_UPPER));
        _swapAs(eligibleTrader, params);

        _assertPoolStateUnchanged(sqrtPriceBefore, tickBefore, liquidityBefore);
    }

    /// @notice Proves a protected-direction swap that would leave the service domain is rejected at O = 0.
    function test_protectedDirectionSwap_leavingTheServiceDomain_isRejectedWhileObligationIsZero() public {
        SwapParams memory params = _swapParams(true, -int256(DOMAIN_REACHING_INPUT), StandbyFixtureConfig.LP_TICK_LOWER);

        (uint160 sqrtPriceBefore, int24 tickBefore, uint128 liquidityBefore) = _servicePoolState();

        _expectHookRejection(IHooks.beforeSwap.selector, _expectedDomainViolation(StandbyFixtureConfig.LP_TICK_LOWER));
        _swapAs(eligibleTrader, params);

        _assertPoolStateUnchanged(sqrtPriceBefore, tickBefore, liquidityBefore);
    }

    /*//////////////////////////////////////////////////////////////
                  G6A-1..3 — AUTHORITATIVE TRANSITION PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an untrusted perimeter cannot authorize an ordinary swap, however it is constructed.
    /// @dev The untrusted perimeter is a byte-identical copy of the trusted one, carrying a genuinely
    ///      eligible originating user. It is refused on identity of the perimeter alone, before its claimed
    ///      actor can become authoritative — which is the whole point of authenticating before interpreting.
    function test_ordinarySwap_throughAnUntrustedPerimeter_cannotAuthorize() public {
        ActorAwareTestRouter untrustedPerimeter = new ActorAwareTestRouter(poolManager);

        vm.startPrank(eligibleTrader);
        ustb.approve(address(untrustedPerimeter), type(uint256).max);
        usdc.approve(address(untrustedPerimeter), type(uint256).max);
        vm.stopPrank();

        (uint160 sqrtPriceBefore, int24 tickBefore, uint128 liquidityBefore) = _servicePoolState();

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__UntrustedSwapPerimeter.selector, address(untrustedPerimeter)
            )
        );
        vm.prank(eligibleTrader);
        untrustedPerimeter.swap(servicePoolKey, _protectedSwapParams(ORDINARY_SWAP_INPUT), bytes(""));

        _assertPoolStateUnchanged(sqrtPriceBefore, tickBefore, liquidityBefore);
    }

    /// @notice Proves a fabricated callback cannot establish Standby economic truth.
    /// @dev Only the immutable PoolManager may invoke an enabled callback. A direct call carrying the
    ///      trusted perimeter as its claimed sender is refused before any Standby reasoning happens.
    function test_directCallbackInvocation_isRejected() public {
        vm.expectRevert(ImmutableState.NotPoolManager.selector);
        hook.beforeSwap(address(swapPerimeter), servicePoolKey, _protectedSwapParams(ORDINARY_SWAP_INPUT), bytes(""));

        vm.expectRevert(ImmutableState.NotPoolManager.selector);
        hook.afterSwap(
            address(swapPerimeter),
            servicePoolKey,
            _protectedSwapParams(ORDINARY_SWAP_INPUT),
            BalanceDeltaLibrary.ZERO_DELTA,
            bytes("")
        );
    }

    /// @notice Proves a forged hook payload cannot substitute for the authenticated originating user.
    /// @dev The payload names an eligible trader and is delivered through the genuinely trusted perimeter.
    ///      The authoritative actor remains the one the perimeter authenticated, so the transition is
    ///      refused under that actor's own eligibility.
    function test_forgedHookData_cannotEstablishTheActor() public {
        bytes memory forged = abi.encode(eligibleTrader);

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__TraderNotEligible.selector, ineligibleTrader)
        );
        _swapAs(ineligibleTrader, _protectedSwapParams(ORDINARY_SWAP_INPUT), forged);
    }

    /// @notice Proves an ordinary swap against a different pool bound to this Hook cannot be enforced.
    /// @dev Callback enablement follows the Hook address, so any pool may bind this Hook. Only the one
    ///      configured service pool is a Standby transition; another is refused rather than enforced
    ///      against a service basis that does not describe it.
    function test_ordinarySwap_againstAnUnconfiguredPool_isRejected() public {
        PoolKey memory foreignKey = servicePoolKey;
        foreignKey.fee = 3000;

        poolManager.initialize(foreignKey, TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.INITIAL_TICK));

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__PoolIsNotConfiguredService.selector, foreignKey.toId())
        );
        vm.prank(eligibleTrader);
        swapPerimeter.swap(foreignKey, _protectedSwapParams(ORDINARY_SWAP_INPUT), bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                   G6A-12 — afterSwap REMAINS INERT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a completed ordinary swap created no exercise, fulfillment, or commitment state.
    /// @dev Every successful swap invokes `afterSwap`, so this state is what `afterSwap` left behind. There
    ///      is no commitment, no bounded reference, no obligation, and no entitlement to have mutated.
    function test_completedOrdinarySwap_leavesNoCommitmentOrFulfillmentState() public {
        _swapAs(eligibleTrader, _protectedSwapParams(ORDINARY_SWAP_INPUT));

        assertEq(hook.nextCommitmentId(), 1, "no commitment identity may be consumed");
        assertEq(hook.aggregateObligation(), 0, "no obligation may appear");

        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(references[slot], 0, "no enforcement reference may be written");
        }

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(1)));
        hook.commitment(1);
    }

    /// @notice Proves `afterSwap` completes an ordinary swap and takes no delta.
    /// @dev Invoked as the PoolManager, which is the only caller that could reach it. It returns its own
    ///      selector and a zero hook delta: completion plumbing, and deliberately nothing else.
    function test_afterSwap_completesWithoutTakingADelta() public {
        vm.prank(address(poolManager));
        (bytes4 selector, int128 hookDelta) = hook.afterSwap(
            address(swapPerimeter),
            servicePoolKey,
            _protectedSwapParams(ORDINARY_SWAP_INPUT),
            BalanceDeltaLibrary.ZERO_DELTA,
            bytes("")
        );

        assertEq(selector, IHooks.afterSwap.selector, "afterSwap must complete the callback");
        assertEq(hookDelta, int128(0), "afterSwap must take no delta");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds the expected domain-violation reason for a swap that clamps at a tick outside the domain.
    ///
    ///      The boundary prices are reconstructed here from the pinned `TickMath` and the frozen fixture
    ///      boundaries rather than read back from the Hook, so the assertion is independent of the
    ///      production derivation it is checking.
    function _expectedDomainViolation(int24 _clampTick) internal pure returns (bytes memory reason) {
        reason = abi.encodeWithSelector(
            StandbyHook.StandbyHook__ProspectivePriceOutsideServiceDomain.selector,
            TickMath.getSqrtPriceAtTick(_clampTick),
            TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q),
            TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_O)
        );
    }

    /// @dev Proves a rejected transition left authoritative PoolManager state exactly as it was.
    function _assertPoolStateUnchanged(uint160 _sqrtPriceX96, int24 _tick, uint128 _liquidity) internal view {
        (uint160 sqrtPriceAfter, int24 tickAfter, uint128 liquidityAfter) = _servicePoolState();

        assertEq(sqrtPriceAfter, _sqrtPriceX96, "a rejected transition must not move the price");
        assertEq(tickAfter, _tick, "a rejected transition must not move the tick");
        assertEq(liquidityAfter, _liquidity, "a rejected transition must not change active liquidity");
    }
}
