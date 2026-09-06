// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {PoolId} from "v4-core/types/PoolId.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseCommitmentStorageTest} from "../shared/BaseCommitmentStorageTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Parameterized G4 evidence for commitment identity, fact fidelity, and bounded-reference
///         integrity across arbitrary commitment facts, allocation histories, and reference patterns.
/// @dev Commitment facts are left almost entirely unconstrained. F4 stores facts and interprets none of
///      them, so there is no semantic domain to respect: a commitment whose `validUntil` precedes its
///      `exercisableFrom`, or whose Remaining Entitlement exceeds its Original Entitlement, is nonsense
///      economically and still has to round-trip exactly, because rejecting it is admission's job and not
///      storage's. Bounds are applied only where the structure itself defines one, such as a slot index.
///
///      As in the unit evidence, everything is driven through `StandbyHookHarness`: production mechanics,
///      production storage, test-supplied authority, no authentic commitment anywhere.
contract CommitmentStorageFuzzTest is BaseCommitmentStorageTest {
    /*//////////////////////////////////////////////////////////////
                    IDENTITY AND FACT FIDELITY
    //////////////////////////////////////////////////////////////*/

    /// @dev Any commitment facts whatsoever round-trip exactly through allocation and storage.
    function testFuzz_recordCommitment_preservesArbitraryFactsExactly(
        bytes32 _serviceId,
        address _beneficiary,
        address _exerciseAuthority,
        uint128 _originalEntitlement,
        uint128 _remainingEntitlement,
        uint64 _exercisableFrom,
        uint64 _validUntil
    ) public {
        StandbyHook.Commitment memory record = StandbyHook.Commitment({
            serviceId: PoolId.wrap(_serviceId),
            beneficiary: _beneficiary,
            exercisableFrom: _exercisableFrom,
            exerciseAuthority: _exerciseAuthority,
            validUntil: _validUntil,
            originalEntitlement: _originalEntitlement,
            remainingEntitlement: _remainingEntitlement
        });

        uint256 commitmentId = harness.recordCommitment(record);

        assertTrue(commitmentId != 0, "an allocated identity is never the sentinel");

        _assertCommitmentEquals(harness.commitment(commitmentId), record, "arbitrary facts must round-trip");
    }

    /// @dev Any number of sequential allocations produces strictly increasing identities starting at 1,
    ///      every one of which remains readable and unchanged at the end of the history.
    function testFuzz_recordCommitment_allocatesAMonotonicNonRecycledHistory(uint8 _rawCount) public {
        uint256 count = bound(uint256(_rawCount), 1, 32);

        for (uint256 seed = 0; seed < count; ++seed) {
            uint256 commitmentId = harness.recordCommitment(_commitmentFor(seed));

            assertEq(commitmentId, seed + 1, "identities are allocated in strict sequence from one");
        }

        assertEq(harness.nextCommitmentId(), count + 1, "the counter reflects exactly the allocated history");

        for (uint256 seed = 0; seed < count; ++seed) {
            assertTrue(harness.commitmentExists(seed + 1), "every allocated identity exists");

            _assertCommitmentEquals(harness.commitment(seed + 1), _commitmentFor(seed), "history stays intact");
        }

        assertFalse(harness.commitmentExists(count + 1), "an unallocated identity does not exist");
    }

    /// @dev Any Remaining Entitlement value is writable, and writing it never disturbs an admission-fixed
    ///      fact. No economic rule is asserted here: the value is unconstrained precisely because F4 does
    ///      not own the rule that will later constrain it.
    function testFuzz_writeRemainingEntitlement_neverDisturbsAdmissionFixedFacts(
        uint256 _seed,
        uint128 _remainingEntitlement
    ) public {
        StandbyHook.Commitment memory admitted = _commitmentFor(_seed);

        uint256 commitmentId = harness.recordCommitment(admitted);

        harness.writeRemainingEntitlement(commitmentId, _remainingEntitlement);

        StandbyHook.Commitment memory expected = admitted;
        expected.remainingEntitlement = _remainingEntitlement;

        _assertCommitmentEquals(harness.commitment(commitmentId), expected, "only Remaining Entitlement may change");
    }

    /// @dev The passage of time past any expiry never alters a stored fact, so Remaining Entitlement is
    ///      never implicitly zeroed by expiry and never reconstructed from the clock.
    function testFuzz_timePassing_neverAltersStoredFacts(uint256 _seed, uint64 _validUntil, uint64 _futureTimestamp)
        public
    {
        vm.assume(_futureTimestamp >= block.timestamp);

        StandbyHook.Commitment memory record = _commitmentFor(_seed);
        record.validUntil = _validUntil;

        uint256 commitmentId = harness.recordCommitment(record);

        vm.warp(_futureTimestamp);

        _assertCommitmentEquals(harness.commitment(commitmentId), record, "time changes no stored fact");
    }

    /// @dev No identity outside the allocated range can be read, referenced, or written.
    function testFuzz_unallocatedIdentity_isUniformlyRejected(uint8 _rawCount, uint256 _identity) public {
        uint256 count = bound(uint256(_rawCount), 0, 8);

        for (uint256 seed = 0; seed < count; ++seed) {
            harness.recordCommitment(_commitmentFor(seed));
        }

        vm.assume(_identity == 0 || _identity > count);

        assertFalse(harness.commitmentExists(_identity), "an unallocated identity does not exist");

        bytes memory expectedRevert =
            abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, _identity);

        vm.expectRevert(expectedRevert);
        harness.commitment(_identity);

        vm.expectRevert(expectedRevert);
        harness.writeRemainingEntitlement(_identity, 1);

        vm.expectRevert(expectedRevert);
        harness.writeEnforcementReference(0, _identity);
    }

    /*//////////////////////////////////////////////////////////////
                  BOUNDED REFERENCE INTEGRITY
    //////////////////////////////////////////////////////////////*/

    /// @dev A reference write occupies the addressed slot and only the addressed slot, wherever it is.
    function testFuzz_writeEnforcementReference_occupiesOnlyTheAddressedSlot(uint8 _rawSlot, uint256 _seed) public {
        uint256 slot = bound(uint256(_rawSlot), 0, MAX_LIVE_COMMITMENTS - 1);

        uint256 commitmentId = harness.recordCommitment(_commitmentFor(_seed));

        harness.writeEnforcementReference(slot, commitmentId);

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            assertEq(references[i], i == slot ? commitmentId : 0, "only the addressed slot may change");
        }
    }

    /// @dev Every slot index outside the bound is rejected and changes nothing.
    function testFuzz_writeEnforcementReference_rejectsAnySlotOutsideTheBound(uint256 _slot, uint256 _seed) public {
        vm.assume(_slot >= MAX_LIVE_COMMITMENTS);

        uint256 commitmentId = harness.recordCommitment(_commitmentFor(_seed));

        vm.expectRevert(
            abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidEnforcementReferenceSlot.selector, _slot)
        );
        harness.writeEnforcementReference(_slot, commitmentId);

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            assertEq(references[i], 0, "a rejected write leaves the index empty");
        }
    }

    /// @dev One commitment can never occupy two slots, whichever pair of distinct slots is tried.
    function testFuzz_writeEnforcementReference_rejectsAnyDuplicate(uint8 _rawFirstSlot, uint8 _rawSecondSlot) public {
        uint256 firstSlot = bound(uint256(_rawFirstSlot), 0, MAX_LIVE_COMMITMENTS - 1);
        uint256 secondSlot = bound(uint256(_rawSecondSlot), 0, MAX_LIVE_COMMITMENTS - 1);

        vm.assume(firstSlot != secondSlot);

        uint256 commitmentId = harness.recordCommitment(_commitmentFor(1));

        harness.writeEnforcementReference(firstSlot, commitmentId);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__DuplicateEnforcementReference.selector, commitmentId, firstSlot
            )
        );
        harness.writeEnforcementReference(secondSlot, commitmentId);

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        assertEq(references[firstSlot], commitmentId, "the original reference is unchanged");
        assertEq(references[secondSlot], 0, "the duplicate slot stays empty");
    }

    /// @dev Under an arbitrary sequence of writes across arbitrary slots, the index invariants hold: at
    ///      most sixteen references exist, every nonzero reference resolves to an existing historical
    ///      commitment, no identity appears twice, and every commitment ever recorded — including every
    ///      one displaced from a slot — is still readable exactly as recorded.
    function testFuzz_repeatedSlotReuse_preservesIndexIntegrityAndHistory(uint8 _rawWrites, uint256 _slotEntropy)
        public
    {
        uint256 writes = bound(uint256(_rawWrites), 1, 48);

        for (uint256 i = 0; i < writes; ++i) {
            uint256 slot = uint256(keccak256(abi.encode(_slotEntropy, i))) % MAX_LIVE_COMMITMENTS;

            harness.writeEnforcementReference(slot, harness.recordCommitment(_commitmentFor(i)));
        }

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        uint256 occupiedCount;

        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            if (references[i] == 0) continue;

            ++occupiedCount;

            assertTrue(harness.commitmentExists(references[i]), "every reference resolves to a real commitment");

            for (uint256 j = i + 1; j < MAX_LIVE_COMMITMENTS; ++j) {
                assertTrue(references[i] != references[j], "no identity may occupy two slots");
            }
        }

        assertTrue(occupiedCount <= MAX_LIVE_COMMITMENTS, "occupancy can never exceed the bound");

        assertEq(harness.nextCommitmentId(), writes + 1, "slot reuse never reuses an identity");

        for (uint256 i = 0; i < writes; ++i) {
            _assertCommitmentEquals(harness.commitment(i + 1), _commitmentFor(i), "history survives slot reuse");
        }
    }
}
