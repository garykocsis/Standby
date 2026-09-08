// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice The production `ExerciseRouter` with its finalization request removed and its completion
///         barrier intact.
/// @dev Production now asks the Hook to finalize every exercise it resolves, so a production exercise that
///      reaches the completion barrier with an unconsumed causal context no longer exists. The barrier is
///      nonetheless production code enforcing a production requirement — an exercise that settled and
///      delivered without being finalized must not commit — and a requirement whose failing case has become
///      unreachable is not a requirement that has stopped mattering. This contract constructs that case.
///
///      It removes exactly one thing: the request for finalization. `exercise`, the originator attribution,
///      the authorization request, the unlock, the PoolManager authentication, the protected execution, the
///      causal-context read, the input-debt derivation, the `maxInput` comparison, the exerciser-funded
///      settlement, the direct Beneficiary delivery, both delta-closure requirements, and the completion
///      barrier itself are all inherited production code running unmodified.
///
///      What that establishes is narrow and is the point: with nothing consuming the causal proof, the
///      barrier refuses, and the swap, the payment, and the delivery unwind with the refusal. Nothing
///      observed through this contract is evidence about what a production exercise does, and no test may
///      present it as such.
contract NonFinalizingExerciseRouter is ExerciseRouter {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the non-finalizing router against the same Hook the production router binds.
    /// @param _hook The StandbyHook that owns the Protected Execution Service.
    constructor(StandbyHook _hook) ExerciseRouter(_hook) {}

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Omits the finalization request, so no causal proof is ever consumed.
    function _finalizeExercise(uint256) internal pure override {}
}
