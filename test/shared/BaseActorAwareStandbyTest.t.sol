// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {DeployStandbyHook} from "../../script/DeployStandbyHook.s.sol";
import {DeterministicFixtureDeployer} from "../../script/helpers/DeterministicFixtureDeployer.sol";
import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../../src/demo/ActorAwareTestRouter.sol";
import {IEligibilityRegistry} from "../../src/interfaces/IEligibilityRegistry.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockUSTB} from "../../src/mocks/MockUSTB.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared real-path fixture for F6A ordinary-transition enforcement evidence.
/// @dev Every fact this fixture establishes is established the way production would establish it: the real
///      pinned `PoolManager`, the canonical `DeployStandbyHook` mining and deployment procedure, the F1
///      deterministic ordered fixture currencies, the F2 `EligibilityRegistry` under its own administrator,
///      the production `configureAndActivate` transition, and — for the canonical liquidity itself — the
///      production `beforeAddLiquidity` enforcement path through the trusted liquidity perimeter.
///
///      Nothing is seeded. No Supporting Capacity is written, no Aggregate Capacity Obligation is written,
///      no commitment is created, no bounded reference is written, no Hook storage is touched directly, no
///      PoolManager state is manufactured, no prospective state is injected, no actor context is faked, and
///      no transition is pre-authorized. The Hook deployed here is the production `StandbyHook`: no harness
///      is involved anywhere in this fixture, because every property it supports evidence for is a claim
///      about a real authoritative transition.
///
///      At bootstrap the service therefore stands at canonical initial Supporting Capacity with Aggregate
///      Capacity Obligation zero and no commitment in existence. The obligation is zero because commitment
///      admission does not exist yet, which is a fact about the reachable state, not an assumption anything
///      here or in the Hook is allowed to make.
///
///      The trusted ordinary-swap perimeter and the trusted liquidity perimeter are two separately deployed
///      instances of the same `ActorAwareTestRouter` bytecode. Identical code, distinct roles: this is what
///      makes it directly provable that a perimeter trusted for one transition family authorizes nothing in
///      the other, without inventing two implementations to manufacture the difference.
abstract contract BaseActorAwareStandbyTest is Test {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Round over-provision. The canonical position needs roughly 99,850 of each currency.
    uint256 internal constant ACTOR_FUNDING = 1_000_000 * 10 ** 6;

    address internal configurationAuthority;
    address internal exerciseRouter;
    address internal establishmentAuthority;
    address internal registryAdmin;

    address internal eligibleTrader;
    address internal ineligibleTrader;
    address internal canonicalProvider;
    address internal exitingProvider;
    address internal ineligibleProvider;

    IPoolManager internal poolManager;

    ActorAwareTestRouter internal swapPerimeter;
    ActorAwareTestRouter internal liquidityPerimeter;

    DeployStandbyHook internal hookDeployer;
    StandbyHook internal hook;
    EligibilityRegistry internal registry;

    DeterministicFixtureDeployer internal fixtureDeployer;
    MockUSTB internal ustb;
    MockUSDC internal usdc;

    PoolKey internal servicePoolKey;
    PoolId internal servicePoolId;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Builds the activated canonical Standby service and its canonical liquidity, through real
    ///         deployment, configuration, and production-transition paths only.
    function setUp() public virtual {
        configurationAuthority = makeAddr("configurationAuthority");
        exerciseRouter = makeAddr("exerciseRouter");
        establishmentAuthority = makeAddr("establishmentAuthority");
        registryAdmin = makeAddr("registryAdmin");

        eligibleTrader = makeAddr("eligibleTrader");
        ineligibleTrader = makeAddr("ineligibleTrader");
        canonicalProvider = makeAddr("canonicalProvider");
        exitingProvider = makeAddr("exitingProvider");
        ineligibleProvider = makeAddr("ineligibleProvider");

        poolManager = IPoolManager(address(new PoolManager(address(this))));

        swapPerimeter = new ActorAwareTestRouter(poolManager);
        liquidityPerimeter = new ActorAwareTestRouter(poolManager);

        hookDeployer = new DeployStandbyHook();
        (hook,) = hookDeployer.deployStandbyHook(
            poolManager,
            address(hookDeployer),
            configurationAuthority,
            address(swapPerimeter),
            address(liquidityPerimeter)
        );

        registry = new EligibilityRegistry(registryAdmin);

        fixtureDeployer = new DeterministicFixtureDeployer();
        (ustb, usdc,) = fixtureDeployer.deployOrderedFixtureCurrencies();

        servicePoolKey = PoolKey({
            currency0: Currency.wrap(address(ustb)),
            currency1: Currency.wrap(address(usdc)),
            fee: StandbyFixtureConfig.LP_FEE,
            tickSpacing: StandbyFixtureConfig.TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        servicePoolId = servicePoolKey.toId();

        poolManager.initialize(servicePoolKey, TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.INITIAL_TICK));

        vm.prank(configurationAuthority);
        hook.configureAndActivate(
            servicePoolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _setTraderEligibility(eligibleTrader, true);
        _setLiquidityEligibility(canonicalProvider, true);
        _setLiquidityEligibility(exitingProvider, true);

        _fundAndApprove(eligibleTrader);
        _fundAndApprove(ineligibleTrader);
        _fundAndApprove(canonicalProvider);
        _fundAndApprove(exitingProvider);
        _fundAndApprove(ineligibleProvider);

        _modifyLiquidityAs(
            canonicalProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER,
                StandbyFixtureConfig.LP_TICK_UPPER,
                int256(uint256(StandbyFixtureConfig.CANONICAL_LIQUIDITY))
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Routes a swap as an originating user, through the trusted ordinary-swap perimeter.
    function _swapAs(address _actor, SwapParams memory _params) internal returns (BalanceDelta delta) {
        delta = _swapAs(_actor, _params, bytes(""));
    }

    /// @dev Routes a swap as an originating user, with an arbitrary hook payload.
    function _swapAs(address _actor, SwapParams memory _params, bytes memory _hookData)
        internal
        returns (BalanceDelta delta)
    {
        vm.prank(_actor);
        delta = swapPerimeter.swap(servicePoolKey, _params, _hookData);
    }

    /// @dev Routes a liquidity modification as an originating user, through the trusted liquidity perimeter.
    function _modifyLiquidityAs(address _actor, ModifyLiquidityParams memory _params)
        internal
        returns (BalanceDelta delta)
    {
        delta = _modifyLiquidityAs(_actor, _params, bytes(""));
    }

    /// @dev Routes a liquidity modification as an originating user, with an arbitrary hook payload.
    function _modifyLiquidityAs(address _actor, ModifyLiquidityParams memory _params, bytes memory _hookData)
        internal
        returns (BalanceDelta delta)
    {
        vm.prank(_actor);
        delta = liquidityPerimeter.modifyLiquidity(servicePoolKey, _params, _hookData);
    }

    /// @dev Builds swap parameters whose reachable path stops at a chosen tick's exact price.
    function _swapParams(bool _zeroForOne, int256 _amountSpecified, int24 _limitTick)
        internal
        pure
        returns (SwapParams memory params)
    {
        params = SwapParams({
            zeroForOne: _zeroForOne,
            amountSpecified: _amountSpecified,
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(_limitTick)
        });
    }

    /// @dev Builds an exact-input protected-direction swap confined to the service domain.
    function _protectedSwapParams(uint256 _amountIn) internal pure returns (SwapParams memory params) {
        params = _swapParams(true, -int256(_amountIn), StandbyFixtureConfig.TICK_Q);
    }

    /// @dev Builds an exact-input opposite-direction swap confined to the service domain.
    function _oppositeSwapParams(uint256 _amountIn) internal pure returns (SwapParams memory params) {
        params = _swapParams(false, -int256(_amountIn), StandbyFixtureConfig.TICK_O);
    }

    /// @dev Builds liquidity-modification parameters.
    function _liquidityParams(int24 _tickLower, int24 _tickUpper, int256 _liquidityDelta)
        internal
        pure
        returns (ModifyLiquidityParams memory params)
    {
        params = ModifyLiquidityParams({
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            liquidityDelta: _liquidityDelta,
            salt: bytes32(0)
        });
    }

    /// @dev Grants or revokes trader eligibility through the registry's own administrator.
    function _setTraderEligibility(address _account, bool _eligible) internal {
        vm.prank(registryAdmin);
        registry.setTraderEligibility(_account, _eligible);
    }

    /// @dev Grants or revokes liquidity-action eligibility through the registry's own administrator.
    function _setLiquidityEligibility(address _account, bool _eligible) internal {
        vm.prank(registryAdmin);
        registry.setLiquidityEligibility(_account, _eligible);
    }

    /// @dev Funds an actor with both fixture currencies and approves both perimeters on its behalf.
    function _fundAndApprove(address _account) internal {
        ustb.mint(_account, ACTOR_FUNDING);
        usdc.mint(_account, ACTOR_FUNDING);

        vm.startPrank(_account);

        ustb.approve(address(swapPerimeter), type(uint256).max);
        usdc.approve(address(swapPerimeter), type(uint256).max);
        ustb.approve(address(liquidityPerimeter), type(uint256).max);
        usdc.approve(address(liquidityPerimeter), type(uint256).max);

        vm.stopPrank();
    }

    /// @dev Reads the authoritative current square-root price, tick, and active liquidity of the service.
    function _servicePoolState() internal view returns (uint160 sqrtPriceX96, int24 tick, uint128 liquidity) {
        (sqrtPriceX96, tick,,) = poolManager.getSlot0(servicePoolId);

        liquidity = poolManager.getLiquidity(servicePoolId);
    }

    /// @dev Expects the revert Uniswap produces when a Hook callback rejects a transition.
    ///
    ///      A failed hook call is wrapped by the pinned `Hooks` library rather than bubbled raw, so the
    ///      assertion must name the wrapper, the Hook, the callback, and the Standby reason inside it.
    ///      Matching only the wrapper would accept any rejection at all.
    function _expectHookRejection(bytes4 _callbackSelector, bytes memory _reason) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                _callbackSelector,
                _reason,
                abi.encodePacked(Hooks.HookCallFailed.selector)
            )
        );
    }
}
