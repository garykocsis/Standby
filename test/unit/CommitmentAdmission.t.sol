// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseCommitmentAdmissionTest} from "../shared/BaseCommitmentAdmissionTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Unit evidence for the F7 O1 admission predicates (G7.1–G7.5, G7.14, G7.15).
/// @dev This file covers the predicates that decide whether a proposed commitment may be admitted at all:
///      who may ask, whether a service exists to ask against, whether the proposed terms are admissible,
///      and whether the proposed Beneficiary is currently entitled to protected service. Every one of them
///      is exercised through the production `establishCommitment` transition on the production
///      `StandbyHook`; no harness records a commitment here, because a commitment a harness records is not
///      an admitted one.
///
///      Each rejection is proved twice over: the specific Standby reason is asserted, so a test cannot
///      pass on an unrelated failure, and the complete authoritative state is compared before and after,
///      so a rejection that had already written something would fail even while reverting for the right
///      reason.
///
///      Positive admission is proved alongside every rejection family. A transition that refused
///      everything would satisfy all the rejection tests and be worthless.
contract CommitmentAdmissionTest is BaseCommitmentAdmissionTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A comfortably backed entitlement: far below the canonical fixture's Supporting Capacity, so
    ///      nothing in this file can pass or fail because of the backing boundary.
    uint128 internal constant ADMISSIBLE_Q = 1_000 * 10 ** 6;

    /*//////////////////////////////////////////////////////////////
                    G7.1 — ESTABLISHMENT AUTHORITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the configured establishment authority may admit a commitment.
    function test_establishCommitment_byEstablishmentAuthority_isAdmitted() public {
        uint256 commitmentId = _establish(ADMISSIBLE_Q);

        assertEq(commitmentId, 1, "the first admitted identity is 1");
        assertEq(hook.aggregateObligation(), ADMISSIBLE_Q, "the admitted commitment must bind immediately");
    }

    /// @notice Proves an account holding no Standby role cannot admit a commitment.
    function test_establishCommitment_byUnauthorizedCaller_isRejected() public {
        address stranger = makeAddr("stranger");

        _assertAdmissionRejectedFor(
            stranger, abi.encodeWithSelector(StandbyHook.StandbyHook__NotEstablishmentAuthority.selector, stranger)
        );
    }

    /// @notice Proves no other Standby role implicitly confers establishment authority.
    /// @dev Each of these accounts genuinely holds authority somewhere in the system — over configuration,
    ///      over the registry, over exercise coordination, over trading, over liquidity, or over the
    ///      commitment that would be created. None of that is establishment authority, and the separation
    ///      has to be proved rather than assumed from the fact that the fields are stored separately.
    function test_establishCommitment_byEveryOtherRole_isRejected() public {
        _assertAdmissionRejectedFor(
            configurationAuthority,
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotEstablishmentAuthority.selector, configurationAuthority)
        );
        _assertAdmissionRejectedFor(
            registryAdmin,
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotEstablishmentAuthority.selector, registryAdmin)
        );
        _assertAdmissionRejectedFor(
            exerciseRouter,
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotEstablishmentAuthority.selector, exerciseRouter)
        );
        _assertAdmissionRejectedFor(
            commitmentExerciseAuthority,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotEstablishmentAuthority.selector, commitmentExerciseAuthority
            )
        );
        _assertAdmissionRejectedFor(
            beneficiary,
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotEstablishmentAuthority.selector, beneficiary)
        );
        _assertAdmissionRejectedFor(
            eligibleTrader,
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotEstablishmentAuthority.selector, eligibleTrader)
        );
        _assertAdmissionRejectedFor(
            canonicalProvider,
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotEstablishmentAuthority.selector, canonicalProvider)
        );
        _assertAdmissionRejectedFor(
            address(swapPerimeter),
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotEstablishmentAuthority.selector, address(swapPerimeter))
        );
    }

    /*//////////////////////////////////////////////////////////////
                        G7.2 — ACTIVATED SERVICE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a Hook with no Protected Execution Service admits nothing.
    /// @dev The Hook is real, deployed through the canonical procedure, and simply never activated. It has
    ///      no establishment authority for anyone to be, which is exactly why service existence has to be
    ///      settled before authority can be authenticated at all.
    function test_establishCommitment_onAnUnconfiguredHook_isRejected() public {
        (StandbyHook unconfiguredHook,) = hookDeployer.deployStandbyHook(
            poolManager,
            address(hookDeployer),
            makeAddr("secondConfigurationAuthority"),
            address(swapPerimeter),
            address(liquidityPerimeter)
        );

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        vm.expectRevert(StandbyHook.StandbyHook__ServiceNotConfigured.selector);
        vm.prank(establishmentAuthority);
        unconfiguredHook.establishCommitment(
            beneficiary, commitmentExerciseAuthority, ADMISSIBLE_Q, exercisableFrom, validUntil
        );

        assertEq(unconfiguredHook.nextCommitmentId(), 1, "a rejected admission consumes no identity");
    }

    /*//////////////////////////////////////////////////////////////
                     G7.3 — COMMITMENT-TERM PREDICATES
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a commitment naming no Beneficiary is rejected.
    function test_establishCommitment_withZeroBeneficiary_isRejected() public {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        _assertAdmissionRejected(
            establishmentAuthority,
            address(0),
            commitmentExerciseAuthority,
            ADMISSIBLE_Q,
            exercisableFrom,
            validUntil,
            abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidBeneficiary.selector)
        );
    }

    /// @notice Proves a commitment naming no exercise authority is rejected.
    function test_establishCommitment_withZeroExerciseAuthority_isRejected() public {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        _assertAdmissionRejected(
            establishmentAuthority,
            beneficiary,
            address(0),
            ADMISSIBLE_Q,
            exercisableFrom,
            validUntil,
            abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidExerciseAuthority.selector)
        );
    }

    /// @notice Proves a commitment carrying no entitlement is rejected.
    function test_establishCommitment_withZeroEntitlement_isRejected() public {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        _assertAdmissionRejected(
            establishmentAuthority,
            beneficiary,
            commitmentExerciseAuthority,
            0,
            exercisableFrom,
            validUntil,
            abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidOriginalEntitlement.selector)
        );
    }

    /// @notice Proves a commitment whose validity ends exactly when its window opens is rejected.
    /// @dev The window is half-open, so `validUntil == exercisableFrom` admits a commitment that could
    ///      never be exercisable for any instant at all.
    function test_establishCommitment_withValidUntilEqualToExercisableFrom_isRejected() public {
        uint64 boundary = uint64(block.timestamp) + DEFAULT_EXERCISE_DELAY;

        _assertAdmissionRejected(
            establishmentAuthority,
            beneficiary,
            commitmentExerciseAuthority,
            ADMISSIBLE_Q,
            boundary,
            boundary,
            abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidCommitmentWindow.selector, boundary, boundary)
        );
    }

    /// @notice Proves a commitment whose validity ends before its window opens is rejected.
    function test_establishCommitment_withValidUntilBeforeExercisableFrom_isRejected() public {
        uint64 exercisableFrom = uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION;
        uint64 validUntil = uint64(block.timestamp) + DEFAULT_EXERCISE_DELAY;

        _assertAdmissionRejected(
            establishmentAuthority,
            beneficiary,
            commitmentExerciseAuthority,
            ADMISSIBLE_Q,
            exercisableFrom,
            validUntil,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidCommitmentWindow.selector, exercisableFrom, validUntil
            )
        );
    }

    /// @notice Proves a commitment whose validity has already ended is rejected.
    function test_establishCommitment_withValidUntilInThePast_isRejected() public {
        uint64 exercisableFrom = uint64(block.timestamp) - 2 hours;
        uint64 validUntil = uint64(block.timestamp) - 1 hours;

        _assertAdmissionRejected(
            establishmentAuthority,
            beneficiary,
            commitmentExerciseAuthority,
            ADMISSIBLE_Q,
            exercisableFrom,
            validUntil,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CommitmentAlreadyInvalid.selector, validUntil, block.timestamp
            )
        );
    }

    /// @notice Proves a commitment whose validity ends exactly now is rejected.
    /// @dev The half-open boundary again, at the other end: at `block.timestamp == validUntil` the
    ///      entitlement is already invalid, so admitting it would create a commitment binding on nothing.
    function test_establishCommitment_withValidUntilEqualToNow_isRejected() public {
        uint64 exercisableFrom = uint64(block.timestamp) - 1 hours;
        uint64 validUntil = uint64(block.timestamp);

        _assertAdmissionRejected(
            establishmentAuthority,
            beneficiary,
            commitmentExerciseAuthority,
            ADMISSIBLE_Q,
            exercisableFrom,
            validUntil,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CommitmentAlreadyInvalid.selector, validUntil, block.timestamp
            )
        );
    }

    /// @notice Proves a commitment whose exercise window is already open is admissible.
    /// @dev `TE < now < TV`. Admission must not require a future window: refusing this would reject
    ///      behavior the frozen temporal semantics explicitly permit.
    function test_establishCommitment_withAnAlreadyOpenWindow_isAdmitted() public {
        uint64 exercisableFrom = uint64(block.timestamp) - 1 hours;
        uint64 validUntil = uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION;

        uint256 commitmentId = _establishWithWindow(ADMISSIBLE_Q, exercisableFrom, validUntil);

        assertEq(hook.commitmentObligation(commitmentId), ADMISSIBLE_Q, "an open-window commitment binds");
    }

    /// @notice Proves a commitment whose exercise window opens exactly now is admissible.
    /// @dev `TE == now < TV`, the inclusive end of exercise qualification.
    function test_establishCommitment_withAWindowOpeningNow_isAdmitted() public {
        uint64 exercisableFrom = uint64(block.timestamp);
        uint64 validUntil = uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION;

        uint256 commitmentId = _establishWithWindow(ADMISSIBLE_Q, exercisableFrom, validUntil);

        assertEq(hook.commitmentObligation(commitmentId), ADMISSIBLE_Q, "a just-opened commitment binds");
    }

    /// @notice Proves a commitment whose exercise window has not opened yet is admissible.
    /// @dev `now < TE < TV`. The obligation is established immediately regardless.
    function test_establishCommitment_withAFutureWindow_isAdmitted() public {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        uint256 commitmentId = _establishWithWindow(ADMISSIBLE_Q, exercisableFrom, validUntil);

        assertEq(hook.commitmentObligation(commitmentId), ADMISSIBLE_Q, "a future-window commitment binds");
    }

    /*//////////////////////////////////////////////////////////////
                     G7.4 — BENEFICIARY ELIGIBILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a commitment for a currently ineligible Beneficiary is rejected.
    function test_establishCommitment_forAnIneligibleBeneficiary_isRejected() public {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        _assertAdmissionRejected(
            establishmentAuthority,
            ineligibleBeneficiary,
            commitmentExerciseAuthority,
            ADMISSIBLE_Q,
            exercisableFrom,
            validUntil,
            abi.encodeWithSelector(StandbyHook.StandbyHook__BeneficiaryNotEligible.selector, ineligibleBeneficiary)
        );
    }

    /// @notice Proves the identical commitment is admitted once the registry makes that account eligible.
    /// @dev The rejection above is therefore attributable to Beneficiary eligibility and to nothing else:
    ///      the caller, the terms, the window, and the backing are unchanged here.
    function test_establishCommitment_succeedsForTheSameBeneficiaryOnceEligible() public {
        _setBeneficiaryEligibility(ineligibleBeneficiary, true);

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        uint256 commitmentId = _establishAs(
            establishmentAuthority,
            ineligibleBeneficiary,
            commitmentExerciseAuthority,
            ADMISSIBLE_Q,
            exercisableFrom,
            validUntil
        );

        assertEq(hook.commitment(commitmentId).beneficiary, ineligibleBeneficiary, "the Beneficiary must be recorded");
    }

    /// @notice Proves Beneficiary eligibility is read at admission and not from the trader domain.
    /// @dev The candidate is an eligible trader and an eligible liquidity provider, and neither answers
    ///      the Beneficiary question. Three distinct predicates, three distinct permission domains.
    function test_establishCommitment_doesNotAcceptTraderOrLiquidityEligibility() public {
        _setTraderEligibility(ineligibleBeneficiary, true);
        _setLiquidityEligibility(ineligibleBeneficiary, true);

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        _assertAdmissionRejected(
            establishmentAuthority,
            ineligibleBeneficiary,
            commitmentExerciseAuthority,
            ADMISSIBLE_Q,
            exercisableFrom,
            validUntil,
            abi.encodeWithSelector(StandbyHook.StandbyHook__BeneficiaryNotEligible.selector, ineligibleBeneficiary)
        );
    }

    /// @notice Proves later Beneficiary ineligibility does not release an admitted binding obligation.
    /// @dev Eligibility governs admission. It is not a validity-ending condition, so revoking it changes
    ///      neither the recorded facts nor the Capacity Obligation they derive: the commitment keeps
    ///      binding shared liquidity exactly as before.
    function test_revokingBeneficiaryEligibility_doesNotReleaseAnAdmittedObligation() public {
        uint256 commitmentId = _establish(ADMISSIBLE_Q);

        StandbyHook.Commitment memory before = hook.commitment(commitmentId);

        _setBeneficiaryEligibility(beneficiary, false);

        assertFalse(registry.canReceiveProtectedService(beneficiary), "the Beneficiary must now be ineligible");

        assertEq(hook.commitmentObligation(commitmentId), ADMISSIBLE_Q, "ineligibility must not release backing");
        assertEq(hook.aggregateObligation(), ADMISSIBLE_Q, "the aggregate must be unchanged");

        StandbyHook.Commitment memory current = hook.commitment(commitmentId);

        assertEq(
            uint256(current.remainingEntitlement),
            uint256(before.remainingEntitlement),
            "ineligibility must not change Remaining Entitlement"
        );
        assertEq(uint256(current.validUntil), uint256(before.validUntil), "ineligibility must not end validity");

        (bool referenced,) = _referenceSlotOf(commitmentId);

        assertTrue(referenced, "ineligibility must not delete the enforcement reference");
    }

    /*//////////////////////////////////////////////////////////////
                     G7.5 — INITIAL ENTITLEMENT BASIS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a successful admission records nothing as fulfilled.
    /// @dev Cumulative fulfillment is derived as `Original - Remaining`, so the only way to say "nothing
    ///      has been fulfilled" at admission is for the two to be equal.
    function test_admittedCommitment_hasFullRemainingEntitlement() public {
        uint256 commitmentId = _establish(ADMISSIBLE_Q);

        StandbyHook.Commitment memory record = hook.commitment(commitmentId);

        assertEq(uint256(record.originalEntitlement), uint256(ADMISSIBLE_Q), "Original Entitlement must equal q");
        assertEq(uint256(record.remainingEntitlement), uint256(ADMISSIBLE_Q), "Remaining Entitlement must equal q");
        assertEq(
            uint256(record.originalEntitlement) - uint256(record.remainingEntitlement),
            0,
            "no fulfillment may exist at admission"
        );
    }

    /*//////////////////////////////////////////////////////////////
                       G7.14 — COMMITMENT IDENTITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves successive admissions receive unique, monotonic, nonzero identities.
    function test_successiveAdmissions_receiveUniqueMonotonicIdentities() public {
        uint256 first = _establish(ADMISSIBLE_Q);
        uint256 second = _establish(ADMISSIBLE_Q);
        uint256 third = _establish(ADMISSIBLE_Q);

        assertGt(first, 0, "identities are never the reserved sentinel");
        assertEq(second, first + 1, "identities advance by exactly one");
        assertEq(third, second + 1, "identities advance by exactly one");
        assertEq(hook.nextCommitmentId(), third + 1, "the sequence advances with each admission");
    }

    /// @notice Proves a failed admission between two successful ones consumes no identity.
    /// @dev The identity the failed attempt would have taken is handed to the next successful admission
    ///      instead, so a rejected attempt leaves no gap and no reserved number behind.
    function test_failedAdmission_consumesNoIdentity() public {
        uint256 first = _establish(ADMISSIBLE_Q);

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        _assertAdmissionRejected(
            establishmentAuthority,
            beneficiary,
            commitmentExerciseAuthority,
            0,
            exercisableFrom,
            validUntil,
            abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidOriginalEntitlement.selector)
        );

        uint256 second = _establish(ADMISSIBLE_Q);

        assertEq(second, first + 1, "the failed attempt must not have advanced the sequence");
    }

    /// @notice Proves an identity that was never admitted cannot be read as an empty commitment.
    function test_unadmittedIdentity_doesNotExist() public {
        _establish(ADMISSIBLE_Q);

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(2)));
        hook.commitment(2);

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(0)));
        hook.commitment(0);
    }

    /*//////////////////////////////////////////////////////////////
                  G7.15 — ADMISSION ATOMICITY BASELINE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a rejected admission leaves no residue even with authentic commitments in existence.
    /// @dev The interesting case is not a rejection against an empty Hook. It is a rejection against a Hook
    ///      that already holds authoritative commitments, a positive derived obligation, and occupied
    ///      references — the state a partial write would be easiest to hide in.
    function test_rejectedAdmission_alongsideExistingCommitments_leavesNoResidue() public {
        _establish(ADMISSIBLE_Q);
        _establish(ADMISSIBLE_Q);

        assertEq(hook.aggregateObligation(), uint256(ADMISSIBLE_Q) * 2, "the fixture must hold a positive obligation");

        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        _assertAdmissionRejected(
            establishmentAuthority,
            ineligibleBeneficiary,
            commitmentExerciseAuthority,
            ADMISSIBLE_Q,
            exercisableFrom,
            validUntil,
            abi.encodeWithSelector(StandbyHook.StandbyHook__BeneficiaryNotEligible.selector, ineligibleBeneficiary)
        );
    }

    /// @notice Proves a successful O1 emits the admission evidence it returns.
    function test_successfulAdmission_emitsAdmissionEvidence() public {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        vm.expectEmit(true, true, true, true, address(hook));
        emit StandbyHook.CommitmentEstablished(
            1, servicePoolId, beneficiary, commitmentExerciseAuthority, ADMISSIBLE_Q, exercisableFrom, validUntil, 0
        );

        _establishWithWindow(ADMISSIBLE_Q, exercisableFrom, validUntil);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Asserts an otherwise valid admission attempted by one caller is rejected without residue.
    function _assertAdmissionRejectedFor(address _caller, bytes memory _reason) internal {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        _assertAdmissionRejected(
            _caller, beneficiary, commitmentExerciseAuthority, ADMISSIBLE_Q, exercisableFrom, validUntil, _reason
        );
    }

    /// @dev Asserts one admission attempt is rejected for the exact stated reason and leaves no residue.
    function _assertAdmissionRejected(
        address _caller,
        address _beneficiary,
        address _exerciseAuthority,
        uint128 _originalEntitlement,
        uint64 _exercisableFrom,
        uint64 _validUntil,
        bytes memory _reason
    ) internal {
        AdmissionState memory stateBefore = _admissionState();

        vm.expectRevert(_reason);
        vm.prank(_caller);
        hook.establishCommitment(_beneficiary, _exerciseAuthority, _originalEntitlement, _exercisableFrom, _validUntil);

        _assertNoAdmissionResidue(stateBefore, "a rejected admission must leave no authoritative residue");
    }

    /// @dev Guards the assumption every backing-independent test in this file relies on.
    function test_fixtureCapacityFarExceedsTheEntitlementUsedHere() public view {
        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_INITIAL_S, "canonical bootstrap capacity");
        assertGt(
            hook.supportingCapacity(), uint256(ADMISSIBLE_Q) * 3, "the term predicates must not be backing-limited"
        );
    }
}
