// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {StandbyHook} from "./StandbyHook.sol";
import {IActorAwarePeriphery} from "./interfaces/IActorAwarePeriphery.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title ExerciseRouter
/// @notice The designated O2 coordinator of one Protected Execution Service.
/// @dev At implementation slice F8A this contract owns exactly two responsibilities, the first two of the
///      five the reference realization assigns it (`implementation-plan.md` §14.0): it accepts the external
///      exercise request, and it preserves the originating exerciser across the call into the Hook so that
///      the Hook can recover an authenticated economic actor. Protected execution, input settlement,
///      Beneficiary delivery, and finalization are later slices and are deliberately absent here.
///
///      It owns no Standby economic truth and cannot acquire any. It does not know whether the commitment
///      exists, who its Beneficiary is, who may exercise it, whether it is valid, whether it is
///      exercisable, what Remaining Entitlement it carries, what Supporting Capacity or Aggregate Capacity
///      Obligation the service currently has, or whether the request is backed. Every one of those is
///      derived by the Hook from authoritative state, on every request, and the Hook trusts this contract
///      for exactly one fact:
///
///      > for the exercise request currently executing, the direct originating caller was address X.
///
///      Being asked that question grants nothing. The Hook first authenticates that its caller is exactly
///      the ExerciseRouter fixed when the service was activated, and only then asks. An identical copy of
///      this bytecode deployed alongside is not the configured router and can authorize nothing, however
///      truthful its answer would have been. The router's own address is likewise never an exercise
///      authority: the answer it gives is the originating caller, never itself.
///
///      Attribution is execution context, not protocol history. The originator is bound in transient
///      storage when a request begins and cleared when it ends, so the lifecycle is
///      `EMPTY -> ACTIVE(exerciser) -> EMPTY` within one transaction and no reusable identity survives it.
///      A request attempted while another is already in flight is rejected rather than stacked, because
///      one exercise request carries exactly one unambiguous originator.
///
///      The originator is the direct caller of `exercise`. `tx.origin` is never consulted, and there is no
///      calldata field, forwarded address, or hook payload through which another exerciser could be
///      nominated — the request surface simply does not carry one.
contract ExerciseRouter is IActorAwarePeriphery {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The transient slot holding the originator of the exercise request currently executing.
    ///      Transient storage is used deliberately: the fact is transaction-local, and ordinary storage
    ///      would leave a reusable identity behind for the next transaction to find.
    bytes32 private constant EXERCISER_CONTEXT_SLOT = keccak256("standby.ExerciseRouter.exerciserContext");

    /// @notice The StandbyHook that owns the Protected Execution Service this router coordinates.
    /// @dev Immutable, and the only contract this router ever calls. The binding is one-directional: being
    ///      bound to a Hook does not make this router that Hook's configured ExerciseRouter. Only the
    ///      Hook's own one-shot service activation decides that.
    StandbyHook public immutable i_hook;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the originating exerciser is queried while no exercise request is executing.
    error ExerciseRouter__NoActiveExerciseContext();

    /// @notice Thrown when an exercise request is attempted while another is already executing.
    /// @param exerciser The originator of the request already in flight.
    error ExerciseRouter__ExerciseContextAlreadyActive(address exerciser);

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Binds the router to the StandbyHook whose service it coordinates.
    /// @param _hook The StandbyHook that owns the Protected Execution Service.
    constructor(StandbyHook _hook) {
        i_hook = _hook;
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Requests Hook-owned authorization to exercise a commitment for a quantity.
    /// @dev The request carries the three fields the frozen realization gives it — which commitment, how
    ///      much of it, and the exerciser's own cost bound (`implementation-plan.md` §14.3). It
    ///      deliberately does not carry the Beneficiary, the PoolKey, the protected direction, the exercise
    ///      authority, Remaining Entitlement, Supporting Capacity, or Aggregate Capacity Obligation: those
    ///      are authoritative facts the Hook resolves, not request parameters.
    ///
    ///      The third field is `maxInput`, and at this slice it is request-surface data and nothing else.
    ///      It is exercise-local cost protection, enforced against the authoritative PoolManager input debt
    ///      that an executed exact-output swap produces (RR-O2-10, RR-O2-12) — and no swap executes here,
    ///      so there is no debt to bound and nothing to enforce it against yet. Its parameter is therefore
    ///      deliberately left unnamed: the value arrives in the request, reaches no code, and cannot be
    ///      read, compared, forwarded to the Hook, bound into the causal context, or persisted. That is not
    ///      an omission to be tidied up later by whoever finds it — it is the F8A boundary made structural,
    ///      and the settlement stage that can honour the bound is the stage that should name it.
    ///
    ///      A successful call leaves a Hook-owned AUTHORIZED causal context in place for the remainder of
    ///      the transaction. That context is authorization and nothing more: no swap has executed, no
    ///      input has been settled, no output has been delivered, no commitment has been fulfilled, and no
    ///      Remaining Entitlement has been reduced. The later O2 slices consume it.
    ///
    ///      The originator context is cleared on the way out, so this router exposes no reusable identity
    ///      afterwards. The Hook's own authorization context is not cleared here, and must not be: whether
    ///      an authorization may be replaced, consumed, or repeated is a Standby economic question the Hook
    ///      owns, and a router that could clear it would be able to manufacture a second authorization.
    /// @param _commitmentId The commitment the caller is asking to exercise.
    /// @param _q The protected-output quantity the caller is asking to exercise.
    function exercise(uint256 _commitmentId, uint256 _q, uint256 /* maxInput */ ) external {
        _beginExerciserContext();

        i_hook.authorizeExercise(_commitmentId, _q);

        _endExerciserContext();
    }

    /// @inheritdoc IActorAwarePeriphery
    function msgSender() external view returns (address actor) {
        actor = _exerciserContext();

        if (actor == address(0)) revert ExerciseRouter__NoActiveExerciseContext();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Binds the caller as the originator of a new exercise request.
    ///
    ///      A context that is already active is rejected rather than replaced or stacked, so exactly one
    ///      unambiguous originator exists for the duration of a request. This is the router's own
    ///      attribution discipline; it is not, and must not be mistaken for, Standby's prevention of
    ///      overlapping authorizations, which the Hook enforces independently.
    function _beginExerciserContext() internal {
        address active = _exerciserContext();

        if (active != address(0)) revert ExerciseRouter__ExerciseContextAlreadyActive(active);

        _setExerciserContext(msg.sender);
    }

    /// @dev Clears the originator context, returning the router to EMPTY.
    function _endExerciserContext() internal {
        _setExerciserContext(address(0));
    }

    /// @dev Writes the transient originator context.
    function _setExerciserContext(address _exerciser) internal {
        bytes32 slot = EXERCISER_CONTEXT_SLOT;

        assembly ("memory-safe") {
            tstore(slot, _exerciser)
        }
    }

    /// @dev Reads the transient originator context. Zero means no exercise request is executing.
    function _exerciserContext() internal view returns (address exerciser) {
        bytes32 slot = EXERCISER_CONTEXT_SLOT;

        assembly ("memory-safe") {
            exerciser := tload(slot)
        }
    }
}
