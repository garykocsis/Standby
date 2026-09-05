// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {StandbyHook} from "../src/StandbyHook.sol";

import {HelperConfig} from "./helpers/HelperConfig.s.sol";
import {NetworkConfig} from "./helpers/NetworkConfig.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title DeployStandbyHook
/// @notice The single canonical StandbyHook deployment procedure.
/// @dev Reused by tests, deterministic local Anvil deployment, and later public/production
///      deployment. The procedure is fixture-agnostic: it resolves infrastructure only and knows
///      nothing about Standby currencies, pool keys, service boundaries, or demo actors.
contract DeployStandbyHook is Script {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Hook-address permission bits this deployment procedure must mine for.
    /// @dev The deployment requirement, derived here from the pinned Uniswap v4 `Hooks` flag
    ///      constants. It is a separate representation from `StandbyHook.getHookPermissions()`; the
    ///      two are independent declarations whose equivalence is established by verification, not by
    ///      construction. `_validateDeployedHook` additionally checks the deployed address against the
    ///      Hook's own declared permissions through the pinned validator.
    uint160 public constant REQUIRED_HOOK_PERMISSION_MASK = uint160(
        Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
            | Hooks.AFTER_SWAP_FLAG
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the deployed Hook is not at the deterministically derived address.
    /// @param expected The address derived by the pinned Uniswap v4 Hook-address rules.
    /// @param deployed The address the Hook actually deployed to.
    error DeployStandbyHook__HookAddressMismatch(address expected, address deployed);

    /// @notice Thrown when the deployed Hook address does not encode exactly the required permissions.
    /// @param expected The required Hook permission mask.
    /// @param actual The permission bits actually encoded by the deployed address.
    error DeployStandbyHook__HookPermissionMaskMismatch(uint160 expected, uint160 actual);

    /// @notice Thrown when the deployed Hook is not bound to the intended PoolManager.
    /// @param expected The intended PoolManager.
    /// @param actual The PoolManager the deployed Hook is bound to.
    error DeployStandbyHook__PoolManagerBindingMismatch(address expected, address actual);

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Canonical script entrypoint: resolves infrastructure and deploys StandbyHook.
    /// @dev Under a broadcasting Foundry script, salted creations are routed through the
    ///      deterministic CREATE2 factory, so that factory is the address the Hook address is
    ///      mined against.
    /// @return hook The deployed StandbyHook.
    /// @return salt The CREATE2 salt that produced the Hook address.
    /// @return config The resolved infrastructure configuration the Hook was deployed against.
    function run() external returns (StandbyHook hook, bytes32 salt, NetworkConfig memory config) {
        HelperConfig helperConfig = new HelperConfig();
        config = helperConfig.getNetworkConfig();

        vm.startBroadcast();
        (hook, salt) = deployStandbyHook(IPoolManager(config.poolManager), CREATE2_FACTORY);
        vm.stopBroadcast();

        console2.log("Standby chain id:      ", config.chainId);
        console2.log("Standby PoolManager:   ", config.poolManager);
        console2.log("Standby Hook:          ", address(hook));
        console2.logBytes32(salt);
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deterministically deploys StandbyHook at a permission-valid Uniswap v4 Hook address.
    /// @param _poolManager The PoolManager the Hook is immutably bound to.
    /// @param _create2Deployer The account that performs the salted creation: the deterministic
    ///        CREATE2 factory under a broadcasting script, or this contract under `forge test`.
    /// @return hook The deployed StandbyHook.
    /// @return salt The CREATE2 salt that produced the Hook address.
    function deployStandbyHook(IPoolManager _poolManager, address _create2Deployer)
        public
        returns (StandbyHook hook, bytes32 salt)
    {
        address expectedHookAddress;
        (expectedHookAddress, salt) = HookMiner.find(
            _create2Deployer, REQUIRED_HOOK_PERMISSION_MASK, type(StandbyHook).creationCode, abi.encode(_poolManager)
        );

        hook = new StandbyHook{salt: salt}(_poolManager);

        if (address(hook) != expectedHookAddress) {
            revert DeployStandbyHook__HookAddressMismatch(expectedHookAddress, address(hook));
        }

        _validateDeployedHook(hook, _poolManager);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Proves the deployed Hook satisfies the deployment contract: the address encodes exactly
    ///      the required permission bits — no missing bit and no unauthorized bit — the pinned
    ///      `Hooks.validateHookPermissions` accepts the address against the Hook's own declared
    ///      permission struct, and the Hook is bound to the intended PoolManager.
    function _validateDeployedHook(StandbyHook _hook, IPoolManager _poolManager) internal view {
        uint160 encodedPermissions = uint160(address(_hook)) & Hooks.ALL_HOOK_MASK;

        if (encodedPermissions != REQUIRED_HOOK_PERMISSION_MASK) {
            revert DeployStandbyHook__HookPermissionMaskMismatch(REQUIRED_HOOK_PERMISSION_MASK, encodedPermissions);
        }

        Hooks.validateHookPermissions(IHooks(address(_hook)), _hook.getHookPermissions());

        address boundPoolManager = address(_hook.poolManager());

        if (boundPoolManager != address(_poolManager)) {
            revert DeployStandbyHook__PoolManagerBindingMismatch(address(_poolManager), boundPoolManager);
        }
    }
}
