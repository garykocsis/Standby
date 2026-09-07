// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseCommitmentAdmissionTest} from "../shared/BaseCommitmentAdmissionTest.t.sol";
import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Fuzz evidence for the F7 O1 admission boundaries (G7.3, G7.10, G7.12, G7.14).
/// @dev The three boundaries F7 has to get exactly right are all boundaries of one unit: the temporal
///      window at its half-open endpoints, the backing comparison at `S == O'`, and the identity sequence
///      across successes, failures, and reference reuse. Each run below decides independently what the
///      production transition should do — from the frozen conditions or from `ReferenceCalculations`, not
///      from the Hook — and then checks that it did that.
///
///      Inputs are bounded to their semantic domains rather than clamped into the passing region. Every
///      temporal run can land on either side of both endpoints, and every backing run can land on either
///      side of exact sufficiency, so the failure regions stay reachable.
///
///      No harness participates: each run drives the production `establishCommitment` transition against
///      the real activated service and the real canonical liquidity.
contract CommitmentAdmissionFuzzTest is BaseCommitmentAdmissionTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A comfortably backed entitlement for the runs whose subject is not the backing boundary.
    uint128 internal constant TEMPORAL_FUZZ_Q = 1_000 * 10 ** 6;

    /// @dev A per-commitment entitlement small enough that a full bounded index stays trivially backed.
    uint128 internal constant TINY_Q = 1 * 10 ** 6;

    /// @dev How far either side of the present the fuzzed window endpoints may fall.
    uint64 internal constant WINDOW_FUZZ_SPAN = 100 days;

    /*//////////////////////////////////////////////////////////////
                    G7.3 — TEMPORAL ADMISSION BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves admission accepts exactly the admissible windows and refuses the rest.
    /// @dev Both endpoints are fuzzed independently across a span that straddles the present, so runs
    ///      reach every combination that matters: an ordered future window, an already-open window, a
    ///      window that opens exactly now, a degenerate window, an inverted one, and a window whose
    ///      validity has already ended — including the two exact instants where the half-open comparisons
    ///      flip.
    ///
    ///      The expected answer is composed from the frozen conditions and the independent validity
    ///      oracle, never from the Hook, and the expected rejection reason is named exactly, so a run
    ///      cannot pass by rejecting the right window for the wrong reason.
    function testFuzz_admission_acceptsExactlyTheAdmissibleWindows(uint64 _exercisableFrom, uint64 _validUntil)
        public
    {
        uint64 exercisableFrom = _boundedWindowEndpoint(_exercisableFrom);
        uint64 validUntil = _boundedWindowEndpoint(_validUntil);

        bool orderedWindow = validUntil > exercisableFrom;
        bool stillValid = ReferenceCalculations.referenceValid(validUntil, block.timestamp);

        if (orderedWindow && stillValid) {
            uint256 commitmentId = _establishWithWindow(TEMPORAL_FUZZ_Q, exercisableFrom, validUntil);

            assertEq(hook.commitmentObligation(commitmentId), TEMPORAL_FUZZ_Q, "an admitted window must bind in full");
            assertEq(hook.aggregateObligation(), TEMPORAL_FUZZ_Q, "the admitted commitment must contribute to O");

            return;
        }

        AdmissionState memory before = _admissionState();

        bytes memory reason = orderedWindow
            ? abi.encodeWithSelector(
                StandbyHook.StandbyHook__CommitmentAlreadyInvalid.selector, validUntil, block.timestamp
            )
            : abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidCommitmentWindow.selector, exercisableFrom, validUntil);

        vm.expectRevert(reason);
        vm.prank(establishmentAuthority);
        hook.establishCommitment(beneficiary, commitmentExerciseAuthority, TEMPORAL_FUZZ_Q, exercisableFrom, validUntil);

        _assertNoAdmissionResidue(before, "an inadmissible window must leave no residue");
    }

    /*//////////////////////////////////////////////////////////////
                    G7.10 — EXACT BACKING BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves admission accepts exactly the entitlements the derived capacity backs.
    /// @dev The entitlement is fuzzed across a range reaching well past capacity, so runs land on both
    ///      sides of exact sufficiency and on the boundary itself. Capacity is taken from the production
    ///      derivation but independently confirmed against the reference oracle, so the boundary being
    ///      checked is the economically correct one and not merely self-consistent.
    function testFuzz_admission_acceptsExactlyTheBackedEntitlements(uint128 _originalEntitlement) public {
        uint256 capacity = _authoritativeCapacity();

        uint128 originalEntitlement = uint128(bound(uint256(_originalEntitlement), 1, capacity * 2));

        if (originalEntitlement <= capacity) {
            uint256 commitmentId = _establish(originalEntitlement);

            assertEq(hook.aggregateObligation(), originalEntitlement, "the admitted entitlement must bind in full");
            assertEq(hook.supportingCapacity(), capacity, "admission must not change capacity");
            assertGe(hook.supportingCapacity(), hook.aggregateObligation(), "backing must still hold");
            assertEq(
                uint256(hook.commitment(commitmentId).remainingEntitlement),
                uint256(originalEntitlement),
                "Remaining must equal the admitted extent"
            );

            return;
        }

        AdmissionState memory before = _admissionState();

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientAdmissionBacking.selector, capacity, uint256(originalEntitlement)
            )
        );
        vm.prank(establishmentAuthority);
        hook.establishCommitment(
            beneficiary, commitmentExerciseAuthority, originalEntitlement, exercisableFrom, validUntil
        );

        _assertNoAdmissionResidue(before, "an unbacked admission must leave no residue");
    }

    /// @notice Proves the backing boundary is the aggregate one once a commitment already exists.
    /// @dev The first commitment's obligation moves the boundary for the second by exactly its own
    ///      entitlement. A per-commitment comparison would admit the whole failing region here.
    function testFuzz_admission_boundaryFollowsTheExistingObligation(uint128 _first, uint128 _second) public {
        uint256 capacity = _authoritativeCapacity();

        uint128 first = uint128(bound(uint256(_first), 1, capacity));

        _establish(first);

        uint256 headroom = capacity - uint256(first);

        uint128 second = uint128(bound(uint256(_second), 1, capacity));

        if (uint256(second) <= headroom) {
            _establish(second);

            assertEq(hook.aggregateObligation(), uint256(first) + uint256(second), "both obligations must bind");
            assertGe(hook.supportingCapacity(), hook.aggregateObligation(), "backing must still hold");

            return;
        }

        AdmissionState memory before = _admissionState();

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientAdmissionBacking.selector,
                capacity,
                uint256(first) + uint256(second)
            )
        );
        vm.prank(establishmentAuthority);
        hook.establishCommitment(beneficiary, commitmentExerciseAuthority, second, exercisableFrom, validUntil);

        _assertNoAdmissionResidue(before, "an unbacked second admission must leave no residue");
    }

    /*//////////////////////////////////////////////////////////////
                       G7.14 — COMMITMENT IDENTITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a sequence of admissions produces unique, monotonic, singly-referenced identities.
    /// @dev Each admission is separated from the next by a rejected attempt, so every run also proves that
    ///      failures consume no identity: the successful identities stay consecutive despite the failures
    ///      interleaved between them.
    function testFuzz_admissions_produceUniqueMonotonicSinglyReferencedIdentities(uint8 _count) public {
        uint256 count = bound(uint256(_count), 1, MAX_LIVE_COMMITMENTS);

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        for (uint256 i = 0; i < count; ++i) {
            uint256 commitmentId = _establish(TINY_Q);

            assertEq(commitmentId, i + 1, "identities must be consecutive from 1");

            (bool referenced,) = _referenceSlotOf(commitmentId);

            assertTrue(referenced, "every admitted commitment must be referenced exactly once");
            assertEq(_occupiedReferenceCount(), i + 1, "each admission must occupy exactly one further slot");

            vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidOriginalEntitlement.selector));
            vm.prank(establishmentAuthority);
            hook.establishCommitment(beneficiary, commitmentExerciseAuthority, 0, exercisableFrom, validUntil);
        }

        assertEq(hook.nextCommitmentId(), count + 1, "failed attempts must not have advanced the sequence");
        assertEq(hook.aggregateObligation(), count * uint256(TINY_Q), "every admitted commitment must contribute");
    }

    /*//////////////////////////////////////////////////////////////
                    G7.12 — RECLAIMABLE SLOT REUSE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves any reclaimable slot in a full index may be reused, wherever it sits.
    /// @dev The terminal commitment's position is fuzzed across the whole bounded index, so reclamation
    ///      cannot appear to work because of a boundary slot or a scan that starts in a lucky place. The
    ///      displaced identity is never handed out again and its record is never rewritten.
    function testFuzz_fullIndex_reusesAnyReclaimableSlot(uint8 _slot) public {
        uint256 terminalSlot = bound(uint256(_slot), 0, MAX_LIVE_COMMITMENTS - 1);

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        uint64 shortValidUntil = uint64(block.timestamp) + 1 days;
        uint256 terminalId;

        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            if (i == terminalSlot) {
                terminalId = _establishWithWindow(TINY_Q, exercisableFrom, shortValidUntil);
            } else {
                _establishWithWindow(TINY_Q, exercisableFrom, validUntil);
            }
        }

        StandbyHook.Commitment memory historyBefore = hook.commitment(terminalId);

        vm.warp(uint256(shortValidUntil));

        assertEq(hook.commitmentObligation(terminalId), 0, "the terminal commitment must impose nothing");

        uint256 newId = _establishWithWindow(TINY_Q, exercisableFrom, validUntil);

        assertEq(newId, MAX_LIVE_COMMITMENTS + 1, "the new commitment must receive a fresh identity");

        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        assertEq(references[terminalSlot], newId, "the reclaimed slot must reference the new commitment");
        assertEq(_occupiedReferenceCount(), MAX_LIVE_COMMITMENTS, "the index must remain exactly full");

        StandbyHook.Commitment memory historyAfter = hook.commitment(terminalId);

        assertEq(
            uint256(historyAfter.remainingEntitlement),
            uint256(historyBefore.remainingEntitlement),
            "a displaced record must not be rewritten"
        );
        assertEq(uint256(historyAfter.validUntil), uint256(historyBefore.validUntil), "a displaced record is permanent");

        assertEq(
            hook.aggregateObligation(),
            uint256(TINY_Q) * MAX_LIVE_COMMITMENTS,
            "the aggregate must count the new commitment and not the displaced one"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Bounds a fuzzed window endpoint to a span straddling the present.
    ///
    ///      The span is deliberately symmetric around now, so past, present, and future endpoints are all
    ///      reachable and neither half-open comparison can be trivially satisfied by the bound itself.
    function _boundedWindowEndpoint(uint64 _raw) internal view returns (uint64 endpoint) {
        endpoint = uint64(
            bound(
                uint256(_raw), block.timestamp - uint256(WINDOW_FUZZ_SPAN), block.timestamp + uint256(WINDOW_FUZZ_SPAN)
            )
        );
    }

    /// @dev Returns current Supporting Capacity, confirmed against the independent reference oracle.
    function _authoritativeCapacity() internal view returns (uint256 capacity) {
        capacity = hook.supportingCapacity();

        (uint160 sqrtPriceX96,, uint128 liquidity) = _servicePoolState();

        assertEq(
            capacity,
            ReferenceCalculations.referenceSupportingCapacity(
                hook.protectedExecutionService().protectedZeroForOne,
                sqrtPriceX96,
                hook.protectedExecutionService().tickQ,
                liquidity
            ),
            "the production capacity must equal the independent derivation"
        );
    }
}
