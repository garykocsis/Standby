// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Lets a production settlement and delivery sequence commit while finalization does not exist.
/// @dev The production `ExerciseRouter` refuses to return from an exercise whose causal proof has not been
///      consumed, and nothing at this slice can consume it, so no production exercise commits. That refusal
///      is a Standby safety requirement rather than an obstacle — but it also means the settlement and
///      delivery mechanics it protects could not otherwise be observed at all, because every transaction
///      that performs them is unwound before anything can be measured.
///
///      This contract is that observation and nothing more. It is the production `ExerciseRouter` with the
///      completion barrier lifted and with no other difference whatsoever: `exercise`, the originator
///      attribution, the authorization request, the unlock, the PoolManager authentication, the protected
///      execution, the causal-context read, the input-debt derivation, the `maxInput` comparison, the
///      exerciser-funded settlement, the direct Beneficiary delivery, and both delta-closure requirements
///      are all inherited production code running unmodified.
///
///      What it removes is exactly one thing, and removing it establishes exactly one thing: that an
///      exercise which has settled and delivered has not been finalized. It does not reduce Remaining
///      Entitlement, release any obligation, attribute any fulfillment, or consume the Hook's causal
///      context — because it implements none of that, and neither does the production code it inherits. A
///      committed exercise here leaves the causal context `EXECUTED`, which is precisely the state the
///      production barrier exists to refuse.
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
contract UnfinalizedExerciseRouter is ExerciseRouter {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the unfinalized router against the same Hook the production router binds.
    /// @param _hook The StandbyHook that owns the Protected Execution Service.
    constructor(StandbyHook _hook) ExerciseRouter(_hook) {}

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

    /// @dev Lifts the completion barrier, so a settled and delivered exercise commits unfinalized.
    function _requireFinalizedExercise() internal view override {}
}
