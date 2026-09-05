// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {ImmutableState} from "v4-periphery/src/base/ImmutableState.sol";

import {DeployStandbyHook} from "../../script/DeployStandbyHook.s.sol";
import {HelperConfig} from "../../script/helpers/HelperConfig.s.sol";
import {NetworkConfig} from "../../script/helpers/NetworkConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for the canonical StandbyHook deployment procedure (G0-H1..G0-H5).
/// @dev This contract deliberately does not inherit `BaseV4Test` and deploys no currencies, no pool,
///      and no Standby economic fixture. Hook deployment must be provable without any of them.
contract StandbyHookDeploymentTest is Test {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The frozen Standby Hook permission mask, restated independently of production code.
    uint160 internal constant FROZEN_PERMISSION_MASK = 0x0AC0;

    PoolManager internal poolManager;
    DeployStandbyHook internal deployScript;

    StandbyHook internal hook;
    bytes32 internal hookSalt;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a real PoolManager and the Hook through the canonical deployment procedure.
    function setUp() public {
        poolManager = new PoolManager(address(this));
        deployScript = new DeployStandbyHook();

        (hook, hookSalt) = deployScript.deployStandbyHook(IPoolManager(address(poolManager)), address(deployScript));
    }

    /*//////////////////////////////////////////////////////////////
                     G0-H1 — EXACT HOOK PERMISSIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves StandbyHook declares exactly the four authorized callbacks and nothing else.
    function test_standbyHook_declaresExactlyTheAuthorizedCallbackPermissions() public view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();

        assertTrue(permissions.beforeAddLiquidity, "beforeAddLiquidity must be enabled");
        assertTrue(permissions.beforeRemoveLiquidity, "beforeRemoveLiquidity must be enabled");
        assertTrue(permissions.beforeSwap, "beforeSwap must be enabled");
        assertTrue(permissions.afterSwap, "afterSwap must be enabled");

        assertFalse(permissions.beforeInitialize, "beforeInitialize must be disabled");
        assertFalse(permissions.afterInitialize, "afterInitialize must be disabled");
        assertFalse(permissions.afterAddLiquidity, "afterAddLiquidity must be disabled");
        assertFalse(permissions.afterRemoveLiquidity, "afterRemoveLiquidity must be disabled");
        assertFalse(permissions.beforeDonate, "beforeDonate must be disabled");
        assertFalse(permissions.afterDonate, "afterDonate must be disabled");
    }

    /// @notice Proves every return-delta / custom-accounting permission is disabled.
    function test_standbyHook_declaresNoReturnDeltaPermissions() public view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();

        assertFalse(permissions.beforeSwapReturnDelta, "beforeSwapReturnDelta must be disabled");
        assertFalse(permissions.afterSwapReturnDelta, "afterSwapReturnDelta must be disabled");
        assertFalse(permissions.afterAddLiquidityReturnDelta, "afterAddLiquidityReturnDelta must be disabled");
        assertFalse(permissions.afterRemoveLiquidityReturnDelta, "afterRemoveLiquidityReturnDelta must be disabled");
    }

    /// @notice Proves the Hook's declared permissions, the deployment mining requirement, the frozen
    ///         expected value, and the deployed address all describe the same permission set.
    /// @dev The Hook permission declaration and the deployment mining mask are separate
    ///      representations. This test establishes their equivalence rather than assuming it. The
    ///      mask compared against them is reconstructed here field-by-field from the declared struct
    ///      using the pinned `Hooks` flag constants; it does not repeat the deployment derivation,
    ///      which simply ORs four fixed flags.
    function test_permissionMask_isEquivalentAcrossDeclarationDeploymentAndAddress() public view {
        uint160 derivedMask = _deriveMask(hook.getHookPermissions());

        assertEq(derivedMask, FROZEN_PERMISSION_MASK, "declared permissions must match the frozen mask");
        assertEq(uint256(derivedMask), 2752, "frozen mask must equal 2752");

        assertEq(
            deployScript.REQUIRED_HOOK_PERMISSION_MASK(),
            derivedMask,
            "deployment mining mask must match the declared permissions"
        );

        assertEq(
            uint160(address(hook)) & Hooks.ALL_HOOK_MASK,
            derivedMask,
            "deployed address bits must match the declared permissions"
        );
    }

    /*//////////////////////////////////////////////////////////////
                   G0-H2 — ADDRESS PERMISSION VALIDITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the deployed address encodes exactly the required permission bits.
    /// @dev Checked against the pinned `Hooks` implementation: each authorized flag is present, each
    ///      unauthorized flag is absent, and the masked address equals the required mask.
    function test_deployedHookAddress_encodesExactlyTheRequiredPermissionBits() public view {
        IHooks deployed = IHooks(address(hook));

        assertEq(
            uint256(uint160(address(hook)) & Hooks.ALL_HOOK_MASK),
            uint256(FROZEN_PERMISSION_MASK),
            "deployed address must encode the frozen permission mask"
        );

        assertTrue(Hooks.hasPermission(deployed, Hooks.BEFORE_ADD_LIQUIDITY_FLAG), "address: beforeAddLiquidity");
        assertTrue(Hooks.hasPermission(deployed, Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG), "address: beforeRemoveLiquidity");
        assertTrue(Hooks.hasPermission(deployed, Hooks.BEFORE_SWAP_FLAG), "address: beforeSwap");
        assertTrue(Hooks.hasPermission(deployed, Hooks.AFTER_SWAP_FLAG), "address: afterSwap");

        assertFalse(Hooks.hasPermission(deployed, Hooks.BEFORE_INITIALIZE_FLAG), "address: beforeInitialize");
        assertFalse(Hooks.hasPermission(deployed, Hooks.AFTER_INITIALIZE_FLAG), "address: afterInitialize");
        assertFalse(Hooks.hasPermission(deployed, Hooks.AFTER_ADD_LIQUIDITY_FLAG), "address: afterAddLiquidity");
        assertFalse(Hooks.hasPermission(deployed, Hooks.AFTER_REMOVE_LIQUIDITY_FLAG), "address: afterRemoveLiquidity");
        assertFalse(Hooks.hasPermission(deployed, Hooks.BEFORE_DONATE_FLAG), "address: beforeDonate");
        assertFalse(Hooks.hasPermission(deployed, Hooks.AFTER_DONATE_FLAG), "address: afterDonate");
        assertFalse(Hooks.hasPermission(deployed, Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG), "address: beforeSwapDelta");
        assertFalse(Hooks.hasPermission(deployed, Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG), "address: afterSwapDelta");
        assertFalse(
            Hooks.hasPermission(deployed, Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG), "address: addLiquidityDelta"
        );
        assertFalse(
            Hooks.hasPermission(deployed, Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG),
            "address: removeLiquidityDelta"
        );
    }

    /// @notice Proves the pinned v4 validator accepts the deployed address against the declared struct.
    function test_deployedHookAddress_satisfiesPinnedHookValidator() public view {
        Hooks.validateHookPermissions(IHooks(address(hook)), hook.getHookPermissions());
    }

    /*//////////////////////////////////////////////////////////////
                      G0-H3 — POOLMANAGER BINDING
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the deployed Hook is bound to the intended real PoolManager.
    function test_deployedHook_isBoundToTheIntendedPoolManager() public view {
        assertEq(address(hook.poolManager()), address(poolManager), "hook must bind the intended PoolManager");
    }

    /// @notice Proves the binding is enforced: an enabled callback rejects a non-PoolManager caller.
    function test_deployedHook_rejectsCallbacksFromNonPoolManager() public {
        PoolKey memory key;
        SwapParams memory params;

        vm.expectRevert(ImmutableState.NotPoolManager.selector);
        hook.beforeSwap(address(this), key, params, "");
    }

    /// @notice Records the current F0 implementation state: enabled callbacks are not implemented yet.
    /// @dev F0 deploys the required permission surface without weakening it, so the enabled callbacks
    ///      exist but carry no behavior. This is an implementation-state regression test for F0, not a
    ///      Standby economic invariant: the later enforcement slices are expected to replace this
    ///      `HookNotImplemented` revert with authoritative behavior and to retire this test.
    function test_enabledCallbacks_failClosedUntilEnforcementIsImplemented() public {
        PoolKey memory key;
        SwapParams memory params;

        vm.prank(address(poolManager));
        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.beforeSwap(address(this), key, params, "");
    }

    /*//////////////////////////////////////////////////////////////
                   G0-H4 — DETERMINISTIC DEPLOYMENT PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the deployed address is the deterministic CREATE2 address for the mined salt.
    function test_canonicalDeployment_producesTheDeterministicMinedAddress() public view {
        bytes memory creationCodeWithArgs =
            abi.encodePacked(type(StandbyHook).creationCode, abi.encode(IPoolManager(address(poolManager))));

        address expected = HookMiner.computeAddress(address(deployScript), uint256(hookSalt), creationCodeWithArgs);

        assertEq(expected, address(hook), "deployed address must equal the mined CREATE2 address");
    }

    /// @notice Proves the canonical procedure composes with the canonical infrastructure resolution.
    /// @dev This is the composition `run()` performs, exercised without broadcast routing.
    function test_canonicalDeployment_usesHelperConfigResolvedPoolManager() public {
        HelperConfig helperConfig = new HelperConfig();
        NetworkConfig memory config = helperConfig.getNetworkConfig();

        assertEq(config.chainId, block.chainid, "config must describe the active chain");
        assertGt(config.poolManager.code.length, 0, "config must resolve a deployed PoolManager");

        DeployStandbyHook configuredDeployScript = new DeployStandbyHook();
        (StandbyHook configuredHook,) =
            configuredDeployScript.deployStandbyHook(IPoolManager(config.poolManager), address(configuredDeployScript));

        assertEq(address(configuredHook.poolManager()), config.poolManager, "hook must bind the resolved PoolManager");
        assertEq(
            uint256(uint160(address(configuredHook)) & Hooks.ALL_HOOK_MASK),
            uint256(FROZEN_PERMISSION_MASK),
            "resolved-infrastructure deployment must still be permission-valid"
        );
    }

    /// @notice Proves infrastructure resolution rejects chains with no validated v4 deployment.
    function test_helperConfig_rejectsUnsupportedNetwork() public {
        HelperConfig helperConfig = new HelperConfig();

        vm.chainId(1);

        vm.expectRevert(abi.encodeWithSelector(HelperConfig.HelperConfig__UnsupportedNetwork.selector, uint256(1)));
        helperConfig.getNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                      G0-H5 — FIXTURE INDEPENDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the deployment procedure is reusable and needs no economic fixture.
    /// @dev A second Hook is deployed against a second real PoolManager with no currencies, no pool,
    ///      no token ordering, no protected direction, and no commitment or service configuration in
    ///      existence. Each Hook keeps its own PoolManager binding.
    function test_hookDeployment_requiresNoEconomicFixture() public {
        PoolManager otherPoolManager = new PoolManager(address(this));
        DeployStandbyHook otherDeployScript = new DeployStandbyHook();

        (StandbyHook otherHook,) =
            otherDeployScript.deployStandbyHook(IPoolManager(address(otherPoolManager)), address(otherDeployScript));

        assertTrue(address(otherHook) != address(hook), "independent deployments must be distinct");

        assertEq(address(otherHook.poolManager()), address(otherPoolManager), "second hook binding");
        assertEq(address(hook.poolManager()), address(poolManager), "first hook binding must be unchanged");

        assertEq(
            uint256(uint160(address(otherHook)) & Hooks.ALL_HOOK_MASK),
            uint256(FROZEN_PERMISSION_MASK),
            "second deployment must be permission-valid"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Independent reconstruction of the permission mask from a declared permission struct,
    ///      using the pinned `Hooks` flag constants. It must not read the production mask constant.
    function _deriveMask(Hooks.Permissions memory permissions) internal pure returns (uint160 mask) {
        if (permissions.beforeInitialize) mask |= Hooks.BEFORE_INITIALIZE_FLAG;
        if (permissions.afterInitialize) mask |= Hooks.AFTER_INITIALIZE_FLAG;
        if (permissions.beforeAddLiquidity) mask |= Hooks.BEFORE_ADD_LIQUIDITY_FLAG;
        if (permissions.afterAddLiquidity) mask |= Hooks.AFTER_ADD_LIQUIDITY_FLAG;
        if (permissions.beforeRemoveLiquidity) mask |= Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG;
        if (permissions.afterRemoveLiquidity) mask |= Hooks.AFTER_REMOVE_LIQUIDITY_FLAG;
        if (permissions.beforeSwap) mask |= Hooks.BEFORE_SWAP_FLAG;
        if (permissions.afterSwap) mask |= Hooks.AFTER_SWAP_FLAG;
        if (permissions.beforeDonate) mask |= Hooks.BEFORE_DONATE_FLAG;
        if (permissions.afterDonate) mask |= Hooks.AFTER_DONATE_FLAG;
        if (permissions.beforeSwapReturnDelta) mask |= Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG;
        if (permissions.afterSwapReturnDelta) mask |= Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        if (permissions.afterAddLiquidityReturnDelta) mask |= Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG;
        if (permissions.afterRemoveLiquidityReturnDelta) mask |= Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG;
    }
}
