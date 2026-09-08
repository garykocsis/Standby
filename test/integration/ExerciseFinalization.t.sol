// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {MisdirectedFinalizationRouter} from "../harness/MisdirectedFinalizationRouter.sol";
import {BaseExerciseFinalizationTest} from "../shared/BaseExerciseFinalizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for F8D durable fulfillment on the complete production path (G8D-A
///         through G8D-F).
/// @dev Every exercise here is requested through the production `ExerciseRouter`, authorized by the
///      production Hook, executed by the real pinned `PoolManager` against a real pool holding real
///      liquidity, settled from the exerciser's own account, delivered directly to the Beneficiary, and
///      finalized by the production Hook — for a commitment the production O1 transition admitted. Nothing
///      is seeded, no harness participates, and no barrier is lifted.
///
///      That is what makes these the first suites in the repository whose subject is a *committed* Standby
///      exercise. Everything they assert afterwards is read back from authoritative state: the commitment
///      record, the derived obligation, the derived capacity, real token balances, and the Hook's own
///      causal context.
contract ExerciseFinalizationTest is BaseExerciseFinalizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /// @dev The exercise quantity used wherever the test is not about the quantity: 20,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 20_000_000_000;

    /*//////////////////////////////////////////////////////////////
                  G8D-C, G8D-F — EXACT PARTIAL FULFILLMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a completed exercise reduces Remaining Entitlement by exactly the exercised quantity.
    /// @dev The canonical positive case, end to end. What the Beneficiary received and what the commitment
    ///      gave up are asserted against each other in the same breath, because a fulfillment that
    ///      discharged a different amount than it delivered would be exactly the failure that matters here.
    ///      The admitted extent is untouched, the derived obligation released exactly the same quantity,
    ///      and the emitted attribution names the commitment, the Beneficiary, the exerciser, and the
    ///      remainder the reduction produced.
    function test_completedExercise_reducesRemainingByExactlyQ() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        vm.expectEmit(true, true, true, true, address(hook));
        emit StandbyHook.ExerciseFinalized(
            commitmentId,
            servicePoolId,
            beneficiary,
            commitmentExerciseAuthority,
            EXERCISE_Q,
            CANONICAL_ENTITLEMENT - uint128(EXERCISE_Q)
        );

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertExactFulfillment(before, commitmentExerciseAuthority, commitmentId, EXERCISE_Q);
    }

    /// @notice Proves a one-raw-unit exercise fulfils exactly one raw unit.
    /// @dev The smallest fulfillment the protocol admits. It still performs a real swap, still settles a
    ///      real debt, and still moves the remainder by exactly one.
    function test_minimalExercise_fulfilsExactlyOneRawUnit() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, 1);

        _assertExactFulfillment(before, commitmentExerciseAuthority, commitmentId, 1);
    }

    /// @notice Proves successive partial exercises leave the exact arithmetic remainder.
    /// @dev Three separate complete exercises against one commitment, each with its own authorization, its
    ///      own swap, its own settlement, its own delivery, and its own finalization. The remainder after
    ///      each is the exact difference, and the Beneficiary's total is the exact sum — so no exercise
    ///      double-counts, rounds, or drifts against the others.
    function test_sequentialPartialExercises_produceTheExactRemainder() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 beneficiaryBefore = usdc.balanceOf(beneficiary);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);
        _assertRemaining(commitmentId, CANONICAL_ENTITLEMENT - uint128(EXERCISE_Q), "after one partial exercise");

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);
        _assertRemaining(commitmentId, CANONICAL_ENTITLEMENT - uint128(2 * EXERCISE_Q), "after two partial exercises");

        _authorizeAs(commitmentExerciseAuthority, commitmentId, 1);
        _assertRemaining(
            commitmentId, CANONICAL_ENTITLEMENT - uint128(2 * EXERCISE_Q) - 1, "after three partial exercises"
        );

        assertEq(
            usdc.balanceOf(beneficiary) - beneficiaryBefore,
            2 * EXERCISE_Q + 1,
            "the Beneficiary must hold exactly the sum of what was fulfilled"
        );
        assertEq(
            uint256(_commitmentRecord(commitmentId).originalEntitlement),
            uint256(CANONICAL_ENTITLEMENT),
            "no number of exercises may rewrite the admitted extent"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     G8D-C — EXACT EXHAUSTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves exercising the whole remainder leaves exactly zero and releases the whole obligation.
    /// @dev Completion is derived, not flagged. The commitment's own obligation and the service aggregate
    ///      both reach zero because they are computed from a remainder that reached zero, and the bounded
    ///      reference is deliberately still there — an exhausted commitment stops contributing without
    ///      anything being sent to clear it.
    function test_exhaustingExercise_leavesZeroRemainingAndZeroObligation() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        (bool referenced, uint256 slot) = _referenceSlotOf(commitmentId);

        assertTrue(referenced, "the admitted commitment must be referenced before it is fulfilled");

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, CANONICAL_ENTITLEMENT);

        _assertExactFulfillment(before, commitmentExerciseAuthority, commitmentId, CANONICAL_ENTITLEMENT);
        _assertRemaining(commitmentId, 0, "exact exhaustion");

        assertEq(hook.commitmentObligation(commitmentId), 0, "an exhausted commitment must carry no obligation");
        assertEq(hook.aggregateObligation(), 0, "the aggregate must release it entirely");

        _assertReferenceRetained(commitmentId, slot, "fulfillment must not clear the bounded reference");
    }

    /// @notice Proves an exhausted commitment cannot be exercised again.
    /// @dev In a later transaction, with the exerciser still funded and the service still backed. The
    ///      refusal is the ordinary extent predicate reporting a remainder of zero, which is what "complete
    ///      fulfillment is derived from `Remaining == 0`" has to mean operationally.
    function test_exhaustedCommitment_cannotBeExercisedAgain() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidExerciseExtent.selector, 1, 0));
        _authorizeAs(commitmentExerciseAuthority, commitmentId, 1);

        _assertNoExerciseResidue(before, commitmentExerciseAuthority, commitmentId);
    }

    /// @notice Proves a partially fulfilled commitment admits exactly its remainder and no more.
    /// @dev Both sides of the boundary, against the remainder a previous exercise produced rather than
    ///      against the admitted extent — which is the difference between an entitlement that was partly
    ///      used and one that was not.
    function test_partiallyFulfilledCommitment_admitsExactlyItsRemainder() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        uint128 remainder = CANONICAL_ENTITLEMENT - uint128(EXERCISE_Q);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidExerciseExtent.selector, uint256(remainder) + 1, remainder
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, uint256(remainder) + 1);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, remainder);

        _assertRemaining(commitmentId, 0, "the exact remainder must be exercisable");
    }

    /*//////////////////////////////////////////////////////////////
              G8D-B — FINAL BACKING AGAINST THE ACTUAL STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an exercise that leaves capacity exactly equal to the obligation succeeds.
    /// @dev The commitment is admitted for the whole of the service's current Supporting Capacity, taken
    ///      from the independent oracle rather than from the derivation under test, so the service sits
    ///      exactly at `S == O` before the exercise and exactly at `S == O` after it. Equality has to pass
    ///      at both the authorization comparison and the final one, and a fulfillment refused here would be
    ///      one the frozen requirement admits.
    function test_exerciseAtExactBacking_succeeds() public {
        uint128 fullyBackedEntitlement = uint128(_referenceSupportingCapacity());

        uint256 commitmentId = _establishExercisable(fullyBackedEntitlement);

        assertEq(hook.supportingCapacity(), hook.aggregateObligation(), "the service must start exactly at backing");

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertExactFulfillment(before, commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        assertEq(hook.supportingCapacity(), hook.aggregateObligation(), "the service must remain exactly at backing");
        _assertDerivationsMatchOracles("both derivations must still match their independent reconstructions");
    }

    /*//////////////////////////////////////////////////////////////
             G8D-D — ONLY THE CAUSAL O2 PATH CAN FULFIL
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a completed exercise leaves no reusable causal evidence behind.
    /// @dev The state the F8C completion barrier exists to refuse is `EXECUTED`; what a finalized exercise
    ///      leaves is the empty context, every field cleared. That is both what lets the barrier pass and
    ///      what makes the proof unusable a second time.
    function test_completedExercise_leavesNoReusableCausalEvidence() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("a finalized exercise must consume its causal proof entirely");
    }

    /// @notice Proves a direct finalization request outside any exercise fulfils nothing.
    /// @dev The Hook's finalization surface is externally reachable, and it has to be: the coordinator calls
    ///      it. Reaching it is not the same as satisfying it, and outside an exercise there is no proof to
    ///      present — for the configured router exactly as for anyone else.
    function test_directFinalizationOutsideAnExercise_fulfilsNothing() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _expectUnprovenRefusal();
        vm.prank(address(configuredExerciseRouter));
        hook.finalizeExercise(commitmentId);

        _expectUnprovenRefusal();
        vm.prank(commitmentExerciseAuthority);
        hook.finalizeExercise(commitmentId);

        _expectUnprovenRefusal();
        vm.prank(unauthorizedExerciser);
        hook.finalizeExercise(commitmentId);

        _assertNoFulfillment(before, commitmentExerciseAuthority, commitmentId, "no direct request may fulfil anything");
    }

    /// @notice Proves an ordinary swap fulfils nothing, however much protected output it produces.
    /// @dev An authoritative protected-direction transition that moves the price, consumes Supporting
    ///      Capacity, and hands an eligible trader the same currency a Beneficiary would receive. It
    ///      discharges no entitlement, because fulfillment is causal rather than a matter of the right
    ///      currency moving.
    function test_ordinarySwap_fulfilsNothing() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(EXERCISE_Q));

        assertLt(
            hook.supportingCapacity(), before.aggregateObligation + EXERCISE_Q, "the swap must have moved capacity"
        );

        _assertNoFulfillment(before, commitmentExerciseAuthority, commitmentId, "an ordinary swap must fulfil nothing");
    }

    /// @notice Proves a direct transfer of the protected currency to the Beneficiary fulfils nothing.
    /// @dev The Beneficiary ends up holding exactly what a fulfilled exercise would have delivered, from an
    ///      account willing to send it. The commitment is untouched: what discharges an entitlement is the
    ///      causally attributable O2 path, not the Beneficiary's balance.
    function test_directTransferToTheBeneficiary_fulfilsNothing() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        vm.prank(eligibleTrader);
        bool sent = usdc.transfer(beneficiary, EXERCISE_Q);

        assertTrue(sent, "the fixture must be able to pay the Beneficiary directly");
        assertEq(
            usdc.balanceOf(beneficiary) - before.beneficiaryOutput,
            EXERCISE_Q,
            "the Beneficiary must hold exactly what a fulfillment would have delivered"
        );

        _assertNoFulfillment(before, commitmentExerciseAuthority, commitmentId, "a direct transfer must fulfil nothing");
    }

    /// @notice Proves a refused exercise fulfils nothing and leaves no residue anywhere.
    /// @dev The cost bound is one raw unit below the debt the swap actually produced, so the exercise
    ///      completes authorization, execution, settlement and delivery before it fails — and then unwinds
    ///      all of it, the finalization included.
    function test_refusedExercise_fulfilsNothing() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        vm.expectRevert();
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, actualInput - 1);

        _assertNoExerciseResidue(before, commitmentExerciseAuthority, commitmentId);
    }

    /*//////////////////////////////////////////////////////////////
                G8D-E — FULFILLMENT AND DELIVERY ARE ATOMIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the exerciser's inability to pay leaves no delivery and no fulfillment.
    /// @dev The one direction of the atomicity requirement that a real failure can demonstrate on the
    ///      production path: everything up to the payment succeeded, and after the refusal there is no
    ///      delivery without fulfillment and no fulfillment without delivery — there is neither.
    function test_unpayableExercise_leavesNeitherDeliveryNorFulfillment() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _drainExerciser(commitmentExerciseAuthority);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        vm.expectRevert();
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoExerciseResidue(before, commitmentExerciseAuthority, commitmentId);
    }

    /*//////////////////////////////////////////////////////////////
                    G8D-F — CANONICAL A4 TERMINAL STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the canonical A1–A4 sequence ends in the frozen terminal state.
    /// @dev The whole reference scenario on the production stack: the canonical service starts at 80,000
    ///      Supporting Capacity, a 50,000 commitment is admitted, an ordinary backing-compatible protected
    ///      swap of 15,000 takes capacity to 65,000 without disturbing the commitment, and the Beneficiary's
    ///      full 50,000 is then exercised. The terminal relationship is the frozen one — capacity 15,000,
    ///      obligation zero, remainder zero, and exactly 50,000 delivered — and every quantity in it is read
    ///      back from authoritative state or from the independent oracles.
    function test_canonicalSequence_reachesTheFrozenTerminalState() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        assertEq(
            _referenceSupportingCapacity(),
            StandbyFixtureConfig.EXPECTED_INITIAL_S,
            "the canonical service must start at the frozen initial capacity"
        );

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT));

        assertEq(
            _referenceSupportingCapacity(),
            StandbyFixtureConfig.EXPECTED_A2_S,
            "the compatible ordinary swap must leave the frozen A2 capacity"
        );

        uint256 beneficiaryBefore = usdc.balanceOf(beneficiary);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, CANONICAL_ENTITLEMENT);

        assertEq(
            _referenceSupportingCapacity(),
            StandbyFixtureConfig.EXPECTED_A2_S - StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "A4 must terminate at 15,000 Supporting Capacity"
        );
        assertEq(hook.aggregateObligation(), 0, "A4 must terminate at zero Aggregate Capacity Obligation");
        _assertRemaining(commitmentId, 0, "A4 must terminate at zero Remaining Entitlement");
        assertEq(
            usdc.balanceOf(beneficiary) - beneficiaryBefore,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "A4 must deliver exactly 50,000 to the Beneficiary"
        );

        _assertDerivationsMatchOracles("the terminal state must match both independent reconstructions");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Expects the Hook's refusal of a finalization with no proven execution behind it.
    function _expectUnprovenRefusal() internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NoProvenExerciseToFinalize.selector,
                StandbyHook.ExerciseAuthorizationState.EMPTY
            )
        );
    }

    /// @dev Asserts a commitment's authoritative Remaining Entitlement.
    function _assertRemaining(uint256 _commitmentId, uint128 _expected, string memory _context) internal view {
        assertEq(uint256(_commitmentRecord(_commitmentId).remainingEntitlement), uint256(_expected), _context);
    }

    /// @dev Removes every unit of input currency an exerciser holds.
    function _drainExerciser(address _exerciser) internal {
        uint256 held = ustb.balanceOf(_exerciser);

        vm.prank(_exerciser);
        bool drained = ustb.transfer(address(0xdead), held);

        assertTrue(drained, "the fixture must be able to remove the exerciser's funds");
    }
}

/// @notice Integration evidence that a refused finalization unwinds the complete O2 transaction (G8D-E).
/// @dev The atomicity requirement is about what happens when finalization *fails*, and every reason it can
///      fail is one the production system cannot produce. An unbacked resulting state and a remainder
///      smaller than the proven quantity are both unreachable, because the invariant they would violate is
///      the one every earlier transition already maintains. A finalization naming the wrong commitment is
///      unreachable because the production router names the commitment its own request was for.
///
///      The configured router here is the production router with exactly that one thing changed: it names a
///      commitment chosen by the test. Everything else — the authorization, the swap, the settlement out of
///      the exerciser's account, and the direct delivery to the Beneficiary — is production code running
///      unmodified against the real PoolManager, so the exercise this suite refuses is a real one that had
///      really executed, really paid, and really delivered by the time it was refused.
///
///      What that isolates is the property on the other side of the refusal: no durable delivery without
///      fulfillment, and no durable fulfillment without delivery. Neither survives, and neither does
///      anything else the exercise had done.
contract MisdirectedFinalizationTest is BaseExerciseFinalizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The entitlement of each of the two commitments: 25,000 MockUSDC.
    ///
    ///      Two of these are admissible against the canonical initial Supporting Capacity and two canonical
    ///      entitlements are not, so the pair is chosen by what the fixture can actually back.
    uint128 internal constant PAIRED_ENTITLEMENT = 25_000_000_000;

    /// @dev The exercise quantity used throughout: 20,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 20_000_000_000;

    /// @dev The configured router, typed so its finalization target is reachable.
    MisdirectedFinalizationRouter internal misdirectingRouter;

    /*//////////////////////////////////////////////////////////////
                    G8D-E — FINALIZATION FAILURE ATOMICITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a refused finalization unwinds the swap, the payment, and the delivery with it.
    /// @dev The exercise is for the first commitment and completes every stage before finalization; the
    ///      request then names the second, and the Hook refuses it against its own causal binding. What is
    ///      asserted afterwards spans every surface the exercise had already touched: the pool price, tick
    ///      and active liquidity, the exerciser's balance, the Beneficiary's balance, the PoolManager's
    ///      balances on both currencies, both commitments' facts, the derived obligation, and the Hook's
    ///      causal context.
    function test_refusedFinalization_unwindsTheCompleteExercise() public {
        uint256 exercisedCommitmentId = _establishExercisable(PAIRED_ENTITLEMENT);
        uint256 namedCommitmentId = _establishExercisable(PAIRED_ENTITLEMENT);

        misdirectingRouter.setFinalizationTarget(namedCommitmentId);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, exercisedCommitmentId);
        StandbyHook.Commitment memory namedBefore = _commitmentRecord(namedCommitmentId);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotTheProvenExerciseCommitment.selector,
                namedCommitmentId,
                exercisedCommitmentId
            )
        );
        _authorizeAs(commitmentExerciseAuthority, exercisedCommitmentId, EXERCISE_Q);

        _assertNoExerciseResidue(before, commitmentExerciseAuthority, exercisedCommitmentId);
        _assertCommitmentFactsUnchanged(
            namedCommitmentId, namedBefore, "the named commitment must not be fulfilled either"
        );
    }

    /// @notice Proves the same exercise commits once the finalization request names the right commitment.
    /// @dev The control. Nothing about the request, the fixture, the funding, or the router changes except
    ///      which commitment the finalization names — so the refusal above is attributable to the
    ///      misdirection and to nothing else in the setup.
    function test_correctlyDirectedFinalization_commitsTheSameExercise() public {
        uint256 exercisedCommitmentId = _establishExercisable(PAIRED_ENTITLEMENT);

        _establishExercisable(PAIRED_ENTITLEMENT);

        misdirectingRouter.setFinalizationTarget(exercisedCommitmentId);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, exercisedCommitmentId);

        _authorizeAs(commitmentExerciseAuthority, exercisedCommitmentId, EXERCISE_Q);

        _assertExactFulfillment(before, commitmentExerciseAuthority, exercisedCommitmentId, EXERCISE_Q);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Activates the service with the production router whose finalization request is misdirectable.
    function _resolveExerciseRouter() internal override returns (address router) {
        misdirectingRouter = new MisdirectedFinalizationRouter(hook);

        configuredExerciseRouter = misdirectingRouter;

        router = address(configuredExerciseRouter);
    }
}
