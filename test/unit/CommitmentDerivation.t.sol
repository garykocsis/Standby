// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {PoolId} from "v4-core/types/PoolId.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {StandbyMath} from "../../src/libraries/StandbyMath.sol";

import {BaseCommitmentStorageTest} from "../shared/BaseCommitmentStorageTest.t.sol";
import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Unit evidence for the F5 per-commitment derivations (G5-A).
/// @dev The pure predicates are exercised directly, because they are pure and a harness would add
///      nothing. The per-commitment obligation is additionally exercised through the Hook's production
///      read against real persisted records, so the composition and the arithmetic are both covered.
///
///      The commitments recorded here are arbitrary test facts. Nothing authenticated them, nothing
///      admitted them, and nothing established that they are backed; they are valid evidence about the
///      derivation and about nothing else.
///
///      The distinction this file exists to protect is that binding is not exercisability. A commitment
///      whose window has not opened, whose Beneficiary has lost eligibility, or whose exercise authority
///      is nowhere near the transaction still imposes its full Remaining Entitlement. Only exhaustion and
///      expiry release it, and both are permanent.
contract CommitmentDerivationTest is BaseCommitmentStorageTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint64 internal constant EXERCISABLE_FROM = 2_000;
    uint64 internal constant VALID_UNTIL = 3_000;
    uint128 internal constant ENTITLEMENT = 50_000_000_000;

    address internal beneficiary;
    address internal exerciseAuthority;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds the two commitment participants to the shared commitment-storage environment.
    function setUp() public virtual override {
        super.setUp();

        beneficiary = makeAddr("beneficiary");
        exerciseAuthority = makeAddr("exerciseAuthority");
    }

    /*//////////////////////////////////////////////////////////////
                          TEMPORAL VALIDITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves validity ends exactly at `validUntil`, not one second later.
    /// @dev The frozen comparison is strict. An inclusive comparison would keep an expired entitlement
    ///      imposing obligation for one further second, and would make the expiry boundary ambiguous.
    function test_validity_endsExactlyAtValidUntil() public pure {
        assertTrue(StandbyMath.isValid(VALID_UNTIL, VALID_UNTIL - 1), "one second before expiry is still valid");
        assertFalse(StandbyMath.isValid(VALID_UNTIL, VALID_UNTIL), "validity is already false at validUntil");
        assertFalse(StandbyMath.isValid(VALID_UNTIL, VALID_UNTIL + 1), "validity stays false after expiry");
    }

    /// @notice Proves validity ignores the exercise window entirely.
    /// @dev A commitment before `exercisableFrom` is valid. Validity and exercisability are distinct
    ///      properties over distinct bases, and one may never stand in for the other.
    function test_validity_doesNotDependOnTheExerciseWindow() public pure {
        assertTrue(StandbyMath.isValid(VALID_UNTIL, EXERCISABLE_FROM - 1), "a future commitment is already valid");
    }

    /*//////////////////////////////////////////////////////////////
                    TEMPORAL EXERCISE QUALIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the exercise window opens inclusively and closes exclusively.
    function test_temporalQualification_opensAtExercisableFromAndClosesAtValidUntil() public pure {
        assertFalse(
            StandbyMath.isTemporallyExerciseQualified(EXERCISABLE_FROM, VALID_UNTIL, EXERCISABLE_FROM - 1),
            "the window has not opened one second early"
        );
        assertTrue(
            StandbyMath.isTemporallyExerciseQualified(EXERCISABLE_FROM, VALID_UNTIL, EXERCISABLE_FROM),
            "the window opens exactly at exercisableFrom"
        );
        assertTrue(
            StandbyMath.isTemporallyExerciseQualified(EXERCISABLE_FROM, VALID_UNTIL, VALID_UNTIL - 1),
            "the window is still open one second before expiry"
        );
        assertFalse(
            StandbyMath.isTemporallyExerciseQualified(EXERCISABLE_FROM, VALID_UNTIL, VALID_UNTIL),
            "the window is closed exactly at validUntil"
        );
    }

    /// @notice Proves temporal qualification is only the temporal condition.
    /// @dev It knows nothing about Remaining Entitlement, so an exhausted commitment inside its window is
    ///      still temporally qualified. Whether it may actually be exercised is the exercise slice's
    ///      question, composed from several conditions of which this is one.
    function test_temporalQualification_isIndependentOfRemainingEntitlement() public pure {
        assertTrue(
            StandbyMath.isTemporallyExerciseQualified(EXERCISABLE_FROM, VALID_UNTIL, EXERCISABLE_FROM + 1),
            "temporal qualification does not consult entitlement"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     PERMANENT NON-BINDING RELEASE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the two irreversible release causes, and only those two.
    function test_permanentNonBinding_holdsExactlyOnExhaustionOrExpiry() public pure {
        assertTrue(
            StandbyMath.isPermanentlyNonBinding(0, VALID_UNTIL, EXERCISABLE_FROM),
            "an exhausted commitment is permanently released"
        );
        assertTrue(
            StandbyMath.isPermanentlyNonBinding(ENTITLEMENT, VALID_UNTIL, VALID_UNTIL),
            "an expired commitment is permanently released"
        );
        assertFalse(
            StandbyMath.isPermanentlyNonBinding(ENTITLEMENT, VALID_UNTIL, EXERCISABLE_FROM - 1),
            "a future commitment with entitlement is not released"
        );
        assertFalse(
            StandbyMath.isPermanentlyNonBinding(ENTITLEMENT, VALID_UNTIL, VALID_UNTIL - 1),
            "an open commitment with entitlement is not released"
        );
    }

    /// @notice Proves an expired commitment stays released for every later time.
    /// @dev Release is irreversible, which is what makes it a sound basis for reclaiming a bounded
    ///      enforcement-reference slot. A condition that could revert would not be.
    function test_permanentNonBinding_isIrreversibleOnceExpired() public pure {
        assertTrue(
            StandbyMath.isPermanentlyNonBinding(ENTITLEMENT, VALID_UNTIL, VALID_UNTIL),
            "release begins at the expiry instant"
        );
        assertTrue(
            StandbyMath.isPermanentlyNonBinding(ENTITLEMENT, VALID_UNTIL, type(uint64).max),
            "release persists arbitrarily far into the future"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        CAPACITY OBLIGATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the complete frozen temporal / entitlement obligation matrix.
    /// @dev Each row states the whole derived answer, so an implementation that got obligation right by
    ///      accident while classifying the commitment wrongly would still fail here.
    function test_commitmentObligation_matchesTheFrozenTemporalMatrix() public pure {
        _assertDerivation(ENTITLEMENT, EXERCISABLE_FROM - 1, true, false, false, ENTITLEMENT);
        _assertDerivation(ENTITLEMENT, EXERCISABLE_FROM, true, true, false, ENTITLEMENT);
        _assertDerivation(ENTITLEMENT, EXERCISABLE_FROM + 1, true, true, false, ENTITLEMENT);
        _assertDerivation(ENTITLEMENT, VALID_UNTIL - 1, true, true, false, ENTITLEMENT);
        _assertDerivation(ENTITLEMENT, VALID_UNTIL, false, false, true, 0);
        _assertDerivation(ENTITLEMENT, VALID_UNTIL + 1, false, false, true, 0);

        _assertDerivation(0, EXERCISABLE_FROM - 1, true, false, true, 0);
        _assertDerivation(0, EXERCISABLE_FROM + 1, true, true, true, 0);
        _assertDerivation(0, VALID_UNTIL, false, false, true, 0);
    }

    /// @notice Proves a commitment imposes obligation before its exercise window opens.
    /// @dev This is the case that separates binding from exercisability. Backing must already be there
    ///      when the window opens, so obligation cannot wait for it.
    function test_commitmentObligation_bindsBeforeTheExerciseWindowOpens() public {
        uint256 commitmentId = _recordCommitment(ENTITLEMENT);

        vm.warp(EXERCISABLE_FROM - 1);

        assertFalse(
            StandbyMath.isTemporallyExerciseQualified(EXERCISABLE_FROM, VALID_UNTIL, block.timestamp),
            "the commitment must not yet be temporally qualified"
        );
        assertEq(
            harness.commitmentObligation(commitmentId), ENTITLEMENT, "a future commitment imposes its full remainder"
        );
    }

    /// @notice Proves expiry zeroes obligation without touching Remaining Entitlement.
    /// @dev The unfulfilled remainder stays visible as history. Expiry changes what the fact means, never
    ///      the fact, and no expiry transaction is needed for the meaning to change.
    function test_commitmentObligation_expiresWithoutRewritingRemainingEntitlement() public {
        uint256 commitmentId = _recordCommitment(ENTITLEMENT);

        vm.warp(VALID_UNTIL);

        assertEq(harness.commitmentObligation(commitmentId), 0, "an expired commitment imposes nothing");
        assertEq(
            uint256(harness.commitment(commitmentId).remainingEntitlement),
            uint256(ENTITLEMENT),
            "the historical remainder must survive expiry unchanged"
        );
        assertEq(
            uint256(harness.commitment(commitmentId).originalEntitlement),
            uint256(ENTITLEMENT),
            "the admitted extent must survive expiry unchanged"
        );
    }

    /// @notice Proves exhaustion through fulfillment zeroes obligation before expiry.
    function test_commitmentObligation_isZeroOnceEntitlementIsExhausted() public {
        uint256 commitmentId = _recordCommitment(ENTITLEMENT);

        vm.warp(EXERCISABLE_FROM);

        assertEq(harness.commitmentObligation(commitmentId), ENTITLEMENT, "the commitment starts out binding");

        harness.writeRemainingEntitlement(commitmentId, 0);

        assertEq(harness.commitmentObligation(commitmentId), 0, "an exhausted commitment imposes nothing");
        assertTrue(
            StandbyMath.isValid(VALID_UNTIL, block.timestamp), "the exhausted commitment is still temporally valid"
        );
    }

    /// @notice Proves losing and regaining Beneficiary eligibility never changes obligation.
    /// @dev Eligibility is an exercisability condition. If it could reduce obligation, a Beneficiary could
    ///      be silently unbacked at the moment eligibility were restored.
    function test_commitmentObligation_isUnaffectedByBeneficiaryEligibility() public {
        uint256 commitmentId = _recordCommitment(ENTITLEMENT);

        vm.warp(EXERCISABLE_FROM);

        vm.prank(registryAdmin);
        registry.setBeneficiaryEligibility(beneficiary, true);

        uint256 whileEligible = harness.commitmentObligation(commitmentId);

        vm.prank(registryAdmin);
        registry.setBeneficiaryEligibility(beneficiary, false);

        assertFalse(registry.canReceiveProtectedService(beneficiary), "the Beneficiary must actually be ineligible");
        assertEq(
            harness.commitmentObligation(commitmentId),
            whileEligible,
            "losing Beneficiary eligibility must not release backing"
        );

        vm.prank(registryAdmin);
        registry.setBeneficiaryEligibility(beneficiary, true);

        assertEq(
            harness.commitmentObligation(commitmentId),
            whileEligible,
            "restoring Beneficiary eligibility must not change obligation either"
        );
    }

    /// @notice Proves the identity of the caller never changes obligation.
    /// @dev Obligation is a property of the commitment, not of who is asking. Neither the recorded
    ///      exercise authority nor an unrelated account can read a different number.
    function test_commitmentObligation_isUnaffectedByCallerIdentity() public {
        uint256 commitmentId = _recordCommitment(ENTITLEMENT);

        vm.warp(EXERCISABLE_FROM);

        uint256 baseline = harness.commitmentObligation(commitmentId);

        vm.prank(exerciseAuthority);
        assertEq(harness.commitmentObligation(commitmentId), baseline, "the exercise authority reads the same value");

        vm.prank(unauthorizedAccount);
        assertEq(harness.commitmentObligation(commitmentId), baseline, "an unrelated account reads the same value");
    }

    /// @notice Proves an unallocated identity has no obligation to report.
    /// @dev Returning zero would let the absence of a commitment be mistaken for a released one.
    function test_commitmentObligation_revertsForAnIdentityThatWasNeverAllocated() public {
        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(0)));
        harness.commitmentObligation(0);

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(7)));
        harness.commitmentObligation(7);
    }

    /// @notice Proves the derivation read surface belongs to the production Hook, not to the harness.
    /// @dev Every derivation exercised in this file runs on a harness, because a harness is the only thing
    ///      that can record a commitment before the admission slice exists. The reads themselves are
    ///      production, though, and this shows them answering on an untouched production `StandbyHook`:
    ///      an empty enforcement index carries no obligation, and an identity that was never allocated is
    ///      rejected rather than reported as released.
    function test_derivationReads_areExposedByTheProductionHook() public {
        assertEq(hook.aggregateObligation(), 0, "an untouched production Hook carries no obligation");

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(1)));
        hook.commitmentObligation(1);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Asserts the complete derived answer at one time, against both the expectation and the oracle.
    function _assertDerivation(
        uint128 _remaining,
        uint256 _timestamp,
        bool _expectedValid,
        bool _expectedQualified,
        bool _expectedNonBinding,
        uint256 _expectedObligation
    ) internal pure {
        assertEq(StandbyMath.isValid(VALID_UNTIL, _timestamp), _expectedValid, "validity");
        assertEq(
            StandbyMath.isTemporallyExerciseQualified(EXERCISABLE_FROM, VALID_UNTIL, _timestamp),
            _expectedQualified,
            "temporal qualification"
        );
        assertEq(
            StandbyMath.isPermanentlyNonBinding(_remaining, VALID_UNTIL, _timestamp),
            _expectedNonBinding,
            "permanent non-binding"
        );
        assertEq(
            StandbyMath.commitmentObligation(_remaining, VALID_UNTIL, _timestamp), _expectedObligation, "obligation"
        );

        assertEq(
            StandbyMath.isValid(VALID_UNTIL, _timestamp),
            ReferenceCalculations.referenceValid(VALID_UNTIL, _timestamp),
            "validity must equal the independent reference"
        );
        assertEq(
            StandbyMath.isTemporallyExerciseQualified(EXERCISABLE_FROM, VALID_UNTIL, _timestamp),
            ReferenceCalculations.referenceTemporallyExerciseQualified(EXERCISABLE_FROM, VALID_UNTIL, _timestamp),
            "temporal qualification must equal the independent reference"
        );
        assertEq(
            StandbyMath.isPermanentlyNonBinding(_remaining, VALID_UNTIL, _timestamp),
            ReferenceCalculations.referencePermanentlyNonBinding(_remaining, VALID_UNTIL, _timestamp),
            "permanent non-binding must equal the independent reference"
        );
        assertEq(
            StandbyMath.commitmentObligation(_remaining, VALID_UNTIL, _timestamp),
            ReferenceCalculations.referenceCommitmentObligation(_remaining, VALID_UNTIL, _timestamp),
            "obligation must equal the independent reference"
        );
    }

    /// @dev Records one commitment with the shared temporal terms and a chosen remainder.
    function _recordCommitment(uint128 _remaining) internal returns (uint256 commitmentId) {
        commitmentId = harness.recordCommitment(
            StandbyHook.Commitment({
                serviceId: PoolId.wrap(bytes32(uint256(1))),
                beneficiary: beneficiary,
                exercisableFrom: EXERCISABLE_FROM,
                exerciseAuthority: exerciseAuthority,
                validUntil: VALID_UNTIL,
                originalEntitlement: ENTITLEMENT,
                remainingEntitlement: _remaining
            })
        );
    }
}
