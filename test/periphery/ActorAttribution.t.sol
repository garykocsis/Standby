// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../../src/demo/ActorAwareTestRouter.sol";
import {IActorAwarePeriphery} from "../../src/interfaces/IActorAwarePeriphery.sol";
import {IEligibilityRegistry} from "../../src/interfaces/IEligibilityRegistry.sol";

import {BaseActorAwareStandbyTest} from "../shared/BaseActorAwareStandbyTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice A contract that answers the actor-attribution question with whatever it likes.
/// @dev Test instrumentation for the adversarial case. It implements the same interface the trusted
///      perimeters implement and names a genuinely eligible account as its originating user, which is
///      exactly the situation the authentication order exists to defeat: the interface is not the trust.
contract ForgingActorPeriphery is IActorAwarePeriphery, IUnlockCallback {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IPoolManager public immutable i_poolManager;

    address public claimedActor;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(IPoolManager _poolManager, address _claimedActor) {
        i_poolManager = _poolManager;
        claimedActor = _claimedActor;
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Attempts a swap on the real PoolManager while claiming an eligible originating user.
    /// @param _key The pool to swap against.
    /// @param _params The proposed swap.
    function swap(PoolKey calldata _key, SwapParams calldata _params) external {
        i_poolManager.unlock(abi.encode(_key, _params));
    }

    /// @notice Performs the claimed swap inside the unlock.
    /// @param _data The encoded pool key and swap parameters.
    /// @return result Unused; the transition is expected to be refused before settlement.
    function unlockCallback(bytes calldata _data) external returns (bytes memory result) {
        (PoolKey memory key, SwapParams memory params) = abi.decode(_data, (PoolKey, SwapParams));

        i_poolManager.swap(key, params, bytes(""));

        result = bytes("");
    }

    /// @inheritdoc IActorAwarePeriphery
    function msgSender() external view returns (address actor) {
        actor = claimedActor;
    }
}

/// @notice A Hook that re-enters a routed perimeter from inside a pool callback.
/// @dev Test instrumentation for the nested-context case, attached to its own unrelated pool. Standby's own
///      execution path offers no re-entry point, which is itself a good property, so proving the perimeter's
///      transaction-local state model requires an external source of re-entry. This is that source and
///      nothing more: it makes no Standby claim and guards no Standby pool.
contract ReenteringTestHook is BaseHook {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    ActorAwareTestRouter public immutable i_perimeter;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(IPoolManager _poolManager, ActorAwareTestRouter _perimeter) BaseHook(_poolManager) {
        i_perimeter = _perimeter;
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Declares the single callback this instrumentation needs.
    /// @return permissions The Hook permissions Uniswap v4 validates against the deployed address.
    function getHookPermissions() public pure override returns (Hooks.Permissions memory permissions) {
        permissions = Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Starts a second routed action while the first is still in flight.
    function _beforeSwap(address, PoolKey calldata _key, SwapParams calldata _params, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        i_perimeter.swap(_key, _params, bytes(""));

        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }
}

/// @notice Periphery evidence that only a trusted perimeter can supply an authenticated economic actor.
/// @dev The architectural boundary under test is an ordering rule as much as a trust rule. The Hook
///      authenticates that the callback sender is exactly the perimeter its immutable configuration
///      designates for that transition family, and only then asks that perimeter who the originating user
///      is. Reversing the order — ask, then decide whether to trust the answer — would let any contract
///      implementing the interface nominate an economic actor, which is precisely what these tests
///      demonstrate cannot happen.
///
///      The two trusted perimeters are separately deployed instances of identical bytecode, so the role
///      separation proven here is a property of configuration rather than of implementation differences.
contract ActorAttributionTest is BaseActorAwareStandbyTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A modest ordinary swap input, well inside the service domain.
    uint256 internal constant ORDINARY_SWAP_INPUT = 5_000 * 10 ** 6;

    /// @dev A modest position size for attribution evidence.
    int256 internal constant SUPPLEMENTARY_LIQUIDITY = 1_000_000_000;

    /*//////////////////////////////////////////////////////////////
                    22.1 — AUTHENTICATED ATTRIBUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the Hook asks the registry about the exact user who originated the routed swap.
    /// @dev Direct evidence of recovery rather than an inference from the outcome: the eligibility query the
    ///      Hook performs must name the originating user, not the perimeter, not the PoolManager, and not
    ///      the transaction origin.
    function test_ordinarySwap_queriesTraderEligibilityForTheOriginatingUser() public {
        vm.expectCall(address(registry), abi.encodeCall(IEligibilityRegistry.canSwap, (eligibleTrader)));

        _swapAs(eligibleTrader, _protectedSwapParams(ORDINARY_SWAP_INPUT));
    }

    /// @notice Proves the same recovery happens on the liquidity path, through its own perimeter.
    function test_liquidityAddition_queriesLiquidityEligibilityForTheOriginatingUser() public {
        vm.expectCall(address(registry), abi.encodeCall(IEligibilityRegistry.canProvideLiquidity, (exitingProvider)));

        _modifyLiquidityAs(
            exitingProvider,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            )
        );
    }

    /// @notice Proves attribution distinguishes users rather than authorizing the perimeter as a whole.
    /// @dev Same perimeter, same pool, same swap, two different originating users, opposite outcomes.
    function test_ordinarySwap_attributesTheOriginatingUserAndNotThePerimeter() public {
        _swapAs(eligibleTrader, _protectedSwapParams(ORDINARY_SWAP_INPUT));

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__TraderNotEligible.selector, ineligibleTrader)
        );
        _swapAs(ineligibleTrader, _protectedSwapParams(ORDINARY_SWAP_INPUT));
    }

    /// @notice Proves the perimeter itself is never mistaken for the economic actor.
    /// @dev Making the perimeter contract eligible must change nothing: it is transport, not a participant.
    function test_ordinarySwap_isNotAuthorizedByMakingThePerimeterEligible() public {
        _setTraderEligibility(address(swapPerimeter), true);

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__TraderNotEligible.selector, ineligibleTrader)
        );
        _swapAs(ineligibleTrader, _protectedSwapParams(ORDINARY_SWAP_INPUT));
    }

    /*//////////////////////////////////////////////////////////////
                  22.2 — UNTRUSTED ATTESTOR REJECTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an untrusted contract cannot establish an economic identity by claiming one.
    /// @dev The claimed actor is genuinely eligible, so eligibility cannot be what refuses this. The
    ///      perimeter is refused on its own identity, and the claim is never consulted: the forging
    ///      contract's attribution function is not called at all.
    function test_untrustedAttestor_cannotEstablishAnEconomicActor() public {
        ForgingActorPeriphery forging = new ForgingActorPeriphery(poolManager, eligibleTrader);

        assertTrue(registry.canSwap(forging.claimedActor()), "the claimed actor must genuinely be eligible");

        vm.expectCall(address(forging), abi.encodeCall(IActorAwarePeriphery.msgSender, ()), 0);

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__UntrustedSwapPerimeter.selector, address(forging))
        );
        vm.prank(ineligibleTrader);
        forging.swap(servicePoolKey, _protectedSwapParams(ORDINARY_SWAP_INPUT));
    }

    /*//////////////////////////////////////////////////////////////
                        22.3 — FORGED HOOK DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a hook payload naming an eligible user cannot displace the authenticated actor.
    /// @dev Delivered through the genuinely trusted perimeter, so the only thing being tested is whether
    ///      caller-supplied data can substitute for authenticated provenance.
    function test_forgedHookData_cannotDisplaceTheAuthenticatedActor() public {
        vm.expectCall(address(registry), abi.encodeCall(IEligibilityRegistry.canSwap, (ineligibleTrader)));

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__TraderNotEligible.selector, ineligibleTrader)
        );
        _swapAs(ineligibleTrader, _protectedSwapParams(ORDINARY_SWAP_INPUT), abi.encode(eligibleTrader));
    }

    /*//////////////////////////////////////////////////////////////
                     22.4 — PERIMETER ROLE CROSSING
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the trusted swap perimeter cannot authorize a liquidity action.
    function test_swapPerimeter_cannotAuthorizeALiquidityAction() public {
        _expectHookRejection(
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__UntrustedLiquidityPerimeter.selector, address(swapPerimeter)
            )
        );
        vm.prank(exitingProvider);
        swapPerimeter.modifyLiquidity(
            servicePoolKey,
            _liquidityParams(
                StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, SUPPLEMENTARY_LIQUIDITY
            ),
            bytes("")
        );
    }

    /// @notice Proves the trusted liquidity perimeter cannot authorize an ordinary swap.
    function test_liquidityPerimeter_cannotAuthorizeAnOrdinarySwap() public {
        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__UntrustedSwapPerimeter.selector, address(liquidityPerimeter)
            )
        );
        vm.prank(eligibleTrader);
        liquidityPerimeter.swap(servicePoolKey, _protectedSwapParams(ORDINARY_SWAP_INPUT), bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                     22.5 — INACTIVE ACTOR CONTEXT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a trusted perimeter exposes no usable actor outside a routed action.
    /// @dev It fails closed rather than returning its caller or the transaction origin. An absent execution
    ///      context is not an economic actor, and a plausible substitute would be worse than no answer.
    function test_trustedPerimeter_exposesNoActorWithoutARoutedAction() public {
        vm.expectRevert(ActorAwareTestRouter.ActorAwareTestRouter__NoActiveActorContext.selector);
        swapPerimeter.msgSender();

        vm.prank(eligibleTrader);
        vm.expectRevert(ActorAwareTestRouter.ActorAwareTestRouter__NoActiveActorContext.selector);
        liquidityPerimeter.msgSender();
    }

    /// @notice Proves the actor context does not survive the routed action that established it.
    function test_actorContext_isClearedAfterARoutedAction() public {
        _swapAs(eligibleTrader, _protectedSwapParams(ORDINARY_SWAP_INPUT));

        vm.expectRevert(ActorAwareTestRouter.ActorAwareTestRouter__NoActiveActorContext.selector);
        swapPerimeter.msgSender();
    }

    /*//////////////////////////////////////////////////////////////
                      22.6 — NESTED ACTOR CONTEXT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a second routed action attempted inside the first is refused.
    /// @dev The re-entry comes from an unrelated pool's own Hook, because Standby's execution path exposes
    ///      no re-entry point of its own. What matters is the perimeter's answer: one routed action carries
    ///      exactly one originator, and a nested one is rejected rather than stacked or silently replaced.
    function test_nestedRoutedAction_isRejected() public {
        ReenteringTestHook reenteringHook = _deployReenteringHook();

        PoolKey memory reentrantKey = servicePoolKey;
        reentrantKey.fee = 3000;
        reentrantKey.hooks = IHooks(address(reenteringHook));

        poolManager.initialize(reentrantKey, TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.INITIAL_TICK));

        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(reenteringHook),
                IHooks.beforeSwap.selector,
                abi.encodeWithSelector(
                    ActorAwareTestRouter.ActorAwareTestRouter__ActorContextAlreadyActive.selector, eligibleTrader
                ),
                abi.encodePacked(Hooks.HookCallFailed.selector)
            )
        );
        vm.prank(eligibleTrader);
        swapPerimeter.swap(reentrantKey, _protectedSwapParams(ORDINARY_SWAP_INPUT), bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mines and deploys the re-entering instrumentation Hook at a permission-valid address.
    function _deployReenteringHook() internal returns (ReenteringTestHook deployed) {
        bytes memory constructorArgs = abi.encode(poolManager, swapPerimeter);

        (, bytes32 salt) = HookMiner.find(
            address(this), uint160(Hooks.BEFORE_SWAP_FLAG), type(ReenteringTestHook).creationCode, constructorArgs
        );

        deployed = new ReenteringTestHook{salt: salt}(poolManager, swapPerimeter);
    }
}
