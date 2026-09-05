// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title StandbyHook
/// @notice The Standby Uniswap v4 Hook.
/// @dev At implementation slice F0 this contract establishes the Hook contract, its immutable
///      PoolManager binding, and the required Hook callback-permission surface. No Standby economic
///      state, derivation, or enforcement behavior is implemented yet, so every enabled callback
///      reverts with `HookNotImplemented` until its owning implementation slice supplies the
///      authoritative behavior.
contract StandbyHook is BaseHook {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Binds the Hook immutably to the authoritative Uniswap v4 PoolManager.
    /// @dev Reverts through `Hooks.validateHookPermissions` unless the deployment address encodes
    ///      exactly the permissions declared by `getHookPermissions()`.
    /// @param _poolManager The PoolManager whose callbacks this Hook answers.
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the required Standby Hook callback-permission surface.
    /// @dev All return-delta / custom-accounting permissions are disabled: Standby enforces backing,
    ///      it does not take custom accounting deltas.
    /// @return permissions The Hook permissions Uniswap v4 validates against the deployed address.
    function getHookPermissions() public pure override returns (Hooks.Permissions memory permissions) {
        permissions = Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
}
