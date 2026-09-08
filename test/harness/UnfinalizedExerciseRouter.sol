// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {NonFinalizingExerciseRouter} from "./NonFinalizingExerciseRouter.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Lets a production settlement and delivery sequence commit without being finalized.
/// @dev The production `ExerciseRouter` asks the Hook to finalize every exercise it resolves, and then
///      refuses to return from one whose causal proof was not consumed. Both are Standby safety
///      requirements rather than obstacles — but together they mean the settlement and delivery mechanics
///      between them cannot be observed *on their own*: a production transaction either finalizes, in which
///      case what is measured afterwards includes the fulfillment, or it unwinds before anything can be
///      measured at all.
///
///      This contract is that observation and nothing more. It is the non-finalizing production router with
///      the completion barrier additionally lifted, and with no other difference whatsoever: `exercise`,
///      the originator attribution, the authorization request, the unlock, the PoolManager authentication,
///      the protected execution, the causal-context read, the input-debt derivation, the `maxInput`
///      comparison, the exerciser-funded settlement, the direct Beneficiary delivery, and both
///      delta-closure requirements are all inherited production code running unmodified.
///
///      What the two removals establish together is exactly one thing: that an exercise which has settled
///      and delivered has not been fulfilled. It reduces no Remaining Entitlement, releases no obligation,
///      attributes no fulfillment, and consumes no causal context — because it asks for none of that, and
///      the production code it inherits does none of it by itself. A committed exercise here leaves the
///      causal context `EXECUTED`, which is precisely the state the production barrier exists to refuse.
///
///      Nothing observed through this contract is evidence that a production O2 completes, and no test may
///      present it as such. What it is evidence for is what the production R3 and R4 mechanics do, measured
///      against the real pinned PoolManager, at the moment they have done it.
///
///      It also exposes the production input-debt derivation, which is `internal pure` in production and
///      reachable only from inside a PoolManager unlock behind a real swap. That is a bare pass-through: it
///      adds no check, removes none, and re-implements nothing. It exists because the derivation's whole
///      job is to interpret a signed `BalanceDelta` correctly, and the real PoolManager will only ever hand
///      it well-formed ones — so the malformed cases the derivation must refuse are unreachable without it.
contract UnfinalizedExerciseRouter is NonFinalizingExerciseRouter {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the unfinalized router against the same Hook the production router binds.
    /// @param _hook The StandbyHook that owns the Protected Execution Service.
    constructor(StandbyHook _hook) NonFinalizingExerciseRouter(_hook) {}

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Runs the production derivation of an executed exercise's settlement facts.
    /// @param _key The pool the execution was performed against.
    /// @param _params The executed protected swap.
    /// @param _delta The balance delta presented as the execution's authoritative result.
    /// @return inputCurrency The currency the execution spends.
    /// @return outputCurrency The currency the execution produces.
    /// @return actualInput The authoritative input debt of the execution.
    function executedExerciseSettlement(PoolKey calldata _key, SwapParams calldata _params, BalanceDelta _delta)
        external
        pure
        returns (Currency inputCurrency, Currency outputCurrency, uint256 actualInput)
    {
        (inputCurrency, outputCurrency, actualInput) = _executedExerciseSettlement(_key, _params, _delta);
    }

    /// @notice Runs the production resolution of an executed exercise.
    /// @dev The other bare pass-through, and it exists for the causal prerequisite rather than for the
    ///      mechanics. Production reaches this only from inside its own unlock, immediately after a swap the
    ///      Hook has already accepted and proven — so the causal positions it must refuse are exactly the
    ///      ones that cannot occur there, and refusing them is verifiable only by presenting them directly.
    ///
    ///      A refused position is refused before any PoolManager interaction, which is what makes the
    ///      refusals observable outside an unlock at all.
    /// @param _key The pool the execution claims to have been performed against.
    /// @param _params The swap the resolution claims to concern.
    /// @param _delta The balance delta presented as the execution's authoritative result.
    /// @param _maxInput The exercise-local cost bound presented for the resolution.
    function resolveExecutedExercise(
        PoolKey calldata _key,
        SwapParams calldata _params,
        BalanceDelta _delta,
        uint256 _maxInput
    ) external {
        _resolveExecutedExercise(_key, _params, _delta, _maxInput);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Lifts the completion barrier, so the settled and delivered exercise its non-finalizing parent
    ///      produces commits instead of unwinding.
    function _requireFinalizedExercise() internal view override {}
}
