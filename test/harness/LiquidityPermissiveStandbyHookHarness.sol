// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice A StandbyHook that admits liquidity, so the zero-liquidity activation guard is reachable.
/// @dev This harness exists for exactly one reason. `configureAndActivate` requires the configured pool
///      to hold no active liquidity, but at F3 the production `beforeAddLiquidity` callback is still
///      fail-closed and liquidity admission belongs to F6A. There is therefore no production path that
///      can put liquidity into a StandbyHook-bound pool, and the guard could not otherwise be exercised
///      against real PoolManager state.
///
///      The harness overrides only the F6A-owned liquidity callback. It adds no state, seeds no
///      economic fact, and inherits `configureAndActivate` and every validation it performs unchanged
///      from production. The liquidity the guard reads is real liquidity, written by the real
///      PoolManager through the official liquidity router.
contract LiquidityPermissiveStandbyHookHarness is StandbyHook {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the harness with the same immutable trust basis as the production Hook.
    /// @param _poolManager The PoolManager whose callbacks this Hook answers.
    /// @param _configurationAuthority The only account authorized to activate the service.
    /// @param _trustedUniversalRouter The trusted ordinary-swap perimeter.
    /// @param _trustedPositionManager The trusted liquidity perimeter.
    constructor(
        IPoolManager _poolManager,
        address _configurationAuthority,
        address _trustedUniversalRouter,
        address _trustedPositionManager
    ) StandbyHook(_poolManager, _configurationAuthority, _trustedUniversalRouter, _trustedPositionManager) {}

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Admits the liquidity addition unconditionally. This is not Standby liquidity admission and
    ///      must never be read as a preview of F6A behavior; it only unblocks the PoolManager write.
    function _beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeAddLiquidity.selector;
    }
}
