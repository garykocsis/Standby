// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyHook} from "./StandbyHook.sol";
import {IActorAwarePeriphery} from "./interfaces/IActorAwarePeriphery.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title ExerciseRouter
/// @notice The designated O2 coordinator of one Protected Execution Service.
/// @dev At implementation slice F8C this contract owns four of the five responsibilities the reference
///      realization assigns it (`implementation-plan.md` §14.0): it accepts the external exercise request,
///      it preserves the originating exerciser across the call into the Hook so that the Hook can recover
///      an authenticated economic actor, it coordinates exactly one protected PoolManager execution for
///      the authorization the Hook produced, and it resolves that execution — settling the actual input
///      debt from the authenticated exerciser and having the PoolManager deliver exactly `q` directly to
///      the authoritative Beneficiary. Causal finalization is a later slice and is deliberately absent.
///
///      Because it is absent, no production exercise completes at this slice, and that is enforced rather
///      than merely observed. A completed exercise leaves the Hook's causal context `EXECUTED`, which is
///      transaction-scoped: it disappears when the transaction ends. If this contract returned
///      successfully from an unfinalized exercise, the swap, the payment, and the delivery would all
///      survive while Remaining Entitlement stayed unreduced and the causal proof that could have reduced
///      it evaporated — leaving the commitment exercisable again for the whole quantity it had already
///      been exercised for. The top-level request therefore requires the causal context to have been
///      consumed before it may return, and until finalization exists that requirement is one no exercise
///      can satisfy. The barrier is a completion condition rather than a stub: finalization will consume
///      the context inside the same unlock, and the same condition will then pass unchanged.
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
///      Settlement does not change that. This contract moves value without ever holding any: the input is
///      pulled from the authenticated exerciser directly to the PoolManager, and the protected output is
///      transferred by the PoolManager directly to the Beneficiary. It is not a Standby reserve, it is not
///      a payer, it is not a custodian of protected output, and a balance it happens to hold is never a
///      source of settlement. Both parties to the transfer are read from the Hook-owned causal context,
///      not from the request, so there is no calldata through which a caller could nominate either.
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
    using TransientStateLibrary for IPoolManager;

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

    /// @notice Thrown when settlement is attempted for an execution the Hook has not proven.
    /// @dev Settlement and delivery resolve one specific protected execution, and the only authority that
    ///      an execution occurred is the Hook's own causal context. A context in any other position is not
    ///      a proven execution, so there is nothing to settle and nothing to deliver.
    /// @param state The causal position the Hook-owned context was actually in.
    error ExerciseRouter__ExerciseNotExecuted(StandbyHook.ExerciseAuthorizationState state);

    /// @notice Thrown when the input side of an executed protected swap is not an authoritative debt.
    /// @dev The PoolManager's own delta is the settlement truth, and its sign is part of that truth: only a
    ///      negative amount is currency the caller owes. A zero or positive input side is not a smaller
    ///      debt or an absolute quantity to be settled anyway — it is a delta this router cannot interpret
    ///      as the cost of the execution, so the whole exercise fails rather than settling a guess.
    /// @param inputDelta The input-side amount the PoolManager actually reported.
    error ExerciseRouter__NoAuthoritativeInputDebt(int256 inputDelta);

    /// @notice Thrown when the authoritative input debt exceeds the exerciser's own cost bound.
    /// @dev Exercise-local cost protection and nothing else. It is compared against the debt the executed
    ///      swap actually produced, never against a quote, an estimate, or the requested quantity, and it
    ///      changes no commitment term, no entitlement, and no obligation (RR-O2-10, RR-O2-12).
    /// @param actualInput The authoritative input debt of the executed protected swap.
    /// @param maxInput The bound the request carried.
    error ExerciseRouter__ExerciseCostExceedsMaxInput(uint256 actualInput, uint256 maxInput);

    /// @notice Thrown when the exact input transfer from the authenticated exerciser does not succeed.
    /// @param currency The input currency of the executed protected swap.
    /// @param exerciser The authenticated originating exerciser the debt is funded from.
    /// @param amount The exact authoritative debt the transfer was for.
    error ExerciseRouter__InputTransferFailed(address currency, address exerciser, uint256 amount);

    /// @notice Thrown when an exercise leaves an outstanding PoolManager currency delta behind.
    /// @dev Calling `settle` is not proof that a debt was paid and calling `take` is not proof that a
    ///      credit was discharged, because both merely account whatever actually moved. The authoritative
    ///      statement is the delta itself, so each side is required to be closed after the operation that
    ///      was supposed to close it. Underpayment, overpayment, and an inexact transfer all surface here.
    /// @param currency The currency whose delta is still open.
    /// @param remainingDelta The outstanding amount.
    error ExerciseRouter__UnresolvedExerciseDelta(address currency, int256 remainingDelta);

    /// @notice Thrown when an exercise would complete while its causal context is still unconsumed.
    /// @dev The slice-completion barrier. An exercise whose causal proof has not been consumed has not
    ///      been finalized, and finalization is the only thing that reduces Remaining Entitlement. Letting
    ///      such a request return would commit the swap, the payment, and the Beneficiary delivery while
    ///      the entitlement they discharged stayed intact and the transaction-scoped proof of what
    ///      happened disappeared with the transaction.
    /// @param state The causal position the Hook-owned context was left in.
    error ExerciseRouter__ExerciseNotFinalized(StandbyHook.ExerciseAuthorizationState state);

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

    /// @notice Requests Hook-owned authorization to exercise a commitment for a quantity, and resolves it.
    /// @dev The request carries the three fields the frozen realization gives it — which commitment, how
    ///      much of it, and the exerciser's own cost bound (`implementation-plan.md` §14.3). It
    ///      deliberately does not carry the Beneficiary, the PoolKey, the protected direction, the exercise
    ///      authority, Remaining Entitlement, Supporting Capacity, or Aggregate Capacity Obligation: those
    ///      are authoritative facts the Hook resolves, not request parameters. Nor does it carry a
    ///      recipient, an input currency, an output currency, or an input amount — a request that could
    ///      name any of those could redirect delivery or substitute settlement truth.
    ///
    ///      The third field is `maxInput`, and this is the slice that can honour it. It is exercise-local
    ///      cost protection, enforced against the authoritative PoolManager input debt the executed
    ///      exact-output swap produced (RR-O2-10, RR-O2-12), and it travels no further than the settlement
    ///      stage: it reaches the Hook through no path, enters no causal context, and is persisted nowhere.
    ///
    ///      Authorization comes first and execution follows it, in one call, with nothing between them that
    ///      could decide differently. The Hook's authorization leaves a transaction-scoped AUTHORIZED causal
    ///      context in place; the unlock that follows performs exactly one PoolManager operation against it
    ///      and then resolves that operation's two currency deltas. Neither step is optional and neither can
    ///      be repeated: a second unlock is impossible while one is open, and the Hook refuses a second swap
    ///      against a context that is no longer AUTHORIZED.
    ///
    ///      Nothing inside the unlock is caught. There is no `try`, no failure branch, and no alternative
    ///      path after the PoolManager call, so a failed execution, a breached cost bound, an exerciser who
    ///      cannot pay, or a delivery that does not land unwinds this request completely — the authorization
    ///      that preceded it included. That matters more than it looks: an execution marker written inside a
    ///      reverted PoolManager callback rolls back to AUTHORIZED, so a router that caught a failure would
    ///      hold a restored authorization it could execute against again. This one cannot, because it does
    ///      not survive the failure.
    ///
    ///      What a resolved exercise establishes is Hook-owned and still narrow: the authorized swap
    ///      produced exactly `q`, the exerciser paid exactly what the pool charged for it, and the
    ///      Beneficiary holds exactly `q`. No commitment has been fulfilled and no Remaining Entitlement has
    ///      been reduced — which is why the request may not return here. The completion barrier requires the
    ///      Hook's causal context to have been consumed, and nothing at this slice can consume it.
    ///
    ///      The originator context is cleared on the way out, so this router exposes no reusable identity
    ///      afterwards. The Hook's own causal context is not cleared here, and must not be: whether it may
    ///      be replaced, consumed, or repeated is a Standby economic question the Hook owns, and a router
    ///      that could clear it would be able to manufacture a second authorization.
    /// @param _commitmentId The commitment the caller is asking to exercise.
    /// @param _q The protected-output quantity the caller is asking to exercise.
    /// @param _maxInput The most input the caller is willing to pay for that quantity.
    function exercise(uint256 _commitmentId, uint256 _q, uint256 _maxInput) external {
        _beginExerciserContext();

        i_hook.authorizeExercise(_commitmentId, _q);

        i_poolManager.unlock(abi.encode(_maxInput));

        _requireFinalizedExercise();

        _endExerciserContext();
    }

    /// @notice Performs and resolves the one protected execution the Hook's active authorization admits.
    /// @dev Only the PoolManager may invoke this. The one thing it carries is the requesting exerciser's
    ///      own cost bound, which the PoolManager returns verbatim from the unlock this router opened; it
    ///      is request data, it is checked against authoritative accounting rather than trusted, and it is
    ///      the only value that crosses this boundary. The swap itself is asked of the Hook rather than
    ///      chosen here or forwarded from the request, and so are the two parties settlement moves value
    ///      between. Direction, exact-output mode, the quantity, the qualification boundary, the payer, and
    ///      the recipient are all Standby facts, and a router that composed its own version of them would
    ///      be a second, silently divergent statement of what a Standby exercise executes and who it is for.
    ///
    ///      Nothing about proposing the right swap is what makes it acceptable. The Hook revalidates the
    ///      operation on the authoritative PoolManager callback path against its own causal context, so this
    ///      contract can propose and never authorize.
    ///
    ///      It is `virtual` for one reason, and the reason is not extensibility: the F8B execution evidence
    ///      is verified against a committed real-PoolManager swap that has no settlement behind it, which
    ///      requires a test-only subclass to close the resulting deltas mechanically. Nothing in production
    ///      overrides it.
    /// @param _data The encoded exercise-local cost bound of the request that opened this unlock.
    /// @return result The encoded balance delta of the performed execution.
    function unlockCallback(bytes calldata _data) external virtual returns (bytes memory result) {
        (PoolKey memory key, SwapParams memory params, BalanceDelta delta) = _executeAuthorizedExercise();

        _resolveExecutedExercise(key, params, delta, abi.decode(_data, (uint256)));

        result = abi.encode(delta);
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
    ///
    ///      It returns the operation it performed as well as the delta that operation produced, because
    ///      settlement needs the exact currencies of exactly this execution. Reconstructing a second
    ///      description of the protected operation to answer that question would create a second statement
    ///      of what an exercise trades, and the two could disagree.
    function _executeAuthorizedExercise()
        internal
        returns (PoolKey memory key, SwapParams memory params, BalanceDelta delta)
    {
        if (msg.sender != address(i_poolManager)) revert ExerciseRouter__NotPoolManager(msg.sender);

        (key, params) = i_hook.authorizedProtectedExecution();

        delta = i_poolManager.swap(key, params, bytes(""));
    }

    /// @dev Settles the executed protected swap's input debt and delivers its protected output.
    ///
    ///      The order is the economic one and every step of it is load-bearing. The Hook's causal context
    ///      is read first, because it is the only authority that this execution happened and the only
    ///      source of the two parties involved: the authenticated exerciser who pays and the authoritative
    ///      Beneficiary who is paid. Neither is inferred from the PoolManager, from this router's address,
    ///      or from anything the request supplied.
    ///
    ///      The cost bound is checked before any value moves, so a breached bound cannot leave a partial
    ///      settlement behind even momentarily. Input is settled before output is delivered, because taking
    ///      the protected output first would hand the Beneficiary currency drawn against a debt that had
    ///      not yet been paid.
    ///
    ///      Both sides are then required to be closed. The PoolManager would refuse to return from the
    ///      unlock with any delta outstanding, so an unresolved side could never commit — but that refusal
    ///      is a count of open deltas rather than a statement about this exercise, and Standby's requirement
    ///      is specifically that this execution's own input debt and output credit were resolved, exactly,
    ///      by these two operations.
    function _resolveExecutedExercise(
        PoolKey memory _key,
        SwapParams memory _params,
        BalanceDelta _delta,
        uint256 _maxInput
    ) internal {
        StandbyHook.ExerciseAuthorizationContext memory context = i_hook.exerciseAuthorization();

        if (context.state != StandbyHook.ExerciseAuthorizationState.EXECUTED) {
            revert ExerciseRouter__ExerciseNotExecuted(context.state);
        }

        (Currency inputCurrency, Currency outputCurrency, uint256 actualInput) =
            _executedExerciseSettlement(_key, _params, _delta);

        if (actualInput > _maxInput) revert ExerciseRouter__ExerciseCostExceedsMaxInput(actualInput, _maxInput);

        _settleExerciseInput(inputCurrency, context.exerciser, actualInput);

        _deliverProtectedOutput(outputCurrency, context.beneficiary, context.q);
    }

    /// @dev Derives the settlement currencies and the authoritative input debt of an executed swap.
    ///
    ///      Everything here comes from the operation the PoolManager actually performed and the delta it
    ///      actually produced. Which currency is spent and which is received follows from the direction of
    ///      that operation and from nothing else — a protected `zeroForOne` execution spends `currency0`
    ///      and produces `currency1`, and `oneForZero` is its mirror — so no caller-supplied currency
    ///      identity is consulted or could be.
    ///
    ///      The debt is the input side of the authoritative `BalanceDelta`, and its sign is part of what
    ///      makes it authoritative: a negative amount is currency the swap caller owes the PoolManager,
    ///      which is the only thing this router may settle. A zero or positive input side is refused rather
    ///      than reinterpreted, because taking an absolute value would turn a credit into a payment and a
    ///      wrong-sided read into a plausible-looking amount.
    ///
    ///      The negation widens to `int256` first. A v4 delta amount is `int128`, and negating `int128` at
    ///      its minimum value overflows in place; widening before negating cannot, so the whole signed
    ///      domain the PoolManager can express is converted exactly or refused, never wrapped.
    function _executedExerciseSettlement(PoolKey memory _key, SwapParams memory _params, BalanceDelta _delta)
        internal
        pure
        returns (Currency inputCurrency, Currency outputCurrency, uint256 actualInput)
    {
        int256 inputDelta;

        if (_params.zeroForOne) {
            (inputCurrency, outputCurrency, inputDelta) = (_key.currency0, _key.currency1, int256(_delta.amount0()));
        } else {
            (inputCurrency, outputCurrency, inputDelta) = (_key.currency1, _key.currency0, int256(_delta.amount1()));
        }

        if (inputDelta >= 0) revert ExerciseRouter__NoAuthoritativeInputDebt(inputDelta);

        actualInput = uint256(-inputDelta);
    }

    /// @dev Funds exactly the authoritative input debt from the authenticated exerciser to the PoolManager.
    ///
    ///      The path is deliberately direct. `sync` records what the PoolManager holds, the exerciser's own
    ///      currency is moved straight into it, and `settle` credits the difference — so the currency never
    ///      passes through this router, and a balance this router happens to hold can never become the
    ///      source of a Standby settlement. The allowance mechanics are the only part of this the router
    ///      coordinates, and an allowance is not custody.
    ///
    ///      The amount is exactly the debt. Not the bound the request carried, not what the pool was
    ///      expected to charge, and not what this router could afford.
    function _settleExerciseInput(Currency _inputCurrency, address _exerciser, uint256 _actualInput) internal {
        i_poolManager.sync(_inputCurrency);

        bool paid = IERC20Minimal(Currency.unwrap(_inputCurrency)).transferFrom(
            _exerciser, address(i_poolManager), _actualInput
        );

        if (!paid) {
            revert ExerciseRouter__InputTransferFailed(Currency.unwrap(_inputCurrency), _exerciser, _actualInput);
        }

        i_poolManager.settle();

        _requireResolvedDelta(_inputCurrency);
    }

    /// @dev Discharges the protected-output credit by having the PoolManager pay the Beneficiary directly.
    ///
    ///      One operation, for the exact authorized quantity, to the account the Hook resolved from
    ///      authoritative commitment state (RR-O2-16, RR-O2-17). The output does not pass through this
    ///      router on its way there and there is no supported path by which it could: no split delivery, no
    ///      redirection, no claim tokens, and no intermediate custody to withdraw from later.
    function _deliverProtectedOutput(Currency _outputCurrency, address _beneficiary, uint256 _q) internal {
        i_poolManager.take(_outputCurrency, _beneficiary, _q);

        _requireResolvedDelta(_outputCurrency);
    }

    /// @dev Requires this router's PoolManager delta in one currency to be fully closed.
    function _requireResolvedDelta(Currency _currency) internal view {
        int256 remainingDelta = i_poolManager.currencyDelta(address(this), _currency);

        if (remainingDelta != 0) {
            revert ExerciseRouter__UnresolvedExerciseDelta(Currency.unwrap(_currency), remainingDelta);
        }
    }

    /// @dev Requires the exercise's causal proof to have been consumed before the request may return.
    ///
    ///      The condition is stated as what completion actually requires rather than as a slice marker, so
    ///      the slice that consumes the context satisfies it by doing its own work and nothing here has to
    ///      be revisited or removed. Until then every production exercise fails here, atomically, with the
    ///      swap, the settlement, and the delivery unwound with it.
    ///
    ///      It is `virtual` for one reason, and the reason is not extensibility: verifying that the
    ///      settlement and delivery mechanics themselves are correct requires observing a committed
    ///      exercise, which no production path can produce while finalization does not exist. Nothing in
    ///      production overrides it.
    function _requireFinalizedExercise() internal view virtual {
        StandbyHook.ExerciseAuthorizationState state = i_hook.exerciseAuthorization().state;

        if (state != StandbyHook.ExerciseAuthorizationState.EMPTY) {
            revert ExerciseRouter__ExerciseNotFinalized(state);
        }
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
