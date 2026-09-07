// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyHookHarness} from "./StandbyHookHarness.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Exposes the F5 derivation kernel and unblocks real v4 execution against a Hook-bound pool.
/// @dev This harness does two things, both of them narrow.
///
///      It exposes the Hook-internal prospective-state derivations. Those derivations are internal because
///      the transitions that will consume them belong to later slices, so without exposure they could not
///      be checked against real execution until after the slices that depend on them were already built —
///      exactly the inversion the verification-gated dependency rule forbids. The exposed functions are
///      bare pass-throughs: they add no check, remove no check, and re-implement nothing.
///
///      It also admits the four enabled callbacks. Standby's production callbacks fail closed until their
///      owning enforcement slice implements them, so no liquidity can enter a Hook-bound pool and no swap
///      can execute against one. Without that, the prospective derivations could only ever be compared
///      against a pool the Hook is not attached to, and the comparison against real v4 execution required
///      by the prospective-state gate could not be made at all.
///
///      What the harness admits is *nothing*: the overrides implement no authorization, no eligibility,
///      no attribution, no backing check, and no economic decision of any kind. They must never be read as
///      a preview of the enforcement slice's behavior. What they leave real is everything that matters
///      here — the PoolManager writes the price, the liquidity, and the tick, and the Hook's derivations
///      read authoritative state exactly as they would in production.
contract StandbyDerivationHarness is StandbyHookHarness {
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
    ) StandbyHookHarness(_poolManager, _configurationAuthority, _trustedUniversalRouter, _trustedPositionManager) {}

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Runs the production prospective swap-state derivation.
    /// @param _params The proposed swap.
    /// @return sqrtPriceX96 The predicted post-swap square-root price.
    /// @return liquidity The predicted post-swap active liquidity.
    function prospectiveSwapState(SwapParams calldata _params)
        external
        view
        returns (uint160 sqrtPriceX96, uint128 liquidity)
    {
        (sqrtPriceX96, liquidity) = _prospectiveSwapState(_params);
    }

    /// @notice Runs the production prospective liquidity-removal state derivation.
    /// @param _params The proposed liquidity modification.
    /// @return sqrtPriceX96 The predicted post-removal square-root price.
    /// @return liquidity The predicted post-removal active liquidity.
    function prospectiveLiquidityRemovalState(ModifyLiquidityParams calldata _params)
        external
        view
        returns (uint160 sqrtPriceX96, uint128 liquidity)
    {
        (sqrtPriceX96, liquidity) = _prospectiveLiquidityRemovalState(_params);
    }

    /// @notice Runs the production Supporting Capacity derivation over a supplied hypothetical state.
    /// @dev Used to prove that a prediction and the authoritative post-transition reading go through the
    ///      same kernel, rather than through two paths that merely happen to agree.
    /// @param _sqrtPriceX96 The square-root price to measure.
    /// @param _liquidity The active liquidity to measure.
    /// @return capacity The Supporting Capacity of that state.
    function supportingCapacityFromState(uint160 _sqrtPriceX96, uint128 _liquidity)
        external
        view
        returns (uint256 capacity)
    {
        capacity = _supportingCapacityFromState(_sqrtPriceX96, _liquidity);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Admits the liquidity addition unconditionally. Not Standby liquidity admission.
    function _beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeAddLiquidity.selector;
    }

    /// @dev Admits the liquidity removal unconditionally. Not Standby backing enforcement.
    function _beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    /// @dev Admits the swap unconditionally and takes no delta. Not Standby O3 enforcement.
    function _beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @dev Observes the completed swap and takes no delta. Not Standby causal finalization.
    function _afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        pure
        override
        returns (bytes4, int128)
    {
        return (IHooks.afterSwap.selector, int128(0));
    }
}
