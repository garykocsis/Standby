// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";

import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseCommitmentStorageTest} from "../shared/BaseCommitmentStorageTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Isolated G4 evidence for permanent commitment identity, commitment fact fidelity, bounded
///         enforcement-reference integrity, and F4 slice isolation.
/// @dev The storage mechanics under test are internal, because F4 deliberately introduces no production
///      path that creates a commitment. They are driven through `StandbyHookHarness`, which supplies
///      authority and nothing else: every allocation, write, and predicate executed here is the
///      production implementation running against production storage.
///
///      Nothing recorded by these tests is an authentic Standby commitment. The records carry arbitrary
///      facts, no admission validated them, no backing supports them, and they are evidence about the
///      storage primitive alone. The slice-isolation tests at the end are run against the real production
///      Hook, with no harness involved, precisely because their claim is about the production surface.
contract CommitmentStorageTest is BaseCommitmentStorageTest {
    /*//////////////////////////////////////////////////////////////
                     G4-A — IDENTITY INTEGRITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves identity allocation starts at 1, so `0` is permanently the nonexistent sentinel.
    function test_commitmentIdentity_startsAtOneAndReservesZero() public {
        assertEq(harness.nextCommitmentId(), 1, "allocation must start at 1");
        assertEq(hook.nextCommitmentId(), 1, "the production Hook allocates nothing at F4");

        assertFalse(harness.commitmentExists(0), "the sentinel identity must never exist");

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(0)));
        harness.commitment(0);
    }

    /// @notice Proves allocated identities are nonzero, unique, and strictly increasing.
    function test_recordCommitment_allocatesNonzeroUniqueIncreasingIdentities() public {
        uint256 previousId;

        for (uint256 seed = 0; seed < 8; ++seed) {
            uint256 commitmentId = harness.recordCommitment(_commitmentFor(seed));

            assertTrue(commitmentId != 0, "an allocated identity is never the sentinel");
            assertTrue(commitmentId > previousId, "identities must strictly increase");
            assertEq(harness.nextCommitmentId(), commitmentId + 1, "the counter must advance by exactly one");
            assertTrue(harness.commitmentExists(commitmentId), "the allocated identity must exist");

            previousId = commitmentId;
        }
    }

    /// @notice Proves an identity beyond the allocated range does not exist.
    function test_commitment_rejectsAnIdentityThatWasNeverAllocated() public {
        harness.recordCommitment(_commitmentFor(1));

        uint256 unallocatedId = harness.nextCommitmentId();

        assertFalse(harness.commitmentExists(unallocatedId), "an unallocated identity must not exist");

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, unallocatedId));
        harness.commitment(unallocatedId);
    }

    /// @notice Proves reference-slot reuse never recycles an identity and never rewrites history.
    /// @dev The bounded index is filled, then every slot is taken over by a newer commitment. If slot
    ///      membership were the thing that owned identity, the displaced commitments would have lost
    ///      theirs. Instead every displaced identity still exists, still reads back exactly as recorded,
    ///      and no later allocation ever reuses one.
    function test_enforcementReferenceReuse_neitherRecyclesIdentityNorErasesHistory() public {
        uint256[] memory firstGeneration = new uint256[](MAX_LIVE_COMMITMENTS);

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            firstGeneration[slot] = harness.recordCommitment(_commitmentFor(slot));
            harness.writeEnforcementReference(slot, firstGeneration[slot]);
        }

        uint256[] memory secondGeneration = new uint256[](MAX_LIVE_COMMITMENTS);

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            secondGeneration[slot] = harness.recordCommitment(_commitmentFor(MAX_LIVE_COMMITMENTS + slot));

            assertTrue(secondGeneration[slot] > firstGeneration[MAX_LIVE_COMMITMENTS - 1], "identities never rewind");

            harness.writeEnforcementReference(slot, secondGeneration[slot]);
        }

        assertEq(harness.nextCommitmentId(), 2 * MAX_LIVE_COMMITMENTS + 1, "every identity was consumed exactly once");

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(references[slot], secondGeneration[slot], "the slot must hold the replacing identity");

            assertTrue(harness.commitmentExists(firstGeneration[slot]), "the displaced identity still exists");
            _assertCommitmentEquals(
                harness.commitment(firstGeneration[slot]),
                _commitmentFor(slot),
                "a displaced historical record must be unchanged"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                   G4-B — COMMITMENT FACT FIDELITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves every commitment fact round-trips exactly through the storage mechanic.
    function test_recordCommitment_preservesEveryFactExactly() public {
        StandbyHook.Commitment memory expected = _commitmentFor(42);

        uint256 commitmentId = harness.recordCommitment(expected);

        _assertCommitmentEquals(harness.commitment(commitmentId), expected, "the record must round-trip exactly");
    }

    /// @notice Proves records are independent: writing one never disturbs another.
    function test_recordCommitment_keepsHistoricalRecordsIndependent() public {
        uint256 firstId = harness.recordCommitment(_commitmentFor(1));
        uint256 secondId = harness.recordCommitment(_commitmentFor(2));

        _assertCommitmentEquals(harness.commitment(firstId), _commitmentFor(1), "the first record is its own");
        _assertCommitmentEquals(harness.commitment(secondId), _commitmentFor(2), "the second record is its own");
    }

    /// @notice Proves the Remaining Entitlement mechanic changes that fact and no other.
    /// @dev Admission-fixed facts are what a later slice must be able to trust; a storage mechanic that
    ///      silently rewrote one of them would let fulfillment reinterpret the admitted relationship.
    function test_writeRemainingEntitlement_changesOnlyRemainingEntitlement() public {
        StandbyHook.Commitment memory admitted = _commitmentFor(7);

        uint256 commitmentId = harness.recordCommitment(admitted);

        harness.writeRemainingEntitlement(commitmentId, 123);

        StandbyHook.Commitment memory stored = harness.commitment(commitmentId);

        assertEq(uint256(stored.remainingEntitlement), 123, "Remaining Entitlement must be written");

        assertEq(PoolId.unwrap(stored.serviceId), PoolId.unwrap(admitted.serviceId), "serviceId is admission-fixed");
        assertEq(stored.beneficiary, admitted.beneficiary, "beneficiary is admission-fixed");
        assertEq(stored.exerciseAuthority, admitted.exerciseAuthority, "exercise authority is admission-fixed");
        assertEq(uint256(stored.exercisableFrom), uint256(admitted.exercisableFrom), "exercisableFrom is fixed");
        assertEq(uint256(stored.validUntil), uint256(admitted.validUntil), "validUntil is admission-fixed");
        assertEq(
            uint256(stored.originalEntitlement),
            uint256(admitted.originalEntitlement),
            "the admitted extent is never rewritten to represent later fulfillment"
        );
    }

    /// @notice Proves Remaining Entitlement cannot be written for an identity that was never allocated.
    function test_writeRemainingEntitlement_rejectsAnIdentityThatWasNeverAllocated() public {
        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(1)));
        harness.writeRemainingEntitlement(1, 1);

        assertEq(harness.nextCommitmentId(), 1, "a rejected write allocates nothing");
    }

    /// @notice Proves expiry does not implicitly zero Remaining Entitlement.
    /// @dev Expiry changes what the facts mean. It is not a storage event, and no mechanic exists that
    ///      could make it one: a commitment far past `validUntil` still holds exactly the Remaining
    ///      Entitlement it was recorded with. Whether that entitlement still imposes an obligation is a
    ///      question for the derivation slice, asked of these unchanged facts.
    function test_expiry_doesNotAlterStoredRemainingEntitlement() public {
        StandbyHook.Commitment memory record = _commitmentFor(11);
        record.exercisableFrom = uint64(block.timestamp);
        record.validUntil = uint64(block.timestamp + 1 days);
        record.originalEntitlement = 1_000e6;
        record.remainingEntitlement = 400e6;

        uint256 commitmentId = harness.recordCommitment(record);

        vm.warp(uint256(record.validUntil) + 365 days);

        _assertCommitmentEquals(harness.commitment(commitmentId), record, "expiry must not touch stored facts");
    }

    /// @notice Proves Beneficiary eligibility changes do not alter stored commitment facts.
    /// @dev Eligibility is externally mutable and lives in a contract that knows nothing about
    ///      commitments. Revoking it must leave the record exactly as recorded.
    function test_eligibilityChange_doesNotAlterStoredCommitmentFacts() public {
        StandbyHook.Commitment memory record = _commitmentFor(13);
        record.beneficiary = makeAddr("beneficiary");

        uint256 commitmentId = harness.recordCommitment(record);

        vm.prank(registryAdmin);
        registry.setBeneficiaryEligibility(record.beneficiary, true);

        _assertCommitmentEquals(harness.commitment(commitmentId), record, "granting eligibility changes no fact");

        vm.prank(registryAdmin);
        registry.setBeneficiaryEligibility(record.beneficiary, false);

        _assertCommitmentEquals(harness.commitment(commitmentId), record, "revoking eligibility changes no fact");
    }

    /// @notice Proves reference writes never rewrite the commitment facts they point at.
    /// @dev Covers all three ways a slot can move: taking an empty slot, being displaced from an occupied
    ///      one, and never being referenced at all. None of them touches a stored fact.
    function test_enforcementReferenceWrite_doesNotRewriteCommitmentFacts() public {
        uint256 displacedId = harness.recordCommitment(_commitmentFor(21));
        uint256 replacingId = harness.recordCommitment(_commitmentFor(22));
        uint256 unreferencedId = harness.recordCommitment(_commitmentFor(23));

        harness.writeEnforcementReference(0, displacedId);
        harness.writeEnforcementReference(0, replacingId);

        assertEq(harness.enforcementReferences()[0], replacingId, "the slot must hold the replacing identity");

        _assertCommitmentEquals(harness.commitment(displacedId), _commitmentFor(21), "displacement rewrites nothing");
        _assertCommitmentEquals(harness.commitment(replacingId), _commitmentFor(22), "referencing rewrites nothing");
        _assertCommitmentEquals(
            harness.commitment(unreferencedId), _commitmentFor(23), "an unreferenced record is untouched"
        );
    }

    /*//////////////////////////////////////////////////////////////
                  G4-C — BOUNDED REFERENCE INTEGRITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the index has exactly `MAX_LIVE_COMMITMENTS` slots and starts entirely empty.
    function test_enforcementReferences_areSixteenAndStartEmpty() public view {
        assertEq(hook.MAX_LIVE_COMMITMENTS(), 16, "the frozen bound is sixteen");

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        assertEq(references.length, 16, "the index must have exactly sixteen slots");

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(references[slot], 0, "every slot must start empty");
        }
    }

    /// @notice Proves a reference write occupies exactly the addressed slot and leaves the rest empty.
    function test_writeEnforcementReference_occupiesExactlyTheAddressedSlot() public {
        uint256 commitmentId = harness.recordCommitment(_commitmentFor(1));

        harness.writeEnforcementReference(5, commitmentId);

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(references[slot], slot == 5 ? commitmentId : 0, "only the addressed slot may change");
        }
    }

    /// @notice Proves all sixteen slots are usable and that no seventeenth reference can exist.
    function test_writeEnforcementReference_fillsSixteenSlotsAndNoMore() public {
        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            harness.writeEnforcementReference(slot, harness.recordCommitment(_commitmentFor(slot)));
        }

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertTrue(references[slot] != 0, "every slot must be occupied");
        }

        uint256 seventeenthId = harness.recordCommitment(_commitmentFor(999));

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidEnforcementReferenceSlot.selector, MAX_LIVE_COMMITMENTS
            )
        );
        harness.writeEnforcementReference(MAX_LIVE_COMMITMENTS, seventeenthId);
    }

    /// @notice Proves a slot outside the bound is rejected.
    function test_writeEnforcementReference_rejectsASlotOutsideTheBound() public {
        uint256 commitmentId = harness.recordCommitment(_commitmentFor(1));

        vm.expectRevert(
            abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidEnforcementReferenceSlot.selector, type(uint256).max)
        );
        harness.writeEnforcementReference(type(uint256).max, commitmentId);
    }

    /// @notice Proves every nonzero reference must resolve to an existing historical commitment.
    function test_writeEnforcementReference_rejectsAnIdentityThatWasNeverAllocated() public {
        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(0)));
        harness.writeEnforcementReference(0, 0);

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(1)));
        harness.writeEnforcementReference(0, 1);

        assertEq(harness.enforcementReferences()[0], 0, "a rejected write must leave the slot empty");
    }

    /// @notice Proves one commitment can never occupy two slots.
    function test_writeEnforcementReference_rejectsADuplicateReference() public {
        uint256 commitmentId = harness.recordCommitment(_commitmentFor(1));

        harness.writeEnforcementReference(2, commitmentId);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__DuplicateEnforcementReference.selector, commitmentId, uint256(2)
            )
        );
        harness.writeEnforcementReference(9, commitmentId);

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        assertEq(references[2], commitmentId, "the original reference is unchanged");
        assertEq(references[9], 0, "the duplicate slot stays empty");
    }

    /// @notice Proves rewriting a commitment into the slot it already occupies is not a duplicate.
    function test_writeEnforcementReference_acceptsRewritingASlotWithItsOwnCommitment() public {
        uint256 commitmentId = harness.recordCommitment(_commitmentFor(1));

        harness.writeEnforcementReference(4, commitmentId);
        harness.writeEnforcementReference(4, commitmentId);

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        assertEq(references[4], commitmentId, "the slot still holds the same commitment");

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            if (slot != 4) assertEq(references[slot], 0, "no other slot may be touched");
        }
    }

    /// @notice Proves reference membership carries no lifecycle or economic classification.
    /// @dev The index is indifferent to what the referenced facts say. A commitment that has expired and
    ///      has zero Remaining Entitlement — everything a later slice would call terminal — is referenced
    ///      exactly as readily as one with a large entitlement and a distant expiry, and a commitment with
    ///      a large entitlement can sit outside the index entirely. Membership therefore cannot be read as
    ///      evidence of validity, exercisability, obligation, or liveness in either direction.
    function test_enforcementReferences_carryNoEconomicClassification() public {
        StandbyHook.Commitment memory terminal = _commitmentFor(31);
        terminal.exercisableFrom = uint64(block.timestamp);
        terminal.validUntil = uint64(block.timestamp + 1);
        terminal.originalEntitlement = 500e6;
        terminal.remainingEntitlement = 0;

        StandbyHook.Commitment memory unreferencedButLarge = _commitmentFor(32);
        unreferencedButLarge.exercisableFrom = uint64(block.timestamp);
        unreferencedButLarge.validUntil = type(uint64).max;
        unreferencedButLarge.originalEntitlement = 1_000e6;
        unreferencedButLarge.remainingEntitlement = 1_000e6;

        uint256 terminalId = harness.recordCommitment(terminal);
        uint256 largeId = harness.recordCommitment(unreferencedButLarge);

        vm.warp(uint256(terminal.validUntil) + 1);

        harness.writeEnforcementReference(0, terminalId);

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        assertEq(references[0], terminalId, "an expired, exhausted commitment may be referenced");

        for (uint256 slot = 1; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertTrue(references[slot] != largeId, "a large live-looking commitment need not be referenced");
        }

        _assertCommitmentEquals(harness.commitment(largeId), unreferencedButLarge, "absence changes no fact");
    }

    /*//////////////////////////////////////////////////////////////
             G4-D / G4-E — MINIMALITY AND SLICE ISOLATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the production Hook exposes no commitment creation or mutation surface.
    /// @dev The Hook has no fallback, so a call to any absent selector reverts. This enumerates the
    ///      admission, fulfillment, and reference-mutation entry points that F7 and F8 will own, and shows
    ///      that none of them exists yet, leaving no path by which an arbitrary caller could manufacture
    ///      an economically authoritative commitment or obligation.
    function test_productionHook_exposesNoCommitmentCreationOrMutationSurface() public {
        string[] memory forbiddenSignatures = new string[](10);
        forbiddenSignatures[0] = "establishCommitment(address)";
        forbiddenSignatures[1] = "createCommitment(address)";
        forbiddenSignatures[2] = "recordCommitment(address)";
        forbiddenSignatures[3] = "admitCommitment(address)";
        forbiddenSignatures[4] = "exercise(address)";
        forbiddenSignatures[5] = "writeRemainingEntitlement(address)";
        forbiddenSignatures[6] = "setRemainingEntitlement(address)";
        forbiddenSignatures[7] = "reduceEntitlement(address)";
        forbiddenSignatures[8] = "writeEnforcementReference(address)";
        forbiddenSignatures[9] = "releaseCommitment(address)";

        for (uint256 i = 0; i < forbiddenSignatures.length; ++i) {
            (bool success,) = address(hook).call(abi.encodeWithSignature(forbiddenSignatures[i], address(1)));
            assertFalse(success, forbiddenSignatures[i]);
        }

        assertEq(hook.nextCommitmentId(), 1, "the production Hook must have allocated no identity");

        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(references[slot], 0, "the production index must be empty");
        }
    }

    /// @notice Proves the storage layer still exposes no commitment lifecycle projection.
    /// @dev The original F4 form of this test forbade every derived economic read, because at F4 no
    ///      derivation existed and any such read would have been a second production implementation of
    ///      economics that had no first one. F5 supplied the authoritative derivation kernel together with
    ///      the frozen minimum read surface — `supportingCapacity()`, `aggregateObligation()`, and
    ///      `commitmentObligation(id)` — so those three are now authorized production reads and are
    ///      verified by the derivation suites.
    ///
    ///      What remains forbidden is the convenience lifecycle API. A commitment has no status: validity,
    ///      exercisability, binding, reclaimability, and liveness are distinct derived properties over
    ///      distinct authoritative bases, and publishing them as a projection would invite exactly the
    ///      substitution — non-exercisable read as non-binding — that the state model forbids. Nothing
    ///      currently requires them, so nothing exposes them.
    function test_noCommitmentLifecycleProjectionIsExposed() public {
        string[] memory forbiddenSignatures = new string[](7);
        forbiddenSignatures[0] = "isValid(uint256)";
        forbiddenSignatures[1] = "isExercisable(uint256)";
        forbiddenSignatures[2] = "isBinding(uint256)";
        forbiddenSignatures[3] = "isReclaimable(uint256)";
        forbiddenSignatures[4] = "isLive(uint256)";
        forbiddenSignatures[5] = "status(uint256)";
        forbiddenSignatures[6] = "availableCapacity()";

        for (uint256 i = 0; i < forbiddenSignatures.length; ++i) {
            bytes memory callData = abi.encodeWithSignature(forbiddenSignatures[i], uint256(1));

            (bool hookSuccess,) = address(hook).call(callData);
            assertFalse(hookSuccess, forbiddenSignatures[i]);

            (bool harnessSuccess,) = address(harness).call(callData);
            assertFalse(harnessSuccess, forbiddenSignatures[i]);
        }
    }

    /// @notice Proves the four enabled callbacks still fail closed at the F4 frontier.
    /// @dev Called as the PoolManager, so the rejection is the missing enforcement behavior rather than
    ///      the caller check. F4 introduced commitment storage without introducing O3 enforcement, O1
    ///      admission, or O2 exercise, and the Hook must still not be attached to a live pool.
    function test_enabledCallbacks_remainFailClosedAtTheF4Frontier() public {
        PoolKey memory key;
        ModifyLiquidityParams memory liquidityParams;
        SwapParams memory swapParams;
        BalanceDelta delta = BalanceDeltaLibrary.ZERO_DELTA;

        vm.startPrank(address(poolManager));

        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.beforeAddLiquidity(address(this), key, liquidityParams, "");

        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.beforeRemoveLiquidity(address(this), key, liquidityParams, "");

        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.beforeSwap(address(this), key, swapParams, "");

        vm.expectRevert(BaseHook.HookNotImplemented.selector);
        hook.afterSwap(address(this), key, swapParams, delta, "");

        vm.stopPrank();
    }

    /// @notice Proves F4 commitment storage did not disturb the closed F3 configuration behavior.
    /// @dev The one-shot Protected Execution Service transition still works, still reads back exactly, and
    ///      still refuses a second activation. Commitment storage is independent of it in both directions:
    ///      records can be written before any service exists, and activation writes no commitment state.
    function test_f4Storage_preservesTheF3ConfigurationBoundary() public {
        harness.recordCommitment(_commitmentFor(1));

        PoolId activatedServiceId = _activateCanonicalService();

        assertEq(PoolId.unwrap(hook.serviceId()), PoolId.unwrap(activatedServiceId), "the service still activates");
        assertTrue(hook.protectedExecutionService().configured, "the service-existence fact is unchanged");
        assertEq(hook.nextCommitmentId(), 1, "activation must allocate no commitment identity");

        vm.expectRevert(StandbyHook.StandbyHook__ServiceAlreadyConfigured.selector);
        _activateCanonicalService();
    }
}
