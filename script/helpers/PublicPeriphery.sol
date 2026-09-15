// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {Actions} from "v4-periphery/src/libraries/Actions.sol";

/*//////////////////////////////////////////////////////////////
                            INTERFACES
//////////////////////////////////////////////////////////////*/

/// @title IPublicPeripheryBindings
/// @notice The immutable-binding getters of the official v4 periphery that the pinned periphery interfaces do
///         not declare.
/// @dev Read-only provenance surface used to validate that the resolved public periphery is one mutually
///      compatible stack. The pinned `IImmutableState` and `IMsgSender` interfaces already declare
///      `poolManager()` and `msgSender()`; these two getters exist on the deployed contracts but not on any
///      pinned interface.
interface IPublicPeripheryBindings {
    /// @notice The v4 PositionManager a Universal Router is bound to.
    /// @return positionManager The bound PositionManager.
    function V4_POSITION_MANAGER() external view returns (address positionManager);

    /// @notice The Permit2 contract a PositionManager pulls payment through.
    /// @return permit2 The bound Permit2.
    function permit2() external view returns (address permit2);
}

/// @title IDeployedUniversalRouter
/// @notice The one Universal Router entrypoint Standby's public-network scripts invoke.
/// @dev The Universal Router is not a pinned Standby dependency, so its entrypoint is declared here rather than
///      imported. The signature is the deployed router's own `execute(bytes,bytes[],uint256)`.
interface IDeployedUniversalRouter {
    /// @notice Executes encoded commands with their inputs, reverting after the deadline.
    /// @param commands One byte per command.
    /// @param inputs One ABI-encoded input per command.
    /// @param deadline The timestamp after which the call reverts.
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

/// @title IPermit2Allowance
/// @notice The one Permit2 allowance entrypoint the public-network scripts invoke.
/// @dev The exact signature of `approve` in the pinned Permit2 `IAllowanceTransfer`; declared locally so the
///      scripts do not pull the pinned interface's whole signature-transfer surface in for one call.
interface IPermit2Allowance {
    /// @notice Grants a spender an allowance over the caller's token, pulled through Permit2.
    /// @param token The token being approved.
    /// @param spender The account allowed to pull the token.
    /// @param amount The allowance; `type(uint160).max` is unlimited.
    /// @param expiration The timestamp at which the allowance lapses.
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

/*//////////////////////////////////////////////////////////////
                             LIBRARIES
//////////////////////////////////////////////////////////////*/

/// @title DeployedUniversalRouterCalldata
/// @notice Encodes a single-pool exact-output v4 swap for the deployed official Universal Router.
/// @dev A calldata adapter and nothing else: it owns no Standby semantics, chooses no economic quantity, and
///      decides nothing about whether a swap is admissible. The Hook decides that on the PoolManager callback
///      path, from authoritative state, exactly as it does for any other perimeter.
///
///      It exists because the deployed router's v4 swap parameters predate pinned v4-periphery. Pinned
///      `IV4Router.ExactOutputSingleParams` carries a `minHopPriceX36` field that the deployed router does not
///      decode: its bytecode contains none of the errors introduced with that field. Encoding the pinned struct
///      for it would shift every later field. The struct below is therefore the deployed router's own
///      five-field layout, and the payment actions are the unchanged `SETTLE_ALL` / `TAKE_ALL` of the pinned
///      `Actions` library, so the payer and recipient are the router's authenticated `msgSender()`.
library DeployedUniversalRouterCalldata {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The deployed router's single-pool exact-output swap parameters.
    /// @param poolKey The pool swapped through.
    /// @param zeroForOne The swap direction.
    /// @param amountOut The exact output requested.
    /// @param amountInMaximum The caller's own input bound.
    /// @param hookData Hook payload; always empty here, and never Standby authority.
    struct ExactOutputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountOut;
        uint128 amountInMaximum;
        bytes hookData;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The Universal Router command that executes v4 router actions.
    uint8 internal constant V4_SWAP = 0x10;

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Encodes an exact-output single-pool swap settled and taken by the router's caller.
    /// @param _poolKey The pool swapped through.
    /// @param _zeroForOne The swap direction.
    /// @param _amountOut The exact output requested.
    /// @param _amountInMaximum The caller's own input bound.
    /// @return commands The router command string.
    /// @return inputs The router command inputs.
    function exactOutputSingle(PoolKey memory _poolKey, bool _zeroForOne, uint128 _amountOut, uint128 _amountInMaximum)
        internal
        pure
        returns (bytes memory commands, bytes[] memory inputs)
    {
        (Currency inputCurrency, Currency outputCurrency) =
            _zeroForOne ? (_poolKey.currency0, _poolKey.currency1) : (_poolKey.currency1, _poolKey.currency0);

        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_OUT_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            ExactOutputSingleParams({
                poolKey: _poolKey,
                zeroForOne: _zeroForOne,
                amountOut: _amountOut,
                amountInMaximum: _amountInMaximum,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(inputCurrency, uint256(_amountInMaximum));
        params[2] = abi.encode(outputCurrency, uint256(_amountOut));

        commands = abi.encodePacked(V4_SWAP);

        inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);
    }
}

/// @title PositionManagerCalldata
/// @notice Encodes a position mint for the official v4 PositionManager.
/// @dev A calldata adapter and nothing else. The mint parameters and actions are the pinned v4-periphery
///      `MINT_POSITION` / `SETTLE_PAIR` encoding, which the deployed PositionManager decodes unchanged. Payment is
///      settled from the PositionManager's authenticated `msgSender()` through Permit2.
library PositionManagerCalldata {
    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Encodes the `modifyLiquidities` unlock data for one position mint settled by the caller.
    /// @param _poolKey The pool the position is minted in.
    /// @param _tickLower The lower position boundary.
    /// @param _tickUpper The upper position boundary.
    /// @param _liquidity The exact liquidity minted.
    /// @param _amount0Max The caller's own bound on currency0 paid.
    /// @param _amount1Max The caller's own bound on currency1 paid.
    /// @param _owner The position NFT owner.
    /// @return unlockData The encoded actions and parameters.
    function mintPosition(
        PoolKey memory _poolKey,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _liquidity,
        uint128 _amount0Max,
        uint128 _amount1Max,
        address _owner
    ) internal pure returns (bytes memory unlockData) {
        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        bytes[] memory params = new bytes[](2);
        params[0] =
            abi.encode(_poolKey, _tickLower, _tickUpper, _liquidity, _amount0Max, _amount1Max, _owner, bytes(""));
        params[1] = abi.encode(_poolKey.currency0, _poolKey.currency1);

        unlockData = abi.encode(actions, params);
    }
}
