// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {ImmutableState} from "v4-periphery/src/base/ImmutableState.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../../src/demo/ActorAwareTestRouter.sol";

import {BaseActorAwareStandbyTest} from "../shared/BaseActorAwareStandbyTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for ordinary O3 liquidity enforcement while the obligation is zero.
/// @dev Addition and removal are deliberately asymmetric, and this suite is built around that asymmetry.
///      Introducing liquidity is a permissioned act and requires current liquidity-action eligibility;
///      withdrawing it is not, because eligibility administration must never become a way to trap capital
///      that was contributed under different circumstances. Both remain confined to the trusted liquidity
///      perimeter, and both preserve the service topology and the realization domain independently of what
///      the current obligation happens to be.
///
///      Everything runs through the real path: originating user, trusted liquidity perimeter, real pinned
///      `PoolManager`, production `StandbyHook`. No harness participates.
contract O3LiquidityEnforcementTest is BaseActorAwareStandbyTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A modest position size, far below the canonical fixture liquidity.
    int256 internal constant SUPPLEMENTARY_LIQUIDITY = 1_000_000_000;

    /*//////////////////////////////////////////////////////////////
              G6A-5 — ADDITION REQUIRES canProvideLiquidity
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an eligible provider's topology-valid addition becomes authoritative.
    function test_liquidityAddition_byEligibleProvider_becomesAuthoritative() public {
        (,, uint128 liquidityBefore) = _servicePoolState();

        uint256 capacityBefore = hook.supportingCapacity();

        _modifyLiquidityAs(
            exitingProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            )
        );

        (,, uint128 liquidityAfter) = _servicePoolState();

        assertEq(
            uint256(liquidityAfter),
            uint256(liquidityBefore) + uint256(SUPPLEMENTARY_LIQUIDITY),
            "the addition must reach authoritative PoolManager state"
        );
        assertGt(hook.supportingCapacity(), capacityBefore, "an active addition increases Supporting Capacity");
        assertEq(hook.aggregateObligation(), 0, "the obligation stays authentically derived and zero");
    }

    /// @notice Proves an otherwise valid addition by an ineligible provider cannot become authoritative.
    function test_liquidityAddition_byIneligibleProvider_isRejected() public {
        (,, uint128 liquidityBefore) = _servicePoolState();

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

        (,, uint128 liquidityAfter) = _servicePoolState();

        assertEq(liquidityAfter, liquidityBefore, "a rejected addition must not change active liquidity");
    }

    /// @notice Proves the identical addition succeeds once the registry makes the same actor eligible.
    /// @dev The rejection above is therefore attributable to liquidity-action eligibility and not to
    ///      funding, approval, topology, or anything else about the position.
    function test_liquidityAddition_succeedsForTheSameActorOnceEligible() public {
        _setLiquidityEligibility(ineligibleProvider, true);

        (,, uint128 liquidityBefore) = _servicePoolState();

        _modifyLiquidityAs(
            ineligibleProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            )
        );

        (,, uint128 liquidityAfter) = _servicePoolState();

        assertGt(liquidityAfter, liquidityBefore, "the same addition must now execute");
    }

    /// @notice Proves trader eligibility does not confer liquidity-action eligibility.
    /// @dev The permission domains are distinct, and holding one of them is not holding the other.
    function test_liquidityAddition_byAnEligibleTraderWithoutLiquidityEligibility_isRejected() public {
        assertTrue(registry.canSwap(eligibleTrader), "the actor must genuinely be an eligible trader");

        _expectHookRejection(
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__LiquidityProviderNotEligible.selector, eligibleTrader)
        );
        _modifyLiquidityAs(
            eligibleTrader,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
              G6A-9 — TOPOLOGY ENFORCEMENT SURVIVES A ZERO O
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an eligible provider cannot initialize a boundary strictly inside the service domain.
    /// @dev The refusal is not about backing: the addition would increase Supporting Capacity and the
    ///      obligation is zero. It is refused because an interior initialized boundary would destroy the
    ///      single-active-region basis every authoritative derivation is built on.
    function test_liquidityAddition_withAnInteriorLowerBoundary_isRejected() public {
        assertEq(hook.aggregateObligation(), 0, "the obligation must be zero for this to prove anything");

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

    /// @notice Proves the same refusal applies to an interior upper boundary.
    function test_liquidityAddition_withAnInteriorUpperBoundary_isRejected() public {
        _expectHookRejection(
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProhibitedInteriorLiquidityBoundary.selector,
                StandbyFixtureConfig.LP_TICK_LOWER,
                int24(100)
            )
        );
        _modifyLiquidityAs(
            exitingProvider, _liquidityParams(StandbyFixtureConfig.LP_TICK_LOWER, 100, SUPPLEMENTARY_LIQUIDITY)
        );
    }

    /// @notice Proves a position whose endpoints sit exactly on the configured boundaries is permitted.
    /// @dev The service domain is closed. A position spanning it exactly introduces no interior boundary and
    ///      must not be refused, or the realization would reject a topology the frozen semantics allow.
    function test_liquidityAddition_withEndpointsOnTheServiceBoundaries_isPermitted() public {
        (,, uint128 liquidityBefore) = _servicePoolState();

        _modifyLiquidityAs(
            exitingProvider,
            _liquidityParams(StandbyFixtureConfig.TICK_Q, StandbyFixtureConfig.TICK_O, SUPPLEMENTARY_LIQUIDITY)
        );

        (,, uint128 liquidityAfter) = _servicePoolState();

        assertGt(liquidityAfter, liquidityBefore, "a domain-spanning position must be permitted");
    }

    /// @notice Proves a harmless position entirely outside the service domain is permitted.
    /// @dev It is inactive at the current tick, so it contributes no active liquidity and no capacity, and
    ///      it initializes no boundary inside the domain.
    function test_liquidityAddition_entirelyOutsideTheServiceDomain_isPermitted() public {
        (,, uint128 liquidityBefore) = _servicePoolState();

        uint256 capacityBefore = hook.supportingCapacity();

        _modifyLiquidityAs(exitingProvider, _liquidityParams(300, 600, SUPPLEMENTARY_LIQUIDITY));

        (,, uint128 liquidityAfter) = _servicePoolState();

        assertEq(liquidityAfter, liquidityBefore, "an inactive position adds no active liquidity");
        assertEq(hook.supportingCapacity(), capacityBefore, "an inactive position changes no capacity");
    }

    /*//////////////////////////////////////////////////////////////
             G6A-6 — REMOVAL WITHOUT CONTINUING ELIGIBILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a valid removal through the trusted liquidity perimeter executes.
    function test_liquidityRemoval_byEligibleProvider_becomesAuthoritative() public {
        _modifyLiquidityAs(
            exitingProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            )
        );

        (,, uint128 liquidityBefore) = _servicePoolState();

        _modifyLiquidityAs(
            exitingProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, -SUPPLEMENTARY_LIQUIDITY
            )
        );

        (,, uint128 liquidityAfter) = _servicePoolState();

        assertEq(
            uint256(liquidityAfter),
            uint256(liquidityBefore) - uint256(SUPPLEMENTARY_LIQUIDITY),
            "the removal must reach authoritative PoolManager state"
        );
    }

    /// @notice Proves a provider who loses liquidity-action eligibility can still exit.
    /// @dev The mandatory behavioral sequence: contribute while eligible, lose eligibility, withdraw anyway.
    ///      Eligibility governs introducing liquidity, not the right to take back what was contributed, so
    ///      registry administration cannot become a capital trap.
    function test_liquidityRemoval_afterEligibilityIsRevoked_stillExecutes() public {
        ModifyLiquidityParams memory addition = _liquidityParams(
            StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
        );

        _modifyLiquidityAs(exitingProvider, addition);

        _setLiquidityEligibility(exitingProvider, false);

        assertFalse(registry.canProvideLiquidity(exitingProvider), "the provider must genuinely be ineligible");

        ModifyLiquidityParams memory removal = _liquidityParams(
            StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, -SUPPLEMENTARY_LIQUIDITY
        );

        uint256 ustbBefore = ustb.balanceOf(exitingProvider);
        uint256 usdcBefore = usdc.balanceOf(exitingProvider);

        _modifyLiquidityAs(exitingProvider, removal);

        assertGt(ustb.balanceOf(exitingProvider), ustbBefore, "the exiting provider must receive currency0 back");
        assertGt(usdc.balanceOf(exitingProvider), usdcBefore, "the exiting provider must receive currency1 back");

        _expectHookRejection(
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__LiquidityProviderNotEligible.selector, exitingProvider)
        );
        _modifyLiquidityAs(exitingProvider, addition);
    }

    /// @notice Proves an economically neutral zero-delta operation is not refused for an ineligible provider.
    /// @dev Uniswap routes a zero delta to the removal callback, and it changes neither price nor active
    ///      liquidity. It is classified by that actual effect rather than by which callback dispatched it,
    ///      so fee collection remains available after eligibility is lost.
    function test_zeroDeltaLiquidityOperation_afterEligibilityIsRevoked_isPermitted() public {
        _modifyLiquidityAs(
            exitingProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            )
        );

        _setLiquidityEligibility(exitingProvider, false);

        (uint160 sqrtPriceBefore,, uint128 liquidityBefore) = _servicePoolState();

        uint256 capacityBefore = hook.supportingCapacity();

        _modifyLiquidityAs(
            exitingProvider, _liquidityParams(StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, 0)
        );

        (uint160 sqrtPriceAfter,, uint128 liquidityAfter) = _servicePoolState();

        assertEq(sqrtPriceAfter, sqrtPriceBefore, "a zero-delta operation moves no price");
        assertEq(liquidityAfter, liquidityBefore, "a zero-delta operation changes no active liquidity");
        assertEq(hook.supportingCapacity(), capacityBefore, "a zero-delta operation changes no capacity");
    }

    /*//////////////////////////////////////////////////////////////
              G6A-10 — F5 PROSPECTIVE DERIVATION IS CONSUMED
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the predicted post-removal capacity equals the authoritative post-removal capacity.
    /// @dev The prediction is the production prospective-removal derivation, the same one enforcement
    ///      consumes before admitting the transition, and it is taken before the pool has moved.
    function test_activeLiquidityRemoval_matchesTheProspectiveDerivation() public {
        ModifyLiquidityParams memory removal = _liquidityParams(
            StandbyFixtureConfig.LP_TICK_LOWER,
            StandbyFixtureConfig.LP_TICK_UPPER,
            -int256(uint256(StandbyFixtureConfig.CANONICAL_LIQUIDITY)) / 2
        );

        uint256 predictedCapacity = hook.prospectiveSupportingCapacityAfterLiquidityRemoval(removal);

        assertLt(predictedCapacity, hook.supportingCapacity(), "an active removal must reduce predicted capacity");

        _modifyLiquidityAs(canonicalProvider, removal);

        assertEq(hook.supportingCapacity(), predictedCapacity, "post-state capacity must equal the F5 prediction");
    }

    /// @notice Proves an inactive removal is predicted, and observed, to leave capacity untouched.
    function test_inactiveLiquidityRemoval_matchesTheProspectiveDerivation() public {
        ModifyLiquidityParams memory addition = _liquidityParams(300, 600, SUPPLEMENTARY_LIQUIDITY);

        _modifyLiquidityAs(exitingProvider, addition);

        ModifyLiquidityParams memory removal = _liquidityParams(300, 600, -SUPPLEMENTARY_LIQUIDITY);

        uint256 predictedCapacity = hook.prospectiveSupportingCapacityAfterLiquidityRemoval(removal);

        assertEq(predictedCapacity, hook.supportingCapacity(), "an inactive removal predicts unchanged capacity");

        _modifyLiquidityAs(exitingProvider, removal);

        assertEq(hook.supportingCapacity(), predictedCapacity, "post-state capacity must equal the F5 prediction");
    }

    /*//////////////////////////////////////////////////////////////
                  G6A-1..2 — AUTHORITATIVE TRANSITION PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an untrusted perimeter cannot authorize a liquidity addition.
    function test_liquidityAddition_throughAnUntrustedPerimeter_cannotAuthorize() public {
        ActorAwareTestRouter untrustedPerimeter = new ActorAwareTestRouter(poolManager);

        vm.startPrank(exitingProvider);
        ustb.approve(address(untrustedPerimeter), type(uint256).max);
        usdc.approve(address(untrustedPerimeter), type(uint256).max);
        vm.stopPrank();

        _expectHookRejection(
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__UntrustedLiquidityPerimeter.selector, address(untrustedPerimeter)
            )
        );
        vm.prank(exitingProvider);
        untrustedPerimeter.modifyLiquidity(
            servicePoolKey,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            ),
            bytes("")
        );
    }

    /// @notice Proves a fabricated liquidity callback cannot establish Standby economic truth.
    function test_directLiquidityCallbackInvocation_isRejected() public {
        ModifyLiquidityParams memory params = _liquidityParams(
            StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
        );

        vm.expectRevert(ImmutableState.NotPoolManager.selector);
        hook.beforeAddLiquidity(address(liquidityPerimeter), servicePoolKey, params, bytes(""));

        vm.expectRevert(ImmutableState.NotPoolManager.selector);
        hook.beforeRemoveLiquidity(address(liquidityPerimeter), servicePoolKey, params, bytes(""));
    }

    /// @notice Proves a liquidity action against a different pool bound to this Hook cannot be enforced.
    function test_liquidityAddition_againstAnUnconfiguredPool_isRejected() public {
        PoolKey memory foreignKey = servicePoolKey;
        foreignKey.fee = 3000;

        poolManager.initialize(foreignKey, TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.INITIAL_TICK));

        _expectHookRejection(
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__PoolIsNotConfiguredService.selector, foreignKey.toId())
        );
        vm.prank(exitingProvider);
        liquidityPerimeter.modifyLiquidity(
            foreignKey,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            ),
            bytes("")
        );
    }
}
