// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {SwapMath} from "v4-core/libraries/SwapMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {ServiceDomain} from "../../src/libraries/ServiceDomain.sol";

import {BaseDerivationTest} from "../shared/BaseDerivationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Prospective-state equivalence evidence against real Uniswap v4 execution (G5-B, G5-F).
/// @dev The oracle here is not a second calculation. For each supported transition the test derives the
///      predicted post-transition state, executes the very same transition against the real pinned
///      PoolManager, and compares the prediction with what the pool actually did — then derives
///      Supporting Capacity from the real post-state and compares that with the predicted `S'`.
///
///      This is the dependency the later pre-transition enforcement rests on. Enforcement authorizes a
///      transition using a prediction, so a prediction that were merely close would authorize transitions
///      the pool then resolves differently, and backing would be decided against a state that never
///      existed. Equality here is therefore exact, never approximate.
///
///      The reproduction being verified is not a single swap step. Uniswap advances a swap in steps
///      bounded by the tick bitmap, and the bitmap yields a candidate at every word edge — not only at
///      initialized liquidity boundaries. A word edge falls at tick 0, strictly inside the canonical
///      service domain, so an ordinary downward swap that starts above parity is split into two steps
///      with their own rounding. The word-edge test below is the case that distinguishes a faithful
///      reproduction from a plausible single-step approximation.
contract ProspectiveStateEquivalenceTest is BaseDerivationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev An inactive liquidity range, entirely above the canonical domain and the canonical position.
    int24 internal constant INACTIVE_TICK_LOWER = 1_000;
    int24 internal constant INACTIVE_TICK_UPPER = 2_000;

    DeployedService internal service;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Builds the canonical service with real liquidity through real v4 paths.
    function setUp() public virtual override {
        super.setUp();

        service = _deployService(_canonicalConfig());
    }

    /*//////////////////////////////////////////////////////////////
                     G5-B — PROSPECTIVE SWAP STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the predicted state of an exact-input protected swap is the state v4 produces.
    function test_prospectiveSwap_exactInputProtectedDirectionMatchesRealExecution() public {
        _assertSwapPredictionMatchesExecution(_swapToTickLimit(true, -20_000_000_000, service.config.tickQ));
    }

    /// @notice Proves the predicted state of an exact-output protected swap is the state v4 produces.
    /// @dev Exact output is the shape a commitment exercise takes: a promised result amount is named and
    ///      the input follows. Its step arithmetic and fee treatment differ from exact input, so it is
    ///      separate evidence rather than a restatement.
    function test_prospectiveSwap_exactOutputProtectedDirectionMatchesRealExecution() public {
        _assertSwapPredictionMatchesExecution(_swapToTickLimit(true, 15_000_000_000, service.config.tickQ));
    }

    /// @notice Proves the predicted state of an opposite-direction swap is the state v4 produces.
    /// @dev A swap away from `P_Q` increases Supporting Capacity rather than consuming it, but the
    ///      prediction must be exact in that direction too — the price still has to stay in the domain.
    function test_prospectiveSwap_oppositeDirectionMatchesRealExecution() public {
        _assertSwapPredictionMatchesExecution(_swapToTickLimit(false, -20_000_000_000, service.config.tickO));
    }

    /// @notice Proves a swap that crosses a tick-bitmap word edge is still predicted exactly.
    /// @dev This is the case a single-step model gets wrong. The pool is first moved above parity, which
    ///      puts the word edge at tick 0 between the current price and the target; the downward swap that
    ///      follows is then split by v4 into two steps, each rounding its own amounts. The prediction
    ///      must reproduce that split rather than the smooth single step it superficially resembles.
    function test_prospectiveSwap_acrossATickBitmapWordEdgeMatchesRealExecution() public {
        _swap(service, _swapToTickLimit(false, -20_000_000_000, service.config.tickO));

        (, int24 tickAfterFirstSwap,) = _poolState(service);

        assertGt(tickAfterFirstSwap, 0, "the pool must sit above the word edge before the second swap");

        _assertSwapPredictionMatchesExecution(_swapToTickLimit(true, -30_000_000_000, service.config.tickQ));
    }

    /// @notice Proves the word-edge split is real, by showing a single-step model would disagree.
    /// @dev Without this, the preceding test could pass for a reproduction that never splits at all. Here
    ///      the single-step answer — the price v4 would reach if it advanced straight to the next
    ///      initialized liquidity boundary or the limit — is computed explicitly and shown to differ from
    ///      the price the pool actually reaches, while the production prediction matches it exactly.
    function test_prospectiveSwap_singleStepModelDisagreesWhereTheProductionDerivationDoesNot() public {
        _swap(service, _swapToTickLimit(false, -20_000_000_000, service.config.tickO));

        SwapParams memory params = _swapToTickLimit(true, -30_000_000_000, service.config.tickQ);

        (uint160 sqrtPriceBeforeX96,, uint128 liquidityBefore) = _poolState(service);

        (uint160 predictedSqrtPriceX96,) = service.hook.prospectiveSwapState(params);

        (uint160 singleStepSqrtPriceX96,,,) = SwapMath.computeSwapStep(
            sqrtPriceBeforeX96,
            SwapMath.getSqrtPriceTarget(
                true, TickMath.getSqrtPriceAtTick(service.config.lpTickLower), params.sqrtPriceLimitX96
            ),
            liquidityBefore,
            params.amountSpecified,
            service.config.lpFee
        );

        _swap(service, params);

        (uint160 actualSqrtPriceX96,,) = _poolState(service);

        assertEq(predictedSqrtPriceX96, actualSqrtPriceX96, "the production prediction must be exact");
        assertNotEq(singleStepSqrtPriceX96, actualSqrtPriceX96, "a single-step model must be shown to be inexact here");
    }

    /// @notice Proves a swap that reaches `P_Q` exactly is predicted exactly, capacity included.
    /// @dev Arriving at the capacity-exhaustion boundary is the state an exercise drives the pool toward,
    ///      and it is the state where Supporting Capacity is exactly zero. The prediction must land on it
    ///      rather than near it.
    function test_prospectiveSwap_reachingPQExactlyMatchesRealExecution() public {
        SwapParams memory params = _swapToTickLimit(true, -1_000_000_000_000, service.config.tickQ);

        (uint160 predictedSqrtPriceX96,) = service.hook.prospectiveSwapState(params);

        assertEq(
            predictedSqrtPriceX96,
            TickMath.getSqrtPriceAtTick(service.config.tickQ),
            "the swap must be predicted to stop exactly at P_Q"
        );
        assertEq(service.hook.prospectiveSupportingCapacityAfterSwap(params), 0, "capacity must be predicted to vanish");

        _swap(service, params);

        (uint160 actualSqrtPriceX96,,) = _poolState(service);

        assertEq(actualSqrtPriceX96, predictedSqrtPriceX96, "the pool must stop exactly at P_Q");
        assertEq(service.hook.supportingCapacity(), 0, "authoritative capacity must be exactly zero at P_Q");
    }

    /// @notice Proves a zero-amount swap is predicted to change nothing.
    /// @dev v4 short-circuits a zero-amount swap before it applies any price-limit condition, and the
    ///      derivation must short-circuit at the same place or it would reject a swap the pool accepts.
    function test_prospectiveSwap_zeroAmountChangesNothing() public view {
        (uint160 sqrtPriceBeforeX96,, uint128 liquidityBefore) = _poolState(service);

        (uint160 predictedSqrtPriceX96, uint128 predictedLiquidity) =
            service.hook.prospectiveSwapState(SwapParams({zeroForOne: true, amountSpecified: 0, sqrtPriceLimitX96: 0}));

        assertEq(predictedSqrtPriceX96, sqrtPriceBeforeX96, "a zero-amount swap moves no price");
        assertEq(predictedLiquidity, liquidityBefore, "a zero-amount swap moves no liquidity");
    }

    /// @notice Proves deriving a prediction changes no authoritative state.
    /// @dev The derivation is a view over authoritative facts. If predicting were to write anything, a
    ///      diagnostic preview would perturb the very state enforcement later reads.
    function test_prospectiveSwap_derivationMutatesNothing() public view {
        (uint160 sqrtPriceBeforeX96, int24 tickBefore, uint128 liquidityBefore) = _poolState(service);

        uint256 capacityBefore = service.hook.supportingCapacity();

        service.hook.prospectiveSwapState(_swapToTickLimit(true, -20_000_000_000, service.config.tickQ));
        service.hook.prospectiveSupportingCapacityAfterSwap(
            _swapToTickLimit(true, -20_000_000_000, service.config.tickQ)
        );

        (uint160 sqrtPriceAfterX96, int24 tickAfter, uint128 liquidityAfter) = _poolState(service);

        assertEq(sqrtPriceAfterX96, sqrtPriceBeforeX96, "the price must be untouched");
        assertEq(tickAfter, tickBefore, "the tick must be untouched");
        assertEq(liquidityAfter, liquidityBefore, "the liquidity must be untouched");
        assertEq(service.hook.supportingCapacity(), capacityBefore, "capacity must be untouched");
    }

    /*//////////////////////////////////////////////////////////////
                G5-B — PROSPECTIVE LIQUIDITY-REMOVAL STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an active removal is predicted exactly, in liquidity, price, and capacity.
    function test_prospectiveRemoval_activePositionMatchesRealExecution() public {
        _assertRemovalPredictionMatchesExecution(
            ModifyLiquidityParams({
                tickLower: service.config.lpTickLower,
                tickUpper: service.config.lpTickUpper,
                liquidityDelta: -int256(uint256(service.config.liquidity) / 4),
                salt: bytes32(0)
            })
        );
    }

    /// @notice Proves an inactive removal is predicted to change nothing, and does not.
    /// @dev An inactive position contributes no active liquidity, so removing it cannot reduce Supporting
    ///      Capacity. A derivation that subtracted removed liquidity unconditionally would reject
    ///      perfectly harmless exits.
    function test_prospectiveRemoval_inactivePositionChangesNothing() public {
        _addLiquidity(service, INACTIVE_TICK_LOWER, INACTIVE_TICK_UPPER, int256(uint256(service.config.liquidity)));

        (, int24 tick,) = _poolState(service);

        assertLt(tick, INACTIVE_TICK_LOWER, "the added position must be inactive at the current tick");

        uint256 capacityBefore = service.hook.supportingCapacity();

        _assertRemovalPredictionMatchesExecution(
            ModifyLiquidityParams({
                tickLower: INACTIVE_TICK_LOWER,
                tickUpper: INACTIVE_TICK_UPPER,
                liquidityDelta: -int256(uint256(service.config.liquidity)),
                salt: bytes32(0)
            })
        );

        assertEq(service.hook.supportingCapacity(), capacityBefore, "an inactive removal must not change capacity");
    }

    /// @notice Proves a full removal of the active position is predicted exactly, leaving zero capacity.
    /// @dev Zero active liquidity is a valid state with no capacity, not an error, and the derivation must
    ///      arrive at zero rather than at an undefined answer.
    function test_prospectiveRemoval_fullActiveRemovalLeavesNoCapacity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: service.config.lpTickLower,
            tickUpper: service.config.lpTickUpper,
            liquidityDelta: -int256(uint256(service.config.liquidity)),
            salt: bytes32(0)
        });

        assertEq(
            service.hook.prospectiveSupportingCapacityAfterLiquidityRemoval(params),
            0,
            "removing all active liquidity must be predicted to leave no capacity"
        );

        _assertRemovalPredictionMatchesExecution(params);

        assertEq(service.hook.supportingCapacity(), 0, "no active liquidity means no capacity");
    }

    /*//////////////////////////////////////////////////////////////
                     G5-F — INVALID DERIVATION BASIS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a swap predicted to leave the service domain yields no capacity answer.
    /// @dev A price outside the configured domain is not a state with some capacity value; it is a state
    ///      the Standby derivation basis does not cover. Reporting a number for it would let a transition
    ///      that destroys the realization domain be evaluated as though it merely changed capacity.
    function test_prospectiveSwap_refusesCapacityForAPredictedStateOutsideTheDomain() public {
        SwapParams memory params = _swapToTickLimit(true, -1_000_000_000_000, service.config.lpTickLower);

        (uint160 predictedSqrtPriceX96,) = service.hook.prospectiveSwapState(params);

        assertLt(
            predictedSqrtPriceX96,
            TickMath.getSqrtPriceAtTick(service.config.tickQ),
            "the swap must actually be predicted to leave the domain"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProspectivePriceOutsideServiceDomain.selector,
                predictedSqrtPriceX96,
                TickMath.getSqrtPriceAtTick(service.config.tickQ),
                TickMath.getSqrtPriceAtTick(service.config.tickO)
            )
        );
        service.hook.prospectiveSupportingCapacityAfterSwap(params);
    }

    /// @notice Proves a price limit Uniswap itself would reject is refused rather than predicted.
    /// @dev The derivation reproduces v4's own entry conditions, so it never reports a post-state for a
    ///      swap the PoolManager would have refused to begin.
    function test_prospectiveSwap_refusesAPriceLimitUniswapWouldReject() public {
        (uint160 sqrtPriceX96,,) = _poolState(service);

        SwapParams memory params =
            SwapParams({zeroForOne: true, amountSpecified: -1_000, sqrtPriceLimitX96: sqrtPriceX96});

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__UnsupportedSwapPriceLimit.selector, true, sqrtPriceX96, sqrtPriceX96
            )
        );
        service.hook.prospectiveSwapState(params);
    }

    /// @notice Proves the removal derivation refuses a liquidity addition.
    /// @dev Addition and removal are different transitions with different consequences for backing, and
    ///      the removal derivation must not silently answer for the wrong one.
    function test_prospectiveRemoval_refusesANonRemoval() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: service.config.lpTickLower,
            tickUpper: service.config.lpTickUpper,
            liquidityDelta: int256(uint256(service.config.liquidity)),
            salt: bytes32(0)
        });

        vm.expectRevert(
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotALiquidityRemoval.selector, params.liquidityDelta)
        );
        service.hook.prospectiveLiquidityRemovalState(params);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Predicts a swap, executes it for real, and requires the pool to have done exactly that.
    ///
    ///      Three comparisons are made, and each rules out a different way a prediction could be wrong:
    ///      the predicted price against the real price, the predicted active liquidity against the real
    ///      active liquidity, and the predicted `S'` against the Supporting Capacity the Hook derives
    ///      from the real post-state through its ordinary authoritative read.
    function _assertSwapPredictionMatchesExecution(SwapParams memory _params) internal {
        (uint160 predictedSqrtPriceX96, uint128 predictedLiquidity) = service.hook.prospectiveSwapState(_params);

        uint256 predictedCapacity = service.hook.prospectiveSupportingCapacityAfterSwap(_params);

        _swap(service, _params);

        (uint160 actualSqrtPriceX96,, uint128 actualLiquidity) = _poolState(service);

        assertEq(predictedSqrtPriceX96, actualSqrtPriceX96, "the predicted price must be the price v4 produced");
        assertEq(predictedLiquidity, actualLiquidity, "the predicted liquidity must be the liquidity v4 produced");
        assertEq(
            predictedCapacity,
            service.hook.supportingCapacity(),
            "the predicted capacity must equal the capacity derived from the real post-state"
        );
    }

    /// @dev Predicts a liquidity removal, executes it for real, and requires the pool to have done that.
    function _assertRemovalPredictionMatchesExecution(ModifyLiquidityParams memory _params) internal {
        (uint160 predictedSqrtPriceX96, uint128 predictedLiquidity) =
            service.hook.prospectiveLiquidityRemovalState(_params);

        uint256 predictedCapacity = service.hook.prospectiveSupportingCapacityAfterLiquidityRemoval(_params);

        (uint160 sqrtPriceBeforeX96,,) = _poolState(service);

        assertEq(predictedSqrtPriceX96, sqrtPriceBeforeX96, "a removal must be predicted to move no price");

        _addLiquidity(service, _params.tickLower, _params.tickUpper, _params.liquidityDelta);

        (uint160 actualSqrtPriceX96,, uint128 actualLiquidity) = _poolState(service);

        assertEq(actualSqrtPriceX96, predictedSqrtPriceX96, "the real removal must have moved no price");
        assertEq(predictedLiquidity, actualLiquidity, "the predicted liquidity must be the liquidity v4 produced");
        assertEq(
            predictedCapacity,
            service.hook.supportingCapacity(),
            "the predicted capacity must equal the capacity derived from the real post-state"
        );
    }
}

/// @notice Admission-time and defensive bounded-traversal evidence (G5-B, G5-D, G5-F).
/// @dev The prospective derivation walks the same swap steps Uniswap walks, and how many of those a
///      service can demand is a property of its immutable configuration: tick spacing decides how many
///      ticks a bitmap word covers, and the boundary ticks decide how many words the domain spans. A wide
///      enough domain at a fine enough spacing therefore demands more steps than the reference
///      realization supports — and because the service basis is immutable, nothing could repair that
///      after activation.
///
///      The correction is that such a service never becomes authoritative. Activation derives the
///      traversal demand its proposed domain implies and refuses if it exceeds the supported bound, so
///      an activated service is one whose every supported in-domain path is derivable. The runtime bound
///      stays, but only as defensive protection: on an activated service it can be reached solely by a
///      path that has already left the configured domain, which is not a path any supported Standby
///      operation takes.
///
///      This fixture proves both halves — that admission is the mechanism, and that the exactly-bounded
///      service really does derive its own worst case without hitting the bound.
contract ProspectiveTraversalBoundTest is BaseDerivationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A domain whose traversal demand is exactly the supported bound. With a tick spacing of one,
    ///      the numeric top at tick 100 sits inside bitmap word 0 rather than on its edge, and the
    ///      numeric bottom at tick -3484 sits in word -14: fifteen words, plus the one conditional step
    ///      the non-edge top allows for, is sixteen.
    int24 internal constant EXACT_BOUND_TICK_Q = -3_484;
    int24 internal constant EXACT_BOUND_TICK_O = 100;

    /// @dev One tick lower, which moves the bottom into word -15 and pushes demand to seventeen.
    int24 internal constant OVER_BOUND_TICK_Q = -3_585;

    /// @dev Liquidity endpoints outside the exactly-bounded domain, spanning it completely.
    int24 internal constant SPANNING_TICK_LOWER = -3_600;
    int24 internal constant SPANNING_TICK_UPPER = 200;

    /// @dev A position whose lower endpoint sits exactly on the numeric top of the domain. RR-SC-6
    ///      permits an endpoint on a configured boundary, and this is the topology that makes the
    ///      conditional extra step real: the price starts on an initialized tick, so v4 spends one step
    ///      crossing it without moving before it spends another on the same bitmap word.
    int24 internal constant BOUNDARY_TICK_LOWER = 100;
    int24 internal constant BOUNDARY_TICK_UPPER = 200;

    uint128 internal constant SPANNING_LIQUIDITY = 1_000_000_000_000;

    /*//////////////////////////////////////////////////////////////
                     ADMISSION-TIME DERIVABILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a domain demanding exactly the supported bound activates.
    function test_activation_acceptsADomainDemandingExactlyTheSupportedBound() public {
        DeployedService memory service = _prepareService(_exactBoundConfig());

        assertEq(
            ServiceDomain.prospectiveTraversalDemand(EXACT_BOUND_TICK_Q, EXACT_BOUND_TICK_O, service.config.tickSpacing),
            service.hook.MAX_PROSPECTIVE_SWAP_STEPS(),
            "the fixture must sit exactly on the bound"
        );

        _activateService(service);

        assertTrue(service.hook.protectedExecutionService().configured, "an exactly-bounded domain must activate");
    }

    /// @notice Proves a domain demanding one step more than the bound is refused, atomically.
    /// @dev One tick of extra width is the whole difference. The rejection names the realization-
    ///      admissibility failure rather than any economic condition, and nothing of the proposed service
    ///      survives it.
    function test_activation_rejectsADomainDemandingOneStepBeyondTheBound() public {
        ServiceConfig memory config = _exactBoundConfig();
        config.tickQ = OVER_BOUND_TICK_Q;

        DeployedService memory service = _prepareService(config);

        uint256 bound = service.hook.MAX_PROSPECTIVE_SWAP_STEPS();
        uint256 demand =
            ServiceDomain.prospectiveTraversalDemand(OVER_BOUND_TICK_Q, EXACT_BOUND_TICK_O, config.tickSpacing);

        assertEq(demand, bound + 1, "the fixture must sit exactly one step beyond the bound");

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProspectiveTraversalDemandExceedsBound.selector, demand, bound
            )
        );
        _activateService(service);

        _assertNoServicePersisted(service);
    }

    /// @notice Proves a far-over-bound domain is refused before any authoritative persistence.
    /// @dev The wide spacing-one domain this suite previously activated in order to reach the runtime
    ///      bound is exactly the configuration that must now never become authoritative.
    function test_activation_rejectsAFarOverBoundDomainBeforeAnyPersistence() public {
        DeployedService memory service = _prepareService(_farOverBoundConfig());

        uint256 bound = service.hook.MAX_PROSPECTIVE_SWAP_STEPS();
        uint256 demand = ServiceDomain.prospectiveTraversalDemand(-6_000, 6_000, 1);

        assertGt(demand, bound, "the fixture must exceed the bound");

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProspectiveTraversalDemandExceedsBound.selector, demand, bound
            )
        );
        _activateService(service);

        _assertNoServicePersisted(service);
    }

    /*//////////////////////////////////////////////////////////////
              G5-B — DOMAIN-EXTREME PATH ON AN ACCEPTED PES
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an exactly-bounded service derives its worst in-domain path without hitting the
    ///         runtime bound, and derives it exactly.
    /// @dev This is what makes the admission classifier evidence rather than assertion. The service sits
    ///      exactly on the bound; its liquidity is arranged in the worst topology the closed domain
    ///      permits, with an endpoint on the numeric top so the conditional crossing step is actually
    ///      spent; and the swap runs the full width of the domain from `P_O` to `P_Q`. If the classifier
    ///      under-counted by even one step, this would revert instead of matching real execution.
    function test_prospectiveSwap_derivesTheWorstInDomainPathOfAnExactlyBoundedService() public {
        DeployedService memory service = _deployService(_exactBoundConfig());

        _addLiquidity(service, BOUNDARY_TICK_LOWER, BOUNDARY_TICK_UPPER, int256(uint256(SPANNING_LIQUIDITY)));

        (uint160 sqrtPriceBeforeX96, int24 tickBefore,) = _poolState(service);

        assertEq(tickBefore, EXACT_BOUND_TICK_O, "the pool must start exactly on the initialized numeric top");
        assertEq(
            sqrtPriceBeforeX96,
            TickMath.getSqrtPriceAtTick(EXACT_BOUND_TICK_O),
            "the pool must start exactly at the P_O price"
        );

        SwapParams memory params = _swapToTickLimit(true, -1_000_000_000_000_000_000, EXACT_BOUND_TICK_Q);

        (uint160 predictedSqrtPriceX96, uint128 predictedLiquidity) = service.hook.prospectiveSwapState(params);

        uint256 predictedCapacity = service.hook.prospectiveSupportingCapacityAfterSwap(params);

        assertEq(
            predictedSqrtPriceX96,
            TickMath.getSqrtPriceAtTick(EXACT_BOUND_TICK_Q),
            "the worst-case path must be predicted to reach P_Q"
        );

        _swap(service, params);

        (uint160 actualSqrtPriceX96,, uint128 actualLiquidity) = _poolState(service);

        assertEq(predictedSqrtPriceX96, actualSqrtPriceX96, "the predicted price must be the price v4 produced");
        assertEq(predictedLiquidity, actualLiquidity, "the predicted liquidity must be the liquidity v4 produced");
        assertEq(
            predictedCapacity,
            service.hook.supportingCapacity(),
            "the predicted capacity must equal the capacity derived from the real post-state"
        );
        assertEq(service.hook.supportingCapacity(), 0, "capacity is exhausted at P_Q");
    }

    /// @notice Proves the same service derives its worst upward in-domain path within the bound.
    /// @dev The upward search skips the tick it starts from, so it can never spend the crossing step and
    ///      never visits more words. Running it establishes that the single demand figure covers both
    ///      directions rather than only the one it was derived from.
    function test_prospectiveSwap_derivesTheWorstUpwardInDomainPathOfAnExactlyBoundedService() public {
        DeployedService memory service = _deployService(_exactBoundConfig());

        _swap(service, _swapToTickLimit(true, -1_000_000_000_000_000_000, EXACT_BOUND_TICK_Q));

        (, int24 tickAtFloor,) = _poolState(service);

        assertLe(tickAtFloor, EXACT_BOUND_TICK_Q, "the pool must be resting on the domain floor");

        SwapParams memory params = _swapToTickLimit(false, -1_000_000_000_000_000_000, EXACT_BOUND_TICK_O);

        (uint160 predictedSqrtPriceX96, uint128 predictedLiquidity) = service.hook.prospectiveSwapState(params);

        _swap(service, params);

        (uint160 actualSqrtPriceX96,, uint128 actualLiquidity) = _poolState(service);

        assertEq(predictedSqrtPriceX96, actualSqrtPriceX96, "the predicted price must be the price v4 produced");
        assertEq(predictedLiquidity, actualLiquidity, "the predicted liquidity must be the liquidity v4 produced");
    }

    /*//////////////////////////////////////////////////////////////
                  G5-F — RUNTIME BOUND AS DEFENSIVE ONLY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the runtime bound is now reachable only by a path outside the service domain.
    /// @dev On an activated service every in-domain path is derivable by construction, so the only way to
    ///      reach the bound is a price limit beyond the configured domain — a transition the enforcement
    ///      slice will reject on its own terms. The bound is retained as defensive protection, which is
    ///      what this shows: it still refuses rather than truncating, and it refuses something that was
    ///      never a supported Standby operation.
    function test_prospectiveSwap_reachesTheRuntimeBoundOnlyOutsideTheServiceDomain() public {
        DeployedService memory service = _deployService(_exactBoundConfig());

        SwapParams memory params = _swapToTickLimit(true, -1_000_000_000_000_000_000, TickMath.MIN_TICK + 1);

        assertLt(
            params.sqrtPriceLimitX96,
            TickMath.getSqrtPriceAtTick(EXACT_BOUND_TICK_Q),
            "the limit must lie beyond the configured domain"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProspectiveSwapStepBoundExceeded.selector,
                service.hook.MAX_PROSPECTIVE_SWAP_STEPS()
            )
        );
        service.hook.prospectiveSwapState(params);
    }

    /// @notice Proves the capacity preview propagates that refusal rather than reporting a number.
    function test_prospectiveCapacity_propagatesTheRuntimeBoundRefusal() public {
        DeployedService memory service = _deployService(_exactBoundConfig());

        SwapParams memory params = _swapToTickLimit(true, -1_000_000_000_000_000_000, TickMath.MIN_TICK + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProspectiveSwapStepBoundExceeded.selector,
                service.hook.MAX_PROSPECTIVE_SWAP_STEPS()
            )
        );
        service.hook.prospectiveSupportingCapacityAfterSwap(params);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev A protected `zeroForOne` service whose traversal demand is exactly the supported bound.
    function _exactBoundConfig() internal pure returns (ServiceConfig memory config) {
        config = ServiceConfig({
            decimals0: 6,
            decimals1: 6,
            protectedZeroForOne: true,
            initialTick: EXACT_BOUND_TICK_O,
            tickQ: EXACT_BOUND_TICK_Q,
            tickO: EXACT_BOUND_TICK_O,
            lpTickLower: SPANNING_TICK_LOWER,
            lpTickUpper: SPANNING_TICK_UPPER,
            tickSpacing: 1,
            lpFee: 500,
            liquidity: SPANNING_LIQUIDITY
        });
    }

    /// @dev A domain far beyond the supported bound, at the finest tick spacing.
    function _farOverBoundConfig() internal pure returns (ServiceConfig memory config) {
        config = ServiceConfig({
            decimals0: 6,
            decimals1: 6,
            protectedZeroForOne: true,
            initialTick: 0,
            tickQ: -6_000,
            tickO: 6_000,
            lpTickLower: -6_000,
            lpTickUpper: 6_000,
            tickSpacing: 1,
            lpFee: 500,
            liquidity: SPANNING_LIQUIDITY
        });
    }

    /// @dev Asserts a rejected activation left no fragment of a Protected Execution Service behind.
    function _assertNoServicePersisted(DeployedService memory _service) internal view {
        StandbyHook.ProtectedExecutionService memory basis = _service.hook.protectedExecutionService();

        assertFalse(basis.configured, "no service-existence fact may persist");
        assertEq(Currency.unwrap(basis.poolKey.currency0), address(0), "no currency0 may persist");
        assertEq(Currency.unwrap(basis.poolKey.currency1), address(0), "no currency1 may persist");
        assertEq(uint256(basis.poolKey.fee), 0, "no fee may persist");
        assertEq(basis.poolKey.tickSpacing, int24(0), "no tick spacing may persist");
        assertEq(address(basis.poolKey.hooks), address(0), "no hook binding may persist");
        assertEq(address(basis.registry), address(0), "no registry may persist");
        assertFalse(basis.protectedZeroForOne, "no protected direction may persist");
        assertEq(basis.tickQ, int24(0), "no tickQ may persist");
        assertEq(basis.tickO, int24(0), "no tickO may persist");
        assertEq(basis.exerciseRouter, address(0), "no ExerciseRouter may persist");
        assertEq(basis.establishmentAuthority, address(0), "no establishment authority may persist");

        try _service.hook.serviceId() returns (PoolId) {
            assertTrue(false, "an unconfigured Hook must report no service identity");
        } catch {}
    }
}
