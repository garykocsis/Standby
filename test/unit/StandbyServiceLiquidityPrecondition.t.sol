// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {IEligibilityRegistry} from "../../src/interfaces/IEligibilityRegistry.sol";

import {LiquidityPermissiveStandbyHookHarness} from "../harness/LiquidityPermissiveStandbyHookHarness.sol";
import {BaseStandbyServiceTest} from "../shared/BaseStandbyServiceTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Isolated evidence for the zero-liquidity activation precondition (G3-C 5).
/// @dev This is the one F3 activation condition that no production path can currently reach. The
///      production `beforeAddLiquidity` callback is fail-closed until F6A, so a StandbyHook-bound pool
///      cannot acquire liquidity, and the guard would otherwise be untestable.
///
///      The isolation is limited to unblocking the F6A-owned liquidity callback:
///      `LiquidityPermissiveStandbyHookHarness` overrides that one callback and inherits
///      `configureAndActivate` unchanged. Everything the guard reads is authoritative: a real pinned
///      `PoolManager`, real liquidity added through the official `PoolModifyLiquidityTest` router, and
///      the production `StateLibrary.getLiquidity` read performed by the production activation path.
///      No economic state is seeded and no storage is written directly.
contract StandbyServiceLiquidityPreconditionTest is BaseStandbyServiceTest {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Round over-provision for the canonical liquidity position.
    uint256 internal constant LP_FUNDING = 1_000_000 * 10 ** 6;

    PoolModifyLiquidityTest internal liquidityRouter;

    LiquidityPermissiveStandbyHookHarness internal harnessHook;
    PoolKey internal harnessPoolKey;
    PoolId internal harnessPoolId;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds a real liquidity router and a liquidity-permissive Hook over the fixture currencies.
    function setUp() public override {
        super.setUp();

        liquidityRouter = new PoolModifyLiquidityTest(poolManager);

        harnessHook = _deployHarnessHook();

        harnessPoolKey =
            _poolKeyFor(IHooks(address(harnessHook)), StandbyFixtureConfig.LP_FEE, StandbyFixtureConfig.TICK_SPACING);
        harnessPoolId = harnessPoolKey.toId();

        _initializePoolAtTick(harnessPoolKey, StandbyFixtureConfig.INITIAL_TICK);

        ustb.mint(address(this), LP_FUNDING);
        usdc.mint(address(this), LP_FUNDING);

        ustb.approve(address(liquidityRouter), type(uint256).max);
        usdc.approve(address(liquidityRouter), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                     G3-C 5 — ZERO-LIQUIDITY GUARD
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves activation is rejected when the pool already holds authoritative active liquidity.
    function test_configureAndActivate_rejectsAPoolThatAlreadyHoldsLiquidity() public {
        _addCanonicalLiquidity();

        uint128 activeLiquidity = poolManager.getLiquidity(harnessPoolId);

        assertEq(activeLiquidity, StandbyFixtureConfig.CANONICAL_LIQUIDITY, "the pool must hold real liquidity");

        vm.prank(configurationAuthority);
        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__PoolLiquidityNotZero.selector, activeLiquidity));
        harnessHook.configureAndActivate(
            harnessPoolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(harnessHook);
    }

    /// @notice Proves the guard reads authoritative PoolManager liquidity rather than a Standby fact.
    /// @dev The identical Hook, pool, and activation arguments succeed before liquidity exists and fail
    ///      after it does. The only thing that changed between the two attempts is real PoolManager
    ///      state, so the rejection above cannot be an artifact of the harness.
    function test_configureAndActivate_acceptsTheSameHookAndPoolBeforeLiquidityExists() public {
        assertEq(poolManager.getLiquidity(harnessPoolId), 0, "the pool must start empty");

        vm.prank(configurationAuthority);
        harnessHook.configureAndActivate(
            harnessPoolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        assertTrue(harnessHook.protectedExecutionService().configured, "the empty pool must activate");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mines and deploys the liquidity-permissive harness at a permission-valid Hook address.
    function _deployHarnessHook() internal returns (LiquidityPermissiveStandbyHookHarness deployed) {
        bytes memory constructorArgs =
            abi.encode(poolManager, configurationAuthority, trustedUniversalRouter, trustedPositionManager);

        (, bytes32 salt) = HookMiner.find(
            address(this),
            hookDeployer.REQUIRED_HOOK_PERMISSION_MASK(),
            type(LiquidityPermissiveStandbyHookHarness).creationCode,
            constructorArgs
        );

        deployed = new LiquidityPermissiveStandbyHookHarness{salt: salt}(
            poolManager, configurationAuthority, trustedUniversalRouter, trustedPositionManager
        );
    }

    /// @dev Adds the canonical liquidity position through the official v4 execution path.
    function _addCanonicalLiquidity() internal {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: StandbyFixtureConfig.LP_TICK_LOWER,
            tickUpper: StandbyFixtureConfig.LP_TICK_UPPER,
            liquidityDelta: int256(uint256(StandbyFixtureConfig.CANONICAL_LIQUIDITY)),
            salt: bytes32(0)
        });

        liquidityRouter.modifyLiquidity(harnessPoolKey, params, bytes(""));
    }
}
