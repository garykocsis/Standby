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

/// @notice The production `ExerciseRouter` with its finalization request pointed at a chosen commitment.
/// @dev Economic atomicity has to hold when finalization *fails*, and a finalization can only fail for
///      reasons the production system cannot produce: a resulting state that is no longer backed, a
///      remainder smaller than the proven quantity, or a request naming a commitment the proof is not bound
///      to. The first two are unreachable because the invariant they would violate is the one every earlier
///      transition already maintains. The third is unreachable because the production router names the
///      commitment its own request was for — which is exactly what this contract stops doing.
///
///      Nothing else is changed. The authorization, the unlock, the protected execution, the input-debt
///      derivation, the `maxInput` comparison, the exerciser-funded settlement, the direct Beneficiary
///      delivery, both delta-closure requirements, and the completion barrier are all inherited production
///      code running unmodified against the real PoolManager — so what a refused finalization unwinds here
///      is a genuine committed swap, a genuine payment, and a genuine delivery.
///
///      A misdirected request is not a Standby capability and no test may read it as one. What it is for is
///      the property on the other side of the refusal: that nothing durable survives it.
contract MisdirectedFinalizationRouter is ExerciseRouter {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The commitment every finalization request names, whatever the exercise was actually for.
    uint256 private _finalizationTarget;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the misdirecting router against the same Hook the production router binds.
    /// @param _hook The StandbyHook that owns the Protected Execution Service.
    constructor(StandbyHook _hook) ExerciseRouter(_hook) {}

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Chooses the commitment the next finalization request will name.
    /// @param _commitmentId The identity to name.
    function setFinalizationTarget(uint256 _commitmentId) external {
        _finalizationTarget = _commitmentId;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Names the chosen commitment instead of the one the request was for.
    function _finalizeExercise(uint256) internal override {
        i_hook.finalizeExercise(_finalizationTarget);
    }
}
