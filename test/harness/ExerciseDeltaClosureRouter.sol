// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Closes the PoolManager currency deltas a real protected execution opens, mechanically.
/// @dev A real Uniswap v4 swap opens currency deltas, and `PoolManager.unlock` refuses to return while any
///      remain open. Closing them is input settlement and Beneficiary delivery, which belong to F8C, so no
///      production path at F8B can close them and no production O2 transaction can commit. Verifying that
///      an otherwise valid real-PoolManager execution actually produced exactly `q`, and that the pool it
///      left behind is the pool the F5 derivation predicted, requires the execution to commit — which is
///      what this contract exists for, and the only thing it exists for.
///
///      It is the production `ExerciseRouter` with one override. `exercise`, the originator attribution, the
///      authorization request, the unlock, the PoolManager authentication, and the protected execution
///      itself are all inherited production code running unmodified; the override adds nothing before the
///      execution and only closes whatever deltas that execution left afterwards.
///
///      The closure is deliberately economics-free, and every choice in it is made so that nothing here can
///      be read as protocol behavior:
///
///      - it funds the input debt from this contract's own pre-funded balance, so it assigns no payer and
///        establishes nothing about who is supposed to pay (RR-O2-11 is F8C's);
///      - it compares nothing against `maxInput`, so it enforces no cost bound (RR-O2-12 is F8C's);
///      - it takes the protected output to itself and not to the Beneficiary, so no test can mistake a
///        closed delta for delivery (RR-O2-16, RR-O2-17 are F8C's);
///      - it reduces no Remaining Entitlement, attributes no fulfillment, and finalizes nothing.
///
///      Harness-only behavior is not evidence about production settlement, delivery, payment
///      responsibility, or fulfillment, and nothing here may be presented as such. What it is evidence for
///      is narrow and real: the Hook's O2 classification and execution evidence, observed across a
///      committed swap performed by the real pinned PoolManager.
contract ExerciseDeltaClosureRouter is ExerciseRouter {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the mechanical closure of a currency debt does not succeed.
    /// @param currency The currency the debt is denominated in.
    /// @param amount The raw amount owed.
    error ExerciseDeltaClosureRouter__ClosureTransferFailed(address currency, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the closure router against the same Hook the production router binds.
    /// @param _hook The StandbyHook that owns the Protected Execution Service.
    constructor(StandbyHook _hook) ExerciseRouter(_hook) {}

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Runs the production protected execution and then closes its deltas mechanically.
    /// @dev The pool is read before the execution because the Hook describes the admitted execution only
    ///      while the causal context is still AUTHORIZED — afterwards it is evidence, not a proposal.
    /// @return result The encoded balance delta of the performed execution.
    function unlockCallback(bytes calldata) external override returns (bytes memory result) {
        PoolKey memory key = i_hook.protectedExecutionService().poolKey;

        BalanceDelta delta = _executeAuthorizedExercise();

        _closeDelta(key.currency0, delta.amount0());
        _closeDelta(key.currency1, delta.amount1());

        result = abi.encode(delta);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Zeroes one currency's outstanding delta. Mechanical accounting closure, never settlement.
    function _closeDelta(Currency _currency, int128 _amount) internal {
        if (_amount < 0) {
            uint256 owed = uint256(int256(-_amount));

            i_poolManager.sync(_currency);

            bool paid = IERC20Minimal(Currency.unwrap(_currency)).transfer(address(i_poolManager), owed);

            if (!paid) revert ExerciseDeltaClosureRouter__ClosureTransferFailed(Currency.unwrap(_currency), owed);

            i_poolManager.settle();
        } else if (_amount > 0) {
            i_poolManager.take(_currency, address(this), uint256(int256(_amount)));
        }
    }
}
