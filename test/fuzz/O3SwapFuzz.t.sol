// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../../src/demo/ActorAwareTestRouter.sol";

import {BaseActorAwareStandbyTest} from "../shared/BaseActorAwareStandbyTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Behavioral fuzz evidence for ordinary O3 swap enforcement.
/// @dev Every run drives a real authoritative transition attempt through the real path: originating user,
///      trusted perimeter, real pinned `PoolManager`, production `StandbyHook`. No harness is involved,
///      because the properties are about which transitions become authoritative, and a harness answer would
///      be an answer about the harness.
///
///      The parameter domains are chosen to keep the interesting region reachable rather than to make the
///      properties easy: both directions, both supported exact-input and exact-output forms, amounts that
///      span from dust to more than the whole domain can absorb, and arbitrary hook payloads.
contract O3SwapFuzzTest is BaseActorAwareStandbyTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Upper bound on a fuzzed exact-input amount. Larger than the whole domain can absorb, so runs
    ///      reach the capacity boundary as well as staying well inside it.
    uint256 internal constant MAX_FUZZED_INPUT = 200_000 * 10 ** 6;

    /// @dev Upper bound on a fuzzed exact-output amount, for the same reason.
    uint256 internal constant MAX_FUZZED_OUTPUT = 120_000 * 10 ** 6;

    /*//////////////////////////////////////////////////////////////
                       ELIGIBILITY PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice An ineligible trader can never produce an authoritative ordinary swap.
    /// @dev Direction, form, amount, and hook payload are all free. None of them is a way in.
    function testFuzz_ineligibleTrader_neverProducesAnAuthoritativeSwap(
        bool _zeroForOne,
        bool _exactOutput,
        uint256 _amount,
        bytes calldata _hookData
    ) public {
        SwapParams memory params = _boundedSwapParams(_zeroForOne, _exactOutput, _amount);

        (uint160 sqrtPriceBefore, int24 tickBefore, uint128 liquidityBefore) = _servicePoolState();

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__TraderNotEligible.selector, ineligibleTrader)
        );
        _swapAs(ineligibleTrader, params, _hookData);

        _assertPoolStateUnchanged(sqrtPriceBefore, tickBefore, liquidityBefore);
    }

    /// @notice A perimeter the service does not trust can never produce an authoritative ordinary swap.
    /// @dev The originating user is genuinely eligible on every run, so the refusal is about provenance.
    function testFuzz_untrustedPerimeter_neverProducesAnAuthoritativeSwap(
        bool _zeroForOne,
        bool _exactOutput,
        uint256 _amount
    ) public {
        ActorAwareTestRouter untrustedPerimeter = new ActorAwareTestRouter(poolManager);

        vm.startPrank(eligibleTrader);
        ustb.approve(address(untrustedPerimeter), type(uint256).max);
        usdc.approve(address(untrustedPerimeter), type(uint256).max);
        vm.stopPrank();

        SwapParams memory params = _boundedSwapParams(_zeroForOne, _exactOutput, _amount);

        (uint160 sqrtPriceBefore, int24 tickBefore, uint128 liquidityBefore) = _servicePoolState();

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__UntrustedSwapPerimeter.selector, address(untrustedPerimeter)
            )
        );
        vm.prank(eligibleTrader);
        untrustedPerimeter.swap(servicePoolKey, params, bytes(""));

        _assertPoolStateUnchanged(sqrtPriceBefore, tickBefore, liquidityBefore);
    }

    /*//////////////////////////////////////////////////////////////
                        DERIVATION PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice An accepted ordinary swap leaves exactly the state the production derivation predicted.
    /// @dev The prediction is read before the transition and the authoritative capacity after it, so this
    ///      is a claim about the enforcement basis and not merely about self-consistency: enforcement
    ///      admitted the transition on the strength of that predicted state.
    function testFuzz_acceptedOrdinarySwap_matchesTheProspectiveDerivation(
        bool _zeroForOne,
        bool _exactOutput,
        uint256 _amount,
        bytes calldata _hookData
    ) public {
        SwapParams memory params = _boundedSwapParams(_zeroForOne, _exactOutput, _amount);

        uint256 predictedCapacity = hook.prospectiveSupportingCapacityAfterSwap(params);

        _swapAs(eligibleTrader, params, _hookData);

        assertEq(hook.supportingCapacity(), predictedCapacity, "post-state capacity must equal the prediction");
        assertEq(hook.aggregateObligation(), 0, "no authentic obligation can exist");

        (uint160 sqrtPriceAfter,,) = _servicePoolState();

        assertTrue(
            sqrtPriceAfter >= TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q)
                && sqrtPriceAfter <= TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_O),
            "an accepted swap must leave the pool inside the closed service domain"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          DOMAIN PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice A swap that would leave the service domain never becomes authoritative at a zero obligation.
    /// @dev Each run carries a price limit outside the configured domain and an amount large enough to
    ///      reach it. A zero obligation makes the backing comparison trivially satisfiable, and the
    ///      transition is refused anyway, because realization-domain validity is a separate requirement.
    function testFuzz_domainLeavingSwap_neverBecomesAuthoritative(bool _zeroForOne, uint256 _amount) public {
        assertEq(hook.aggregateObligation(), 0, "the obligation must be zero for this to prove anything");

        int24 limitTick = _zeroForOne ? StandbyFixtureConfig.LP_TICK_LOWER : StandbyFixtureConfig.LP_TICK_UPPER;

        SwapParams memory params =
            _swapParams(_zeroForOne, -int256(bound(_amount, MAX_FUZZED_INPUT, 10 * MAX_FUZZED_INPUT)), limitTick);

        (uint160 sqrtPriceBefore, int24 tickBefore, uint128 liquidityBefore) = _servicePoolState();

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProspectivePriceOutsideServiceDomain.selector,
                TickMath.getSqrtPriceAtTick(limitTick),
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q),
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_O)
            )
        );
        _swapAs(eligibleTrader, params);

        _assertPoolStateUnchanged(sqrtPriceBefore, tickBefore, liquidityBefore);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a supported ordinary swap whose reachable path is confined to the service domain.
    ///
    ///      The price limit is the direction-relative service boundary, so a swap larger than the domain
    ///      can absorb stops exactly on the boundary rather than running past it. That keeps the accepted
    ///      region reachable while leaving the boundary itself — where capacity is exactly zero — inside
    ///      the explored domain.
    function _boundedSwapParams(bool _zeroForOne, bool _exactOutput, uint256 _amount)
        internal
        pure
        returns (SwapParams memory params)
    {
        int24 limitTick = _zeroForOne ? StandbyFixtureConfig.TICK_Q : StandbyFixtureConfig.TICK_O;

        int256 amountSpecified =
            _exactOutput ? int256(_bound(_amount, 1, MAX_FUZZED_OUTPUT)) : -int256(_bound(_amount, 1, MAX_FUZZED_INPUT));

        params = _swapParams(_zeroForOne, amountSpecified, limitTick);
    }

    /// @dev Proves a rejected transition left authoritative PoolManager state exactly as it was.
    function _assertPoolStateUnchanged(uint160 _sqrtPriceX96, int24 _tick, uint128 _liquidity) internal view {
        (uint160 sqrtPriceAfter, int24 tickAfter, uint128 liquidityAfter) = _servicePoolState();

        assertEq(sqrtPriceAfter, _sqrtPriceX96, "a rejected transition must not move the price");
        assertEq(tickAfter, _tick, "a rejected transition must not move the tick");
        assertEq(liquidityAfter, _liquidity, "a rejected transition must not change active liquidity");
    }
}
