// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseCommitmentAdmissionTest} from "../shared/BaseCommitmentAdmissionTest.t.sol";
import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for F7 O1 commitment admission against real Uniswap v4 state
///         (G7.6–G7.13, G7.15–G7.19).
/// @dev Everything here runs against the production `StandbyHook`, the real pinned `PoolManager`, and
///      canonical liquidity that was itself added through the production `beforeAddLiquidity` path. No
///      obligation is written, no capacity is written, no commitment is seeded, and no reference is
///      planted: every commitment these tests reason about was admitted by the production O1 transition.
///
///      This is where the first authentic positive Aggregate Capacity Obligation appears. Until F7 the
///      obligation was zero in every reachable state because nothing could create a commitment; the tests
///      below establish that it is now positive because a real admission made it so, and that it is still
///      derived rather than stored — it moves when time moves, without any transaction being sent.
///
///      Both economic derivations O1 consumes are checked against `ReferenceCalculations` rather than
///      against themselves, so agreement here is agreement between the production derivation and an
///      independently composed one.
contract CommitmentAdmissionIntegrationTest is BaseCommitmentAdmissionTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A per-commitment entitlement small enough that sixteen of them are trivially backed, so a
    ///      bounded-reference test can never be passing because of the backing boundary.
    uint128 internal constant TINY_Q = 1 * 10 ** 6;

    /// @dev The short validity used to make exactly one reference authoritatively reclaimable.
    uint64 internal constant SHORT_VALIDITY = 1 days;

    /// @dev A protected-direction input large enough to visibly consume Supporting Capacity.
    uint256 internal constant CAPACITY_CONSUMING_INPUT = 10_000 * 10 ** 6;

    /*//////////////////////////////////////////////////////////////
                       G7.19 — CANONICAL A1 RESULT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the production system can create the first authentic positive obligation.
    /// @dev The decisive F7 proof. From the canonical bootstrap — `S = 80,000 MockUSDC`, `O = 0`, no
    ///      commitment in existence — one real O1 for `q = 50,000 MockUSDC` must leave `S` untouched,
    ///      `O = 50,000`, and `Remaining = 50,000`.
    ///
    ///      That `S` is unchanged is the whole point of the mechanism, not an incidental detail: Standby
    ///      binds shared liquidity without moving it, so admission takes no custody, reserves nothing, and
    ///      leaves the pool exactly as it found it. The capacity that now backs a 50,000 obligation is the
    ///      same capacity that was there a moment ago and is still fully available to ordinary traders.
    function test_canonicalA1_firstAuthenticPositiveObligation() public {
        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_INITIAL_S, "A1 requires S = 80,000 MockUSDC");
        assertEq(hook.aggregateObligation(), 0, "A1 requires O = 0 before admission");
        assertEq(hook.nextCommitmentId(), 1, "no commitment may exist before admission");

        AdmissionState memory before = _admissionState();

        uint256 commitmentId = _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        assertEq(
            hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_INITIAL_S, "admission must not change capacity"
        );
        assertEq(
            hook.aggregateObligation(), StandbyFixtureConfig.CANONICAL_COMMITMENT_Q, "O must become 50,000 MockUSDC"
        );

        StandbyHook.Commitment memory record = hook.commitment(commitmentId);

        assertEq(
            uint256(record.remainingEntitlement),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "Remaining must be 50,000 MockUSDC"
        );

        assertGt(commitmentId, 0, "the admitted identity must be authentic");
        assertEq(hook.nextCommitmentId(), commitmentId + 1, "the identity sequence must have advanced once");

        (bool referenced,) = _referenceSlotOf(commitmentId);

        assertTrue(referenced, "exactly one bounded reference must identify the commitment");
        assertEq(_occupiedReferenceCount(), 1, "admission must occupy exactly one slot");

        _assertNoPoolOrCustodyEffect(before);
    }

    /*//////////////////////////////////////////////////////////////
                    G7.16 — NO RESERVATION OR CUSTODY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a successful O1 moves no protected output and touches no pool state.
    /// @dev Checked across several admissions rather than one, because a reservation mechanism would be
    ///      easiest to hide behind the first commitment being special.
    function test_successfulAdmissions_takeNoCustodyAndMoveNoPoolState() public {
        AdmissionState memory before = _admissionState();

        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));
        _establish(TINY_Q);
        _establish(TINY_Q);

        _assertNoPoolOrCustodyEffect(before);

        assertEq(hook.aggregateObligation(), StandbyFixtureConfig.CANONICAL_COMMITMENT_Q + 2 * uint256(TINY_Q), "O");
    }

    /*//////////////////////////////////////////////////////////////
                  G7.17 — COMPLETE AUTHORITATIVE BASIS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves every admitted fact is persisted exactly, read through the production surface.
    /// @dev Each term is given a distinct value so a record that stored the right value in the wrong field
    ///      could not pass. The service reference is checked too: a commitment is admitted under one
    ///      Protected Execution Service, and every immutable semantic it needs later is recovered through
    ///      that reference rather than copied beside it.
    function test_admittedCommitment_persistsTheCompleteAuthoritativeBasis() public {
        uint64 exercisableFrom = uint64(block.timestamp) + 3 hours;
        uint64 validUntil = uint64(block.timestamp) + 9 days;
        uint128 originalEntitlement = 12_345 * 10 ** 6;

        uint256 commitmentId = _establishAs(
            establishmentAuthority,
            secondBeneficiary,
            commitmentExerciseAuthority,
            originalEntitlement,
            exercisableFrom,
            validUntil
        );

        StandbyHook.Commitment memory record = hook.commitment(commitmentId);

        assertEq(PoolId.unwrap(record.serviceId), PoolId.unwrap(servicePoolId), "the admitted service reference");
        assertEq(record.beneficiary, secondBeneficiary, "the admitted Beneficiary");
        assertEq(record.exerciseAuthority, commitmentExerciseAuthority, "the admitted exercise authority");
        assertEq(uint256(record.exercisableFrom), uint256(exercisableFrom), "the admitted exercisableFrom");
        assertEq(uint256(record.validUntil), uint256(validUntil), "the admitted validUntil");
        assertEq(uint256(record.originalEntitlement), uint256(originalEntitlement), "the admitted extent");
        assertEq(uint256(record.remainingEntitlement), uint256(originalEntitlement), "the initial remainder");
    }

    /*//////////////////////////////////////////////////////////////
                   G7.6 — BINDING IS NOT EXERCISABILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a commitment whose window has not opened is valid, non-qualified, and fully binding.
    /// @dev `now < TE < TV`. Successful O1 establishes the binding claim immediately, so this commitment
    ///      consumes backing from the instant it exists even though nobody could exercise it yet. The two
    ///      classifications are derived independently from the recorded facts here, so "binding" cannot be
    ///      inherited from "exercisable".
    function test_futureWindowCommitment_isValidAndBindingButNotExerciseQualified() public {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        uint256 commitmentId =
            _establishWithWindow(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q), exercisableFrom, validUntil);

        StandbyHook.Commitment memory record = hook.commitment(commitmentId);

        assertLt(block.timestamp, uint256(record.exercisableFrom), "the window must not have opened");

        assertTrue(
            ReferenceCalculations.referenceValid(record.validUntil, block.timestamp), "the commitment must be valid"
        );
        assertFalse(
            ReferenceCalculations.referenceTemporallyExerciseQualified(
                record.exercisableFrom, record.validUntil, block.timestamp
            ),
            "the commitment must not be exercise-qualified"
        );

        assertGt(hook.commitmentObligation(commitmentId), 0, "an unopened window must still impose CO > 0");
        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "the commitment must contribute to O immediately"
        );
    }

    /*//////////////////////////////////////////////////////////////
                 G7.7 / G7.8 — DERIVED O AND DERIVED CO
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves admission measures against the F5-derived current obligation, not a stored total.
    /// @dev Three observations of the same commitment. While valid it shifts the admissible boundary by
    ///      exactly its own entitlement; once its validity ends the boundary returns to full capacity,
    ///      with no transaction sent to expire it; and the obligation the Hook reports tracks that. A
    ///      stored aggregate could not do the middle step.
    function test_admissionMeasuresAgainstTheDerivedCurrentObligation() public {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        _establishWithWindow(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q), exercisableFrom, validUntil);

        uint256 capacity = hook.supportingCapacity();
        uint256 headroom = capacity - StandbyFixtureConfig.CANONICAL_COMMITMENT_Q;

        _assertAdmissionRejectedForBacking(uint128(headroom + 1), capacity, capacity + 1);

        vm.warp(uint256(validUntil));

        assertEq(hook.aggregateObligation(), 0, "an expired commitment must release its obligation by derivation");

        uint256 secondId = _establish(uint128(capacity));

        assertEq(hook.aggregateObligation(), capacity, "the full capacity must now be admissible again");
        assertEq(secondId, 2, "the expired commitment's identity must not be reused");
    }

    /// @notice Proves the proposed commitment's obligation uses the same F5 semantics as an admitted one.
    /// @dev Two commitments with identical terms, one already authoritative and one being proposed. The
    ///      obligation the admission boundary charges for the proposal is exactly the obligation the Hook
    ///      reports for the admitted twin, and both equal the independent reference derivation.
    function test_proposedCommitmentObligation_matchesAnEquivalentAdmittedCommitment() public {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        uint128 entitlement = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

        uint256 admittedId = _establishWithWindow(entitlement, exercisableFrom, validUntil);

        uint256 admittedObligation = hook.commitmentObligation(admittedId);

        assertEq(
            admittedObligation,
            ReferenceCalculations.referenceCommitmentObligation(entitlement, validUntil, block.timestamp),
            "the admitted obligation must equal the independent derivation"
        );

        uint256 capacity = hook.supportingCapacity();
        uint256 headroom = capacity - admittedObligation;

        _assertAdmissionRejectedForBacking(uint128(headroom + 1), capacity, capacity + 1);

        uint256 secondId = _establishWithWindow(uint128(headroom), exercisableFrom, validUntil);

        assertEq(hook.aggregateObligation(), capacity, "the two obligations must sum to exactly the capacity");
        assertEq(
            hook.commitmentObligation(secondId),
            ReferenceCalculations.referenceCommitmentObligation(uint128(headroom), validUntil, block.timestamp),
            "the second obligation must equal the independent derivation"
        );
    }

    /*//////////////////////////////////////////////////////////////
                G7.9 / G7.18 — AUTHORITATIVE SUPPORTING CAPACITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the admission decision follows authoritative PoolManager state.
    /// @dev A real ordinary swap through the trusted perimeter moves the price and consumes capacity. The
    ///      entitlement that was admissible before the swap is refused afterwards, and the refusal reports
    ///      exactly the capacity the post-swap pool state derives to. Nothing about the proposal changed;
    ///      only the pool did.
    function test_admissionDecision_followsAuthoritativePoolManagerState() public {
        uint256 capacityBefore = hook.supportingCapacity();

        _swapAs(eligibleTrader, _protectedSwapParams(CAPACITY_CONSUMING_INPUT));

        uint256 capacityAfter = hook.supportingCapacity();

        assertLt(capacityAfter, capacityBefore, "the swap must actually consume capacity");

        (uint160 sqrtPriceX96,, uint128 liquidity) = _servicePoolState();

        assertEq(
            capacityAfter,
            ReferenceCalculations.referenceSupportingCapacity(
                StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
                sqrtPriceX96,
                StandbyFixtureConfig.TICK_Q,
                liquidity
            ),
            "the post-swap capacity must equal the independent derivation"
        );

        _assertAdmissionRejectedForBacking(uint128(capacityBefore), capacityAfter, capacityBefore);

        uint256 commitmentId = _establish(uint128(capacityAfter));

        assertEq(hook.aggregateObligation(), capacityAfter, "the post-swap capacity must be exactly admissible");
        assertEq(hook.commitment(commitmentId).remainingEntitlement, uint128(capacityAfter), "the admitted extent");
    }

    /*//////////////////////////////////////////////////////////////
                     G7.10 — EXACT BACKING BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an entitlement strictly below capacity is admitted.
    function test_admission_belowCapacity_isPermitted() public {
        uint256 capacity = hook.supportingCapacity();

        _establish(uint128(capacity - 1));

        assertEq(hook.aggregateObligation(), capacity - 1, "the obligation must be established");
    }

    /// @notice Proves an entitlement exactly equal to capacity is admitted.
    /// @dev Exact sufficiency satisfies backing. Refusing `S == O'` would reject a state the frozen
    ///      semantics explicitly permit, and would quietly make the protocol's guarantee weaker than the
    ///      one it claims.
    function test_admission_exactlyAtCapacity_isPermitted() public {
        uint256 capacity = hook.supportingCapacity();

        _establish(uint128(capacity));

        assertEq(hook.aggregateObligation(), capacity, "the obligation must exactly equal capacity");
        assertEq(hook.supportingCapacity(), capacity, "capacity must be unchanged by admission");
    }

    /// @notice Proves an entitlement one unit above capacity is refused, leaving nothing behind.
    function test_admission_oneUnitAboveCapacity_isRejected() public {
        uint256 capacity = hook.supportingCapacity();

        _assertAdmissionRejectedForBacking(uint128(capacity + 1), capacity, capacity + 1);
    }

    /// @notice Proves the boundary is the aggregate, not the individual commitment.
    /// @dev The refused second commitment would be admissible on its own several times over. What refuses
    ///      it is the obligation the first one already imposes, which is exactly what shared backing means.
    function test_admission_boundaryAppliesToTheAggregate() public {
        uint256 capacity = hook.supportingCapacity();

        _establish(uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q));

        uint256 headroom = capacity - StandbyFixtureConfig.CANONICAL_COMMITMENT_Q;

        _assertAdmissionRejectedForBacking(uint128(headroom + 1), capacity, capacity + 1);

        _establish(uint128(headroom));

        assertEq(hook.aggregateObligation(), capacity, "the aggregate must reach exactly the capacity");
    }

    /*//////////////////////////////////////////////////////////////
                   G7.11 — EMPTY REFERENCE INSERTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves admission inserts the new identity into an empty slot and makes it visible to F5.
    /// @dev The reference is not bookkeeping the tests take on faith: the aggregate derivation scans the
    ///      bounded index, so a commitment that was recorded but never referenced would contribute
    ///      nothing, and this obligation would be zero.
    function test_admission_insertsIntoAnEmptyReferenceSlotAndBecomesVisibleToTheAggregate() public {
        uint256 firstId = _establish(TINY_Q);
        uint256 secondId = _establish(TINY_Q);

        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        assertEq(references[0], firstId, "the first admission must take the lowest empty slot");
        assertEq(references[1], secondId, "the second admission must take the next empty slot");

        for (uint256 slot = 2; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(references[slot], 0, "admission must write exactly one slot");
        }

        assertEq(hook.aggregateObligation(), 2 * uint256(TINY_Q), "both references must be visible to the aggregate");
    }

    /*//////////////////////////////////////////////////////////////
                   G7.12 — RECLAIMABLE REFERENCE REUSE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a full index may reuse the reference of an authoritatively terminal commitment.
    /// @dev The displaced commitment is terminal because its validity ended, which is one of the two
    ///      irreversible causes; nothing expired it, and no transaction was sent to notice. Reuse costs it
    ///      its slot and nothing else: the record stays readable under its own identity, with its
    ///      unfulfilled remainder intact, and the new commitment receives a fresh identity rather than the
    ///      one that was released.
    function test_fullIndex_reusesAReclaimableReferenceWhilePreservingHistory() public {
        uint256 reclaimableId = _fillIndexWithOneShortLivedCommitment();

        StandbyHook.Commitment memory historyBefore = hook.commitment(reclaimableId);

        vm.warp(block.timestamp + SHORT_VALIDITY + 1);

        assertEq(hook.commitmentObligation(reclaimableId), 0, "the displaced commitment must be terminal");
        assertEq(
            hook.aggregateObligation(),
            uint256(TINY_Q) * (MAX_LIVE_COMMITMENTS - 1),
            "only the still-binding commitments may contribute"
        );

        (, uint256 reclaimedSlot) = _referenceSlotOf(reclaimableId);

        uint256 newId = _establish(TINY_Q);

        assertEq(newId, MAX_LIVE_COMMITMENTS + 1, "the new commitment must receive a fresh identity");
        assertTrue(newId != reclaimableId, "identities are never recycled");

        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        assertEq(references[reclaimedSlot], newId, "the reclaimed slot must now reference the new commitment");
        assertEq(_occupiedReferenceCount(), MAX_LIVE_COMMITMENTS, "the index must remain full");

        (bool stillReferenced,) = _referenceSlotOf(reclaimableId);

        assertFalse(stillReferenced, "the displaced identity must no longer be referenced");

        StandbyHook.Commitment memory historyAfter = hook.commitment(reclaimableId);

        assertEq(historyAfter.beneficiary, historyBefore.beneficiary, "history must survive slot reuse");
        assertEq(historyAfter.exerciseAuthority, historyBefore.exerciseAuthority, "history must survive slot reuse");
        assertEq(
            uint256(historyAfter.originalEntitlement),
            uint256(historyBefore.originalEntitlement),
            "history must survive slot reuse"
        );
        assertEq(
            uint256(historyAfter.remainingEntitlement),
            uint256(historyBefore.remainingEntitlement),
            "a released remainder is not rewritten as fulfilled"
        );
        assertEq(uint256(historyAfter.validUntil), uint256(historyBefore.validUntil), "history must survive slot reuse");

        assertEq(
            hook.aggregateObligation(),
            uint256(TINY_Q) * MAX_LIVE_COMMITMENTS,
            "the aggregate must count the new commitment and not the displaced one"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    G7.13 — FULL BOUNDED-SET REJECTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a full index of still-binding commitments refuses admission on bounded capacity.
    /// @dev The refusal must be attributable to the realization's bounded reference set and to nothing
    ///      economic: the test asserts that backing would have been sufficient several thousand times
    ///      over, and that the reason given is the bounded-capacity one rather than the backing one.
    function test_fullIndexOfBindingCommitments_isRejectedOnBoundedCapacity() public {
        _fillIndexWithBindingCommitments();

        uint256 capacity = hook.supportingCapacity();
        uint256 obligation = hook.aggregateObligation();

        assertEq(obligation, uint256(TINY_Q) * MAX_LIVE_COMMITMENTS, "every reference must still be binding");
        assertGt(capacity, obligation + uint256(TINY_Q), "backing must be amply sufficient for one more");

        AdmissionState memory before = _admissionState();

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        vm.expectRevert(StandbyHook.StandbyHook__EnforcementReferenceCapacityExhausted.selector);
        vm.prank(establishmentAuthority);
        hook.establishCommitment(beneficiary, commitmentExerciseAuthority, TINY_Q, exercisableFrom, validUntil);

        _assertNoAdmissionResidue(before, "bounded-capacity rejection must leave no residue");
    }

    /// @notice Proves bounded exhaustion is checked independently of the backing comparison.
    /// @dev With the index full and the proposal also unbacked, the bounded-capacity reason is the one
    ///      reported. The two conditions are separate requirements, and a realization limit must never be
    ///      dressed up as an economic verdict about the proposal.
    function test_boundedExhaustion_isDistinctFromInsufficientBacking() public {
        _fillIndexWithBindingCommitments();

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        uint128 unbackedEntitlement = uint128(hook.supportingCapacity() + 1);

        vm.expectRevert(StandbyHook.StandbyHook__EnforcementReferenceCapacityExhausted.selector);
        vm.prank(establishmentAuthority);
        hook.establishCommitment(
            beneficiary, commitmentExerciseAuthority, unbackedEntitlement, exercisableFrom, validUntil
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Admits one long-lived commitment into every slot of the bounded index.
    function _fillIndexWithBindingCommitments() internal {
        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            _establish(TINY_Q);
        }

        assertEq(_occupiedReferenceCount(), MAX_LIVE_COMMITMENTS, "the index must be full");
    }

    /// @dev Fills the bounded index, giving exactly one commitment a short validity window.
    ///
    ///      The short-lived commitment is placed in the middle of the index rather than first or last, so
    ///      reclamation cannot appear to work because of a boundary slot.
    function _fillIndexWithOneShortLivedCommitment() internal returns (uint256 shortLivedId) {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        uint64 shortValidUntil = uint64(block.timestamp) + SHORT_VALIDITY;

        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            if (i == 7) {
                shortLivedId = _establishWithWindow(TINY_Q, exercisableFrom, shortValidUntil);
            } else {
                _establishWithWindow(TINY_Q, exercisableFrom, validUntil);
            }
        }

        assertEq(_occupiedReferenceCount(), MAX_LIVE_COMMITMENTS, "the index must be full");
    }

    /// @dev Asserts an admission is refused for insufficient backing with the exact derived quantities.
    function _assertAdmissionRejectedForBacking(
        uint128 _originalEntitlement,
        uint256 _expectedCapacity,
        uint256 _expectedProspectiveObligation
    ) internal {
        AdmissionState memory before = _admissionState();

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientAdmissionBacking.selector,
                _expectedCapacity,
                _expectedProspectiveObligation
            )
        );
        vm.prank(establishmentAuthority);
        hook.establishCommitment(
            beneficiary, commitmentExerciseAuthority, _originalEntitlement, exercisableFrom, validUntil
        );

        _assertNoAdmissionResidue(before, "an unbacked admission must leave no residue");
    }

    /// @dev Proves admission moved no pool state and took custody of no protected output.
    function _assertNoPoolOrCustodyEffect(AdmissionState memory _before) internal view {
        (uint160 sqrtPriceX96, int24 tick, uint128 liquidity) = _servicePoolState();

        assertEq(sqrtPriceX96, _before.sqrtPriceX96, "admission must not move the price");
        assertEq(tick, _before.tick, "admission must not move the tick");
        assertEq(liquidity, _before.liquidity, "admission must not change active liquidity");

        assertEq(
            usdc.balanceOf(beneficiary), _before.beneficiaryOutput, "no protected output may reach the Beneficiary"
        );
        assertEq(usdc.balanceOf(address(hook)), _before.hookOutput, "the Hook may take no protected-output custody");
        assertEq(
            usdc.balanceOf(exerciseRouter),
            _before.exerciseRouterOutput,
            "the ExerciseRouter may take no protected-output custody"
        );

        assertEq(usdc.balanceOf(address(hook)), 0, "the Hook must hold no protected output at all");
        assertEq(usdc.balanceOf(exerciseRouter), 0, "the ExerciseRouter must hold no protected output at all");

        assertEq(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.INITIAL_TICK),
            "the canonical price must be untouched"
        );
    }
}
