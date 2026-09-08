// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseUnbackedExerciseAuthorizationTest} from "../shared/BaseUnbackedExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Unit evidence for the F8D causal prerequisites, the final-backing comparison, and exact-once
///         consumption (G8D-A, G8D-B, G8D-C, G8D-D).
/// @dev Everything F8D refuses is something the reachable production system cannot present to it, and that
///      is a property of the protocol working rather than a gap in the evidence. A production finalization
///      arrives from inside a PoolManager unlock, immediately after a swap this Hook accepted, proved,
///      settled, and delivered — so a context that is not `EXECUTED`, a caller that is not the bound
///      ExerciseRouter, a commitment that is not the bound one, a remainder smaller than the proven
///      quantity, and a post-execution state that is no longer backed are all unreachable there. Each is
///      nonetheless a requirement, and each is verifiable only by constructing it directly.
///
///      This is the F8A unbacked fixture, unchanged: the real PoolManager, the real pool, the production
///      activation, the canonical liquidity through the production liquidity path, the real registry, the
///      real ExerciseRouter, and commitments created only by the production O1 transition — with a
///      `StandbyHookHarness` in the production Hook's place. The harness contributes two abilities and no
///      economics: writing a causal context at a chosen position, and writing a commitment's Remaining
///      Entitlement directly.
///
///      A context written that way is a starting position, not an authorization: nothing authenticated it,
///      no swap stands behind it, and nothing was delivered for it. It is valid evidence about what
///      finalization requires of the position it is handed, and about nothing else. In particular, no test
///      here is evidence that a production exercise fulfils anything — that is the integration suite's.
contract ExerciseFinalizationTest is BaseUnbackedExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /// @dev The proven quantity every seeded context carries: 20,000 MockUSDC.
    uint256 internal constant PROVEN_Q = 20_000_000_000;

    /// @dev The entitlement used where a test needs two commitments at once: 25,000 MockUSDC.
    ///
    ///      Two of these are admissible against the canonical initial Supporting Capacity and two canonical
    ///      entitlements are not, so the pair is chosen by what the fixture can actually back rather than
    ///      by convenience. Nothing below turns on the value.
    uint128 internal constant PAIRED_ENTITLEMENT = 25_000_000_000;

    /*//////////////////////////////////////////////////////////////
                    G8D-A — A PROVEN EXECUTION IS REQUIRED
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an absent causal context finalizes nothing.
    /// @dev The position every transaction that never exercised is in, and the position a consumed context
    ///      returns to. An ordinary swap, a direct transfer, a liquidity action, and a replayed
    ///      finalization all present exactly this and are all refused by it.
    function test_absentContext_finalizesNothing() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _expectUnprovenRefusal(StandbyHook.ExerciseAuthorizationState.EMPTY);

        _finalize(commitmentId);

        _assertRemainingEntitlement(commitmentId, CANONICAL_ENTITLEMENT, "an absent context must fulfil nothing");
    }

    /// @notice Proves an authorization that has not executed finalizes nothing.
    /// @dev Every binding a fulfillment needs is present — this commitment, this exerciser, this
    ///      Beneficiary, this quantity — and the pool has still produced nothing. Reducing the entitlement
    ///      here would discharge an obligation against a delivery that never happened.
    function test_authorizedButUnexecutedContext_finalizesNothing() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.AUTHORIZED);

        _expectUnprovenRefusal(StandbyHook.ExerciseAuthorizationState.AUTHORIZED);

        _finalize(commitmentId);

        _assertRemainingEntitlement(commitmentId, CANONICAL_ENTITLEMENT, "an unexecuted exercise must fulfil nothing");
    }

    /// @notice Proves a swap merely in flight finalizes nothing.
    function test_inFlightContext_finalizesNothing() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTING);

        _expectUnprovenRefusal(StandbyHook.ExerciseAuthorizationState.EXECUTING);

        _finalize(commitmentId);

        _assertRemainingEntitlement(commitmentId, CANONICAL_ENTITLEMENT, "an in-flight swap must fulfil nothing");
    }

    /// @notice Proves an undecided authorization finalizes nothing.
    function test_undecidedContext_finalizesNothing() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.AUTHORIZING);

        _expectUnprovenRefusal(StandbyHook.ExerciseAuthorizationState.AUTHORIZING);

        _finalize(commitmentId);

        _assertRemainingEntitlement(commitmentId, CANONICAL_ENTITLEMENT, "an undecided attempt must fulfil nothing");
    }

    /*//////////////////////////////////////////////////////////////
                    G8D-A — THE BOUND COORDINATOR IS REQUIRED
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an account with no relationship to the exercise cannot finalize it.
    /// @dev The proof exists, is complete, and belongs to somebody else. Finalization is not a public
    ///      transition that anyone may complete on the protocol's behalf.
    function test_unrelatedAccount_cannotFinalize() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED);

        _expectFinalizerRefusal(unauthorizedExerciser);

        vm.prank(unauthorizedExerciser);
        hook.finalizeExercise(commitmentId);

        _assertRemainingEntitlement(commitmentId, CANONICAL_ENTITLEMENT, "an outsider must fulfil nothing");
    }

    /// @notice Proves the commitment's own exercise authority cannot finalize its exercise directly.
    /// @dev The one account that may exercise this commitment, and it still may not reach the fulfillment
    ///      transition except through the coordinator the proof is bound to — because what finalization
    ///      completes is a specific coordinated operation, not a right the authority holds standing.
    function test_exerciseAuthority_cannotFinalizeDirectly() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED);

        _expectFinalizerRefusal(commitmentExerciseAuthority);

        vm.prank(commitmentExerciseAuthority);
        hook.finalizeExercise(commitmentId);

        _assertRemainingEntitlement(commitmentId, CANONICAL_ENTITLEMENT, "the exercise authority must fulfil nothing");
    }

    /// @notice Proves an identical but unconfigured ExerciseRouter cannot finalize.
    /// @dev Same bytecode, same Hook, no configuration. What authorizes finalization is being the
    ///      coordinator this proof was produced through, which is a Hook-owned fact rather than a property
    ///      of an implementation.
    function test_unconfiguredRouter_cannotFinalize() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED);

        _expectFinalizerRefusal(address(unconfiguredExerciseRouter));

        vm.prank(address(unconfiguredExerciseRouter));
        hook.finalizeExercise(commitmentId);

        _assertRemainingEntitlement(commitmentId, CANONICAL_ENTITLEMENT, "an unconfigured router must fulfil nothing");
    }

    /*//////////////////////////////////////////////////////////////
                    G8D-A, G8D-D — THE BOUND COMMITMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a finalization naming another commitment is refused rather than redirected.
    /// @dev Two authentic commitments exist and the proof is bound to the first. The request names the
    ///      second, and the outcome is neither "the second is fulfilled" nor "the first is fulfilled
    ///      anyway": it is a refusal, so a caller cannot discover which commitment a proof belongs to by
    ///      watching what a wrong guess does.
    function test_crossCommitmentFinalization_isRefused() public {
        uint256 provenCommitmentId =
            _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED, PAIRED_ENTITLEMENT, PROVEN_Q);
        uint256 otherCommitmentId = _establishExercisable(PAIRED_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotTheProvenExerciseCommitment.selector, otherCommitmentId, provenCommitmentId
            )
        );

        _finalize(otherCommitmentId);

        _assertRemainingEntitlement(provenCommitmentId, PAIRED_ENTITLEMENT, "the proven commitment must be intact");
        _assertRemainingEntitlement(otherCommitmentId, PAIRED_ENTITLEMENT, "the named commitment must be intact");
    }

    /*//////////////////////////////////////////////////////////////
              G8D-A, G8D-C — THE QUANTITY COMES FROM THE PROOF
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the reduction is the quantity the context carries, whatever the caller wanted.
    /// @dev The finalization surface carries no quantity at all, so this is what "the caller cannot
    ///      substitute `q`" means concretely: two identical requests differing only in the quantity their
    ///      proofs were bound to reduce the entitlement by those two different amounts, and nothing the
    ///      caller passes participates.
    function test_reduction_followsTheProvenQuantity() public {
        uint256 smallCommitmentId =
            _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED, PAIRED_ENTITLEMENT, 1);

        _finalize(smallCommitmentId);

        _assertRemainingEntitlement(
            smallCommitmentId, PAIRED_ENTITLEMENT - 1, "one raw unit of proof must fulfil one raw unit"
        );

        uint256 largeCommitmentId =
            _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED, PAIRED_ENTITLEMENT, PROVEN_Q);

        _finalize(largeCommitmentId);

        _assertRemainingEntitlement(
            largeCommitmentId,
            PAIRED_ENTITLEMENT - uint128(PROVEN_Q),
            "a larger proof must fulfil exactly that larger quantity"
        );
    }

    /// @notice Proves the whole remainder can be discharged, leaving exactly zero.
    /// @dev Complete fulfillment is `Remaining == 0` and nothing else: no flag is set, and the obligation
    ///      the commitment carried disappears because it is derived from the remainder that just reached
    ///      zero.
    function test_exhaustingProof_leavesZeroRemainingAndZeroObligation() public {
        uint256 commitmentId = _seededCommitment(
            StandbyHook.ExerciseAuthorizationState.EXECUTED, CANONICAL_ENTITLEMENT, CANONICAL_ENTITLEMENT
        );

        _finalize(commitmentId);

        _assertRemainingEntitlement(commitmentId, 0, "exact exhaustion must produce zero Remaining Entitlement");

        assertEq(hook.commitmentObligation(commitmentId), 0, "an exhausted commitment must carry no obligation");
        assertEq(hook.aggregateObligation(), 0, "the aggregate must release the exhausted commitment entirely");
        assertEq(
            uint256(_commitmentFacts(commitmentId).originalEntitlement),
            uint256(CANONICAL_ENTITLEMENT),
            "the admitted extent must survive complete fulfillment"
        );
    }

    /*//////////////////////////////////////////////////////////////
             G8D-A, G8D-C — AUTHORITATIVE STATE IS RE-READ
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a proof larger than the current remainder is refused rather than clamped.
    /// @dev Finalization does not trust the extent its own authorization admitted; it re-reads the
    ///      commitment and compares against what the record says now. A remainder smaller than the proven
    ///      quantity is a state finalization must not resolve by fulfilling less, because a partial
    ///      fulfillment of a complete delivery would discharge less obligation than was actually delivered.
    function test_proofExceedingTheCurrentRemainder_isRefused() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED);

        uint128 shortenedRemainder = uint128(PROVEN_Q) - 1;

        _writeRemainingEntitlement(commitmentId, shortenedRemainder);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__FulfillmentExceedsRemainingEntitlement.selector, PROVEN_Q, shortenedRemainder
            )
        );

        _finalize(commitmentId);

        _assertRemainingEntitlement(commitmentId, shortenedRemainder, "a refused finalization must fulfil nothing");
    }

    /*//////////////////////////////////////////////////////////////
                  G8D-B — ACTUAL POST-EXECUTION BACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a resulting state that would be unbacked refuses the fulfillment.
    /// @dev The comparison is between two present facts: the Supporting Capacity the pool actually has, and
    ///      the obligation that would remain once exactly the proven quantity is released. The remainder is
    ///      inflated past what this pool can support, so releasing `q` still leaves more obligation than
    ///      capacity — and the refusal names both derived quantities rather than a generic failure.
    function test_unbackedResultingState_refusesFulfillment() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED);

        uint256 capacity = _referenceSupportingCapacity();
        uint128 unbackedRemainder = uint128(capacity + PROVEN_Q + 1);

        _writeRemainingEntitlement(commitmentId, unbackedRemainder);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientFinalExerciseBacking.selector, capacity, capacity + 1
            )
        );

        _finalize(commitmentId);

        _assertRemainingEntitlement(commitmentId, unbackedRemainder, "an unbacked result must fulfil nothing");
    }

    /// @notice Proves a resulting state exactly at the backing boundary is accepted.
    /// @dev The boundary that must not be off by one in the safe direction. Capacity exactly equal to the
    ///      obligation the fulfillment leaves behind preserves backing, and refusing it would refuse a
    ///      fulfillment the frozen requirement admits.
    function test_exactlyBackedResultingState_isAccepted() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED);

        uint256 capacity = _referenceSupportingCapacity();
        uint128 exactRemainder = uint128(capacity + PROVEN_Q);

        _writeRemainingEntitlement(commitmentId, exactRemainder);

        _finalize(commitmentId);

        _assertRemainingEntitlement(
            commitmentId, uint128(capacity), "exact final backing must fulfil exactly the proven quantity"
        );

        assertEq(
            hook.aggregateObligation(), hook.supportingCapacity(), "the fulfilled state must sit exactly at backing"
        );
    }

    /// @notice Proves the authorization-time prediction cannot stand in for the actual resulting state.
    /// @dev Both quantities are present in the fixture and they are different numbers. The prospective
    ///      capacity of the canonical exercise is `S - q`, which would clear an obligation this pool cannot
    ///      actually support; the refusal reports `S` instead, so the comparison demonstrably used the state
    ///      the pool is in rather than a prediction about a swap.
    function test_finalBacking_usesActualCapacityRatherThanTheProspectivePrediction() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED);

        uint256 capacity = _referenceSupportingCapacity();
        uint256 prospectiveCapacity = _expectedProspectiveExerciseCapacity(PROVEN_Q);

        assertLt(prospectiveCapacity, capacity, "the prediction and the actual state must be distinguishable");

        _writeRemainingEntitlement(commitmentId, uint128(capacity + PROVEN_Q + 1));

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientFinalExerciseBacking.selector, capacity, capacity + 1
            )
        );

        _finalize(commitmentId);
    }

    /*//////////////////////////////////////////////////////////////
                  G8D-D — EXACT-ONCE CAUSAL CONSUMPTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a successful finalization consumes the whole causal context.
    /// @dev Every binding is checked, not only the position. A context that reported `EMPTY` while still
    ///      carrying a commitment, an actor, a Beneficiary, or a quantity would be exactly the reusable
    ///      evidence consumption exists to destroy.
    function test_finalization_consumesTheWholeCausalContext() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED);

        _finalize(commitmentId);

        _assertNoAuthorizationContext("finalization must leave no reusable causal evidence");
    }

    /// @notice Proves one proven execution can reduce Remaining Entitlement exactly once.
    /// @dev The replay, made as directly as it can be made: the same coordinator, the same commitment, in
    ///      the same transaction, immediately after the finalization that succeeded. It is refused against
    ///      the consumed position, and the entitlement moved once.
    function test_finalization_cannotBeReplayed() public {
        uint256 commitmentId = _seededCommitment(StandbyHook.ExerciseAuthorizationState.EXECUTED);

        _finalize(commitmentId);

        _expectUnprovenRefusal(StandbyHook.ExerciseAuthorizationState.EMPTY);

        _finalize(commitmentId);

        _assertRemainingEntitlement(
            commitmentId, CANONICAL_ENTITLEMENT - uint128(PROVEN_Q), "one proof must cause exactly one reduction"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Requests finalization as the ExerciseRouter the seeded proofs are bound to.
    function _finalize(uint256 _commitmentId) internal {
        vm.prank(exerciseRouter);
        hook.finalizeExercise(_commitmentId);
    }

    /// @dev Admits an authentic commitment and seeds a causal context bound to it at a chosen position.
    function _seededCommitment(StandbyHook.ExerciseAuthorizationState _state) internal returns (uint256 commitmentId) {
        commitmentId = _seededCommitment(_state, CANONICAL_ENTITLEMENT, PROVEN_Q);
    }

    /// @dev The same, with the admitted extent and the proven quantity chosen explicitly.
    ///
    ///      The commitment is admitted by the production O1 transition and every fact about it is
    ///      authentic. The context is not: it is written directly, at a position no swap put it in, so that
    ///      one finalization requirement can be addressed at a time.
    function _seededCommitment(StandbyHook.ExerciseAuthorizationState _state, uint128 _entitlement, uint256 _q)
        internal
        returns (uint256 commitmentId)
    {
        commitmentId = _establishExercisable(_entitlement);

        serviceHarness.writeExerciseAuthorization(
            StandbyHook.ExerciseAuthorizationContext({
                state: _state,
                serviceId: servicePoolId,
                commitmentId: commitmentId,
                exerciseRouter: exerciseRouter,
                exerciser: commitmentExerciseAuthority,
                beneficiary: beneficiary,
                q: _q
            })
        );
    }

    /// @dev Expects the refusal of a finalization offered against a position that proves no execution.
    function _expectUnprovenRefusal(StandbyHook.ExerciseAuthorizationState _state) internal {
        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__NoProvenExerciseToFinalize.selector, _state));
    }

    /// @dev Expects the refusal of a finalization requested by anything but the bound coordinator.
    function _expectFinalizerRefusal(address _caller) internal {
        vm.expectRevert(
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotAuthorizedExerciseFinalizer.selector, _caller)
        );
    }

    /// @dev Reads a commitment's authoritative fact record.
    function _commitmentFacts(uint256 _commitmentId) internal view returns (StandbyHook.Commitment memory record) {
        record = hook.commitment(_commitmentId);
    }

    /// @dev Asserts a commitment's authoritative Remaining Entitlement.
    function _assertRemainingEntitlement(uint256 _commitmentId, uint128 _expected, string memory _context)
        internal
        view
    {
        assertEq(uint256(_commitmentFacts(_commitmentId).remainingEntitlement), uint256(_expected), _context);
    }
}
