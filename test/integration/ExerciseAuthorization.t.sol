// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseExerciseAuthorizationTest} from "../shared/BaseExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for F8A O2 authorization on the real execution stack (G8A-4 through
///         G8A-14).
/// @dev Authorization is the point at which Standby decides that one exercise attempt may proceed, and the
///      claim these tests establish is narrow on purpose: everything the decision turns on is derived from
///      authoritative state, and nothing about the decision changes any of it.
///
///      Every commitment here is authentic. It is created by the production `establishCommitment`
///      transition, from the canonical bootstrap state, through the trusted authority — never by a setter,
///      a harness, a direct storage write, or a fabricated aggregate. Every authorization request travels
///      the real path: an originating exerciser, the real configured `ExerciseRouter`, the real Hook, and
///      the F5 derivations over real pinned `PoolManager` state.
///
///      The canonical numbers are asserted against the frozen fixture expectations rather than against the
///      derivations that produced them, and both live derivations are cross-checked against
///      `ReferenceCalculations` throughout, so nothing here verifies the production derivation against
///      itself.
contract ExerciseAuthorizationTest is BaseExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /// @dev The exercise quantity used wherever the test is not about the quantity: 20,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 20_000_000_000;

    /// @dev The capacity a protected exercise of `EXERCISE_Q` leaves from the canonical bootstrap:
    ///      80,000 - 20,000 MockUSDC.
    uint256 internal constant EXPECTED_EXERCISE_PROSPECTIVE_S = 60_000_000_000;

    /// @dev The obligation a complete successful exercise of `EXERCISE_Q` would leave: 50,000 - 20,000.
    uint256 internal constant EXPECTED_POST_EXERCISE_O = 30_000_000_000;

    /// @dev The ordinary protected output that lands Supporting Capacity exactly on the canonical
    ///      obligation: 80,000 - 30,000 = 50,000 MockUSDC.
    uint256 internal constant EQUALITY_BOUNDARY_SWAP_OUTPUT = 30_000_000_000;

    /*//////////////////////////////////////////////////////////////
              G8A-4..9 — POSITIVE AUTHORIZATION AND BINDINGS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a fully qualified request produces exactly one context with exactly the right
    ///         bindings.
    /// @dev The canonical positive case, with every predicate satisfied at once: the configured router, the
    ///      authenticated exercise authority, a currently valid and currently exercisable commitment, an
    ///      eligible authoritative Beneficiary, a permissible extent, and prospective backing that survives
    ///      the complete successful exercise.
    ///
    ///      The Beneficiary in the resulting context is the interesting binding. Nothing in the request
    ///      named it: it was resolved from the commitment record, which is what makes delivery a fact about
    ///      the commitment rather than a fact about who asked.
    function test_qualifiedRequest_bindsExactlyOneAuthorizedCausalContext() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _assertNoAuthorizationContext("no context may exist before a request");

        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_INITIAL_S, "canonical bootstrap capacity");
        assertEq(hook.aggregateObligation(), StandbyFixtureConfig.CANONICAL_COMMITMENT_Q, "canonical obligation");

        assertEq(
            _expectedProspectiveExerciseCapacity(EXERCISE_Q),
            EXPECTED_EXERCISE_PROSPECTIVE_S,
            "the exercise must be predicted to leave S' = 60,000 MockUSDC"
        );
        assertGt(
            EXPECTED_EXERCISE_PROSPECTIVE_S, EXPECTED_POST_EXERCISE_O, "the canonical case must clear the boundary"
        );

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertAuthorizationContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "authorization must bind the exact causal identity of this attempt"
        );

        StandbyHook.Commitment memory record = hook.commitment(commitmentId);

        assertEq(_authorizationContext().beneficiary, record.beneficiary, "the Beneficiary is resolved, not supplied");
        assertEq(
            _authorizationContext().exerciser, record.exerciseAuthority, "the exerciser is the commitment authority"
        );
    }

    /// @notice Proves authorization alone fulfils nothing and changes no authoritative state.
    /// @dev The whole F8A boundary, stated as one claim. After a successful authorization the commitment
    ///      record is byte-for-byte what it was, the derived obligation is what it was, Supporting Capacity
    ///      is what it was, the bounded index is what it was, no identity was consumed, and no protected
    ///      output reached the Beneficiary, the Hook, or the router. An authorization is a capability, not
    ///      a payment.
    function test_successfulAuthorization_leavesEveryAuthoritativeFactUntouched() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);
        AdmissionState memory before = _admissionState();

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoAdmissionResidue(before, "authorization must change no authoritative state");
        _assertCommitmentFactsUnchanged(commitmentId, admitted, "authorization must touch no commitment fact");
        _assertDerivationsMatchOracles("post-authorization derivations must equal their reconstructions");

        assertEq(
            hook.commitment(commitmentId).remainingEntitlement,
            CANONICAL_ENTITLEMENT,
            "authorization must not reduce Remaining Entitlement"
        );
        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "authorization must not reduce the authoritative obligation"
        );
    }

    /// @notice Proves the causal context does not advance beyond AUTHORIZED at this slice.
    /// @dev An ordinary backed swap runs while an authorization is live. It is enforced as the ordinary O3
    ///      transition it is, against the full unreduced obligation, and the causal context comes out of it
    ///      exactly as it went in. Nothing observes execution, nothing marks execution, and no entitlement
    ///      moves: `AUTHORIZED -> EXECUTED` does not exist yet.
    function test_authorizedContext_doesNotAdvanceBeyondAuthorized() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT));

        _assertAuthorizationContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "an ordinary transition may not advance or consume the causal context"
        );

        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_A2_S, "the ordinary swap was ordinary");
        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "no fulfillment may be attributed to an authorization"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     G8A-4 — COMMITMENT IDENTITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an identity that was never allocated cannot be authorized.
    /// @dev Both shapes: the reserved nonexistent sentinel, and the identity the next admission would
    ///      receive. Neither is an empty commitment that could be exercised for nothing.
    function test_nonexistentCommitment_isRejected() public {
        _establishExercisable(CANONICAL_ENTITLEMENT);

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(0)));
        _authorizeAs(commitmentExerciseAuthority, 0, EXERCISE_Q);

        uint256 unallocated = hook.nextCommitmentId();

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, unallocated));
        _authorizeAs(commitmentExerciseAuthority, unallocated, EXERCISE_Q);

        _assertNoAuthorizationContext("a nonexistent commitment must leave no causal context");
    }

    /// @notice Proves authority over one commitment authorizes nothing about another.
    /// @dev Two authentic commitments, two distinct exercise authorities, one Hook. Each authority is
    ///      refused on the other's commitment and accepted on its own, so the authorization is bound to a
    ///      commitment rather than to a role.
    function test_commitmentSubstitution_isRejected() public {
        uint256 first = _establishExercisable(20_000_000_000);

        address secondAuthority = makeAddr("secondExerciseAuthority");

        uint256 second = _establishAs(
            establishmentAuthority,
            secondBeneficiary,
            secondAuthority,
            20_000_000_000,
            uint64(block.timestamp),
            uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotCommitmentExerciseAuthority.selector, second, commitmentExerciseAuthority
            )
        );
        _authorizeAs(commitmentExerciseAuthority, second, EXERCISE_Q);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotCommitmentExerciseAuthority.selector, first, secondAuthority
            )
        );
        _authorizeAs(secondAuthority, first, EXERCISE_Q);

        _assertNoAuthorizationContext("a substituted commitment must leave no causal context");

        _authorizeAs(secondAuthority, second, EXERCISE_Q);

        _assertAuthorizationContext(
            second, secondAuthority, secondBeneficiary, EXERCISE_Q, "each authority may authorize its own commitment"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     G8A-6 — TEMPORAL BOUNDARIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a commitment whose exercise window has not opened cannot be authorized.
    /// @dev And that being unauthorizable releases nothing: the commitment is fully valid, fully binding,
    ///      and imposes its whole Remaining Entitlement while it waits.
    function test_beforeExercisableFrom_isRejected() public {
        uint256 commitmentId = _establish(CANONICAL_ENTITLEMENT);

        StandbyHook.Commitment memory record = hook.commitment(commitmentId);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CommitmentNotExercisable.selector,
                commitmentId,
                record.exercisableFrom,
                record.validUntil,
                block.timestamp
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("a closed window must leave no causal context");

        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "a commitment that is not yet exercisable is still fully binding"
        );
    }

    /// @notice Proves the exercise window opens inclusively, at `exercisableFrom` exactly.
    function test_atExercisableFrom_isPermitted() public {
        uint256 commitmentId = _establish(CANONICAL_ENTITLEMENT);

        StandbyHook.Commitment memory record = hook.commitment(commitmentId);

        vm.warp(record.exercisableFrom);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertAuthorizationContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, EXERCISE_Q, "exercisableFrom is inclusive"
        );
    }

    /// @notice Proves the validity window remains open up to the last instant before `validUntil`.
    function test_immediatelyBeforeValidUntil_isPermitted() public {
        uint256 commitmentId = _establish(CANONICAL_ENTITLEMENT);

        StandbyHook.Commitment memory record = hook.commitment(commitmentId);

        vm.warp(uint256(record.validUntil) - 1);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertAuthorizationContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, EXERCISE_Q, "validUntil is exclusive"
        );
    }

    /// @notice Proves validity ends exclusively, at `validUntil` exactly.
    /// @dev The rejection names invalidity rather than non-exercisability. The two are different facts with
    ///      different consequences, and at this instant the permanent one is what happened.
    function test_atValidUntil_isRejected() public {
        uint256 commitmentId = _establish(CANONICAL_ENTITLEMENT);

        StandbyHook.Commitment memory record = hook.commitment(commitmentId);

        vm.warp(record.validUntil);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CommitmentNotValid.selector, commitmentId, record.validUntil, block.timestamp
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("an invalid commitment must leave no causal context");
    }

    /// @notice Proves expiry releases the obligation without rewriting the commitment.
    /// @dev The existing release behavior, observed through authorization rather than restated by it. Past
    ///      `validUntil` the commitment imposes nothing and can no longer be exercised, and its admitted
    ///      terms and unfulfilled remainder are still exactly what they always were.
    function test_afterValidUntil_releasesTheObligationWithoutChangingRemaining() public {
        uint256 commitmentId = _establish(CANONICAL_ENTITLEMENT);

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);

        vm.warp(uint256(admitted.validUntil) + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CommitmentNotValid.selector, commitmentId, admitted.validUntil, block.timestamp
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        assertEq(hook.aggregateObligation(), 0, "expiry releases the Capacity Obligation");
        _assertCommitmentFactsUnchanged(commitmentId, admitted, "expiry rewrites no commitment fact");
        _assertNoAuthorizationContext("an expired commitment must leave no causal context");
    }

    /*//////////////////////////////////////////////////////////////
                  G8A-6 — BENEFICIARY ELIGIBILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves current Beneficiary ineligibility prevents authorization and releases nothing.
    /// @dev Eligibility administration is not a release surface. The commitment stays valid, keeps its
    ///      Remaining Entitlement, keeps imposing its full Capacity Obligation, and keeps its admitted
    ///      terms; all that changed is that it is not currently exercisable.
    function test_ineligibleBeneficiary_isRejectedAndReleasesNothing() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);

        _setBeneficiaryEligibility(beneficiary, false);

        AdmissionState memory before = _admissionState();

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__BeneficiaryNotEligible.selector, beneficiary));
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("an ineligible Beneficiary must leave no causal context");
        _assertNoAdmissionResidue(before, "a refused authorization must leave no authoritative residue");
        _assertCommitmentFactsUnchanged(commitmentId, admitted, "ineligibility rewrites no commitment fact");

        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "ineligibility must not release the binding obligation"
        );
    }

    /// @notice Proves restored eligibility restores authorizability.
    /// @dev Ineligibility is a current condition, not an irreversible consequence, so nothing about the
    ///      refusal may have consumed or degraded the commitment.
    function test_restoredBeneficiaryEligibility_restoresAuthorizability() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _setBeneficiaryEligibility(beneficiary, false);

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__BeneficiaryNotEligible.selector, beneficiary));
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _setBeneficiaryEligibility(beneficiary, true);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertAuthorizationContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, EXERCISE_Q, "restored eligibility must authorize"
        );
    }

    /*//////////////////////////////////////////////////////////////
                       G8A-7 — EXERCISE EXTENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a zero-quantity request is refused.
    /// @dev An exercise of nothing is not a cheap exercise; it is not an exercise, and admitting one would
    ///      create a causal context that no execution could ever match.
    function test_zeroQuantity_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidExerciseExtent.selector, uint256(0), CANONICAL_ENTITLEMENT
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, 0);

        _assertNoAuthorizationContext("a zero quantity must leave no causal context");
    }

    /// @notice Proves a quantity strictly inside the remainder is permitted.
    function test_partialQuantity_isPermitted() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertAuthorizationContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, EXERCISE_Q, "0 < q < Remaining is permitted"
        );
    }

    /// @notice Proves the whole remainder is a permissible extent.
    /// @dev The inclusive end of `0 < q <= Remaining`, and the case a commitment exists for: exercising
    ///      everything that remains must not be refused because it is everything.
    function test_fullRemainingQuantity_isPermitted() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, CANONICAL_ENTITLEMENT);

        _assertAuthorizationContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, CANONICAL_ENTITLEMENT, "q == Remaining is permitted"
        );
    }

    /// @notice Proves a quantity above the remainder is refused, including by a single raw unit.
    function test_quantityAboveRemaining_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidExerciseExtent.selector,
                uint256(CANONICAL_ENTITLEMENT) + 1,
                CANONICAL_ENTITLEMENT
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, uint256(CANONICAL_ENTITLEMENT) + 1);

        _assertNoAuthorizationContext("an impermissible extent must leave no causal context");
    }

    /*//////////////////////////////////////////////////////////////
                    G8A-8 — PROSPECTIVE BACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves authorization passes when the exercise leaves capacity strictly above the obligation.
    /// @dev The canonical case, checked against the frozen expectation on both sides rather than against
    ///      the derivations that produced them: 60,000 MockUSDC of capacity against 30,000 of remaining
    ///      obligation.
    function test_prospectiveBacking_permitsWhenCapacityStrictlyExceedsRemainingObligation() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        assertEq(_referenceSupportingCapacity(), StandbyFixtureConfig.EXPECTED_INITIAL_S, "reconstructed capacity");
        assertEq(
            _referenceAggregateObligation(), StandbyFixtureConfig.CANONICAL_COMMITMENT_Q, "reconstructed obligation"
        );
        assertEq(
            _expectedProspectiveExerciseCapacity(EXERCISE_Q),
            EXPECTED_EXERCISE_PROSPECTIVE_S,
            "the exercise leaves 60,000 MockUSDC"
        );

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertAuthorizationContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, EXERCISE_Q, "S' > O - q must be authorized"
        );
    }

    /// @notice Proves exact sufficiency is authorized.
    /// @dev Reached entirely through production transitions. An ordinary protected swap first draws
    ///      Supporting Capacity down to exactly the canonical obligation, so the service sits on the backing
    ///      boundary with `S = O = 50,000`; the exercise then leaves `S' = 30,000` against a remaining
    ///      obligation of exactly `30,000`. Equality preserves backing and must not be refused.
    function test_prospectiveBacking_permitsAtExactSufficiency() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(EQUALITY_BOUNDARY_SWAP_OUTPUT));

        assertEq(
            _referenceSupportingCapacity(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "the service must sit exactly on the backing boundary"
        );

        assertEq(
            _expectedProspectiveExerciseCapacity(EXERCISE_Q),
            EXPECTED_POST_EXERCISE_O,
            "the exercise must leave capacity exactly equal to the remaining obligation"
        );

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertAuthorizationContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, EXERCISE_Q, "S' == O - q must be authorized"
        );

        assertEq(
            hook.aggregateObligation(),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "authorization at the boundary still reduces no obligation"
        );
    }

    /*//////////////////////////////////////////////////////////////
                  G8A-11..12 — REPLAY AND SUBSTITUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a second authorization cannot become active while one is unresolved.
    /// @dev Three shapes of second request are refused — the identical one, a different quantity, and a
    ///      different commitment held by a different authority — and the original context survives all of
    ///      them unchanged. Neither overwriting nor coexistence is available.
    function test_secondAuthorization_cannotOverwriteOrCoexist() public {
        uint256 first = _establishExercisable(20_000_000_000);

        address secondAuthority = makeAddr("secondExerciseAuthority");

        uint256 second = _establishAs(
            establishmentAuthority,
            secondBeneficiary,
            secondAuthority,
            20_000_000_000,
            uint64(block.timestamp),
            uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION
        );

        _authorizeAs(commitmentExerciseAuthority, first, EXERCISE_Q);

        vm.expectRevert(StandbyHook.StandbyHook__ExerciseAuthorizationAlreadyActive.selector);
        _authorizeAs(commitmentExerciseAuthority, first, EXERCISE_Q);

        vm.expectRevert(StandbyHook.StandbyHook__ExerciseAuthorizationAlreadyActive.selector);
        _authorizeAs(commitmentExerciseAuthority, first, EXERCISE_Q / 2);

        vm.expectRevert(StandbyHook.StandbyHook__ExerciseAuthorizationAlreadyActive.selector);
        _authorizeAs(secondAuthority, second, EXERCISE_Q);

        _assertAuthorizationContext(
            first,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "the active context must survive every attempted replacement"
        );
    }

    /// @notice Proves every kind of failed authorization leaves nothing usable behind.
    /// @dev The refusals are deliberately of different kinds — perimeter, identity, authority, time,
    ///      eligibility, extent — because "no residue" has to hold for all of them, and then a genuine
    ///      request still succeeds afterwards, so the refusals did not degrade anything either.
    function test_failedAuthorizations_leaveNoUsableContext() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotExerciseRouter.selector, address(unconfiguredExerciseRouter)
            )
        );
        vm.prank(commitmentExerciseAuthority);
        unconfiguredExerciseRouter.exercise(commitmentId, EXERCISE_Q, UNCONSTRAINED_MAX_INPUT);
        _assertNoAuthorizationContext("a refused perimeter leaves nothing");

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__CommitmentDoesNotExist.selector, uint256(0)));
        _authorizeAs(commitmentExerciseAuthority, 0, EXERCISE_Q);
        _assertNoAuthorizationContext("a refused identity leaves nothing");

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotCommitmentExerciseAuthority.selector, commitmentId, unauthorizedExerciser
            )
        );
        _authorizeAs(unauthorizedExerciser, commitmentId, EXERCISE_Q);
        _assertNoAuthorizationContext("a refused authority leaves nothing");

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidExerciseExtent.selector, uint256(0), CANONICAL_ENTITLEMENT
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, 0);
        _assertNoAuthorizationContext("a refused extent leaves nothing");

        _setBeneficiaryEligibility(beneficiary, false);
        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__BeneficiaryNotEligible.selector, beneficiary));
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);
        _assertNoAuthorizationContext("a refused Beneficiary leaves nothing");
        _setBeneficiaryEligibility(beneficiary, true);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertAuthorizationContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "the single authorization slot must still be available after any number of refusals"
        );
    }
}

/// @notice Integration evidence that an O2 authorization cannot be reused across transactions (G8A-12).
/// @dev The claim is about a transaction boundary, so it has to be made across one. The authorization
///      happens in `setUp`, which Foundry executes as its own transaction, and the test body then runs in a
///      new one. Nothing is cleared by any Standby code between them — F8A implements no consumption at all
///      — so what the test body observes is the transient context expiring with the transaction that
///      created it, which is the property the realization relies on.
contract ExerciseAuthorizationTransactionScopeTest is BaseExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint128 internal constant CARRIED_ENTITLEMENT = 20_000_000_000;

    uint256 internal constant CARRIED_Q = 5_000_000_000;

    uint256 internal carriedCommitmentId;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorizes an exercise in the fixture transaction and lets that transaction end.
    function setUp() public virtual override {
        super.setUp();

        carriedCommitmentId = _establishExercisable(CARRIED_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, carriedCommitmentId, CARRIED_Q);

        _assertAuthorizationContext(
            carriedCommitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            CARRIED_Q,
            "the fixture transaction must genuinely have authorized"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     TRANSACTION-SCOPED CONTEXT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the authorization did not survive into the next transaction.
    function test_authorization_doesNotSurviveItsTransaction() public view {
        _assertNoAuthorizationContext("an authorization must not survive its transaction");
    }

    /// @notice Proves the next transaction may authorize afresh rather than inheriting a blocked slot.
    /// @dev The complementary half: an expired context releases the single authorization slot as well as
    ///      the capability, so the restriction is transaction-local in both directions.
    function test_theNextTransaction_mayAuthorizeAfresh() public {
        _authorizeAs(commitmentExerciseAuthority, carriedCommitmentId, CARRIED_Q);

        _assertAuthorizationContext(
            carriedCommitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            CARRIED_Q,
            "a new transaction must be able to authorize"
        );

        assertEq(
            hook.commitment(carriedCommitmentId).remainingEntitlement,
            CARRIED_ENTITLEMENT,
            "two authorizations of the same commitment still fulfil nothing"
        );
    }
}
