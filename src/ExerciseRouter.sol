// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyHook} from "./StandbyHook.sol";
import {IActorAwarePeriphery} from "./interfaces/IActorAwarePeriphery.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title ExerciseRouter
/// @notice The designated O2 coordinator of one Protected Execution Service.
/// @dev At implementation slice F8B this contract owns exactly three responsibilities, the first three of
///      the five the reference realization assigns it (`implementation-plan.md` §14.0): it accepts the
///      external exercise request, it preserves the originating exerciser across the call into the Hook so
///      that the Hook can recover an authenticated economic actor, and it coordinates exactly one protected
///      PoolManager execution for the authorization the Hook produced. Input settlement, Beneficiary
///      delivery, and finalization are later slices and are deliberately absent here.
///
///      Because they are absent, no exercise completes at this slice. A real PoolManager swap opens
///      currency deltas, and `PoolManager.unlock` refuses to return while any remain open, so the
///      coordinated execution always unwinds the request that made it. That is the honest state of the
///      implementation rather than a defect to be worked around: the deltas belong to input settlement and
///      Beneficiary delivery, which are F8C's to own, and closing them here — to anyone, in any amount —
///      would be inventing settlement semantics this slice has no authority over.
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
contract ExerciseRouter is IActorAwarePeriphery, IUnlockCallback {
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

    /// @notice The PoolManager the coordinated protected execution is performed against.
    /// @dev Resolved from the Hook rather than supplied separately, so this router cannot be bound to a
    ///      PoolManager the Hook does not answer callbacks from.
    IPoolManager public immutable i_poolManager;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the originating exerciser is queried while no exercise request is executing.
    error ExerciseRouter__NoActiveExerciseContext();

    /// @notice Thrown when an exercise request is attempted while another is already executing.
    /// @param exerciser The originator of the request already in flight.
    error ExerciseRouter__ExerciseContextAlreadyActive(address exerciser);

    /// @notice Thrown when the unlock callback is invoked by anything other than the PoolManager.
    /// @param caller The unauthorized caller.
    error ExerciseRouter__NotPoolManager(address caller);

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Binds the router to the StandbyHook whose service it coordinates.
    /// @param _hook The StandbyHook that owns the Protected Execution Service.
    constructor(StandbyHook _hook) {
        i_hook = _hook;
        i_poolManager = _hook.poolManager();
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
    ///      The third field is `maxInput`, and it remains request-surface data and nothing else through this
    ///      slice. It is exercise-local cost protection, enforced against the authoritative PoolManager
    ///      input debt an executed exact-output swap produces (RR-O2-10, RR-O2-12). That debt now exists —
    ///      the protected swap executes here — but deriving it authoritatively, requiring
    ///      `actualInput <= maxInput`, and settling it are one responsibility, and it is F8C's. The bound is
    ///      therefore not enforced here. Its parameter is deliberately left unnamed: the value arrives in
    ///      the request, reaches no code, and cannot be read, compared, forwarded to the Hook, bound into
    ///      the causal context, or persisted. That is not an omission to be tidied up later by whoever finds
    ///      it — it is the settlement boundary made structural, and the stage that can honour the bound is
    ///      the stage that should name it.
    ///
    ///      Authorization comes first and execution follows it, in one call, with nothing between them that
    ///      could decide differently. The Hook's authorization leaves a transaction-scoped AUTHORIZED causal
    ///      context in place; the unlock that follows performs exactly one PoolManager operation against it.
    ///      Neither step is optional and neither can be repeated: a second unlock is impossible while one is
    ///      open, and the Hook refuses a second swap against a context that is no longer AUTHORIZED.
    ///
    ///      The protected execution is not caught. There is no `try`, no failure branch, and no alternative
    ///      path after the PoolManager call, so a failed execution unwinds this request completely — the
    ///      authorization that preceded it included. That matters more than it looks: an execution marker
    ///      written inside a reverted PoolManager callback rolls back to AUTHORIZED, so a router that caught
    ///      a failed swap would hold a restored authorization it could execute against again. This one
    ///      cannot, because it does not survive the failure.
    ///
    ///      What a completed execution establishes is Hook-owned and narrow: the authorized swap actually
    ///      produced exactly `q`. No input has been settled, no output has been delivered to the
    ///      Beneficiary, no commitment has been fulfilled, and no Remaining Entitlement has been reduced.
    ///
    ///      The originator context is cleared on the way out, so this router exposes no reusable identity
    ///      afterwards. The Hook's own causal context is not cleared here, and must not be: whether it may
    ///      be replaced, consumed, or repeated is a Standby economic question the Hook owns, and a router
    ///      that could clear it would be able to manufacture a second authorization.
    /// @param _commitmentId The commitment the caller is asking to exercise.
    /// @param _q The protected-output quantity the caller is asking to exercise.
    function exercise(uint256 _commitmentId, uint256 _q, uint256 /* maxInput */ ) external {
        _beginExerciserContext();

        i_hook.authorizeExercise(_commitmentId, _q);

        i_poolManager.unlock(bytes(""));

        _endExerciserContext();
    }

    /// @notice Performs the one protected execution the Hook's active authorization admits.
    /// @dev Only the PoolManager may invoke this, and it carries no parameters: the swap it performs is
    ///      asked of the Hook rather than chosen here or forwarded from the request. Direction,
    ///      exact-output mode, the quantity, and the qualification boundary are all Standby facts, and a
    ///      router that composed its own version of them would be a second, silently divergent statement of
    ///      what a Standby exercise executes.
    ///
    ///      Nothing about proposing the right swap is what makes it acceptable. The Hook revalidates the
    ///      operation on the authoritative PoolManager callback path against its own causal context, so this
    ///      contract can propose and never authorize.
    ///
    ///      It is `virtual` for one reason, and the reason is not extensibility: F8B implements no
    ///      settlement, so the deltas this swap opens cannot be closed by any production path, and the
    ///      verification of a committed real-PoolManager execution requires a test-only subclass to close
    ///      them mechanically. Nothing in production overrides it.
    /// @return result The encoded balance delta of the performed execution.
    function unlockCallback(bytes calldata) external virtual returns (bytes memory result) {
        result = abi.encode(_executeAuthorizedExercise());
    }

    /// @inheritdoc IActorAwarePeriphery
    function msgSender() external view returns (address actor) {
        actor = _exerciserContext();

        if (actor == address(0)) revert ExerciseRouter__NoActiveExerciseContext();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs the authorized protected execution inside the PoolManager unlock.
    ///
    ///      The PoolManager authentication is here rather than in the callback entry point so that a
    ///      test-only subclass which must close deltas cannot reach the execution without it.
    function _executeAuthorizedExercise() internal returns (BalanceDelta delta) {
        if (msg.sender != address(i_poolManager)) revert ExerciseRouter__NotPoolManager(msg.sender);

        (PoolKey memory key, SwapParams memory params) = i_hook.authorizedProtectedExecution();

        delta = i_poolManager.swap(key, params, bytes(""));
    }

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
