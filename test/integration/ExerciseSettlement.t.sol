// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";
import {MockFixtureCurrency} from "../../src/mocks/MockFixtureCurrency.sol";

import {BaseExerciseSettlementTest} from "../shared/BaseExerciseSettlementTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for F8C authoritative settlement and direct Beneficiary delivery on the
///         real execution stack (G8C-1, G8C-2, G8C-5 through G8C-13, G8C-16 through G8C-18).
/// @dev Every exercise here is authorized by the production Hook, executed by the real pinned
///      `PoolManager` against a real pool holding real liquidity, for a commitment the production O1
///      transition admitted, and settled and delivered by the production R4 code. Nothing about the debt,
///      the payment, or the delivery is seeded, quoted, or estimated: the amount that moves is the amount
///      the pool actually charged, and the account it moves to is the one the Hook resolved from the
///      commitment record.
///
///      One thing is not production: the configured router's completion barrier is lifted, because a
///      production exercise deliberately refuses to return while its causal proof is unconsumed and would
///      therefore unwind the very settlement these tests measure. That barrier is verified against the
///      production router in `ProductionExerciseCompletionTest` below, and nothing here may be read as
///      evidence that a production O2 completes.
contract ExerciseSettlementTest is BaseExerciseSettlementTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /// @dev The exercise quantity used wherever the test is not about the quantity: 20,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 20_000_000_000;

    /*//////////////////////////////////////////////////////////////
           G8C-1, G8C-2, G8C-7 THROUGH G8C-13 — EXACT RESOLUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an exercise pays the exact debt from the exerciser and delivers exactly `q` to the
    ///         Beneficiary, with no intermediate custody anywhere.
    /// @dev The canonical positive case, end to end on the real stack. The debt is the one production
    ///      itself reports for this exact swap, so the equality asserted is against authoritative
    ///      accounting rather than against a reconstruction; every currency movement is then required to
    ///      match on both sides at once — what left the exerciser is what reached the PoolManager, and what
    ///      left the PoolManager is what reached the Beneficiary.
    ///
    ///      The router holds a large balance of both currencies throughout and the Hook holds none, which
    ///      is what makes "the router could have paid and did not" and "nothing passed through either of
    ///      them" observable rather than assumed.
    function test_authorizedExercise_settlesExactlyAndDeliversDirectly() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        assertGt(before.routerInput, actualInput, "the router must be able to pay, so that not paying is a choice");

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertExactSettlementAndDelivery(before, commitmentExerciseAuthority, commitmentId, EXERCISE_Q, actualInput);
    }

    /// @notice Proves the authoritative debt is what the pool charged, not what was requested or bounded.
    /// @dev Three numbers that a wrong implementation would confuse: the quantity the request named, the
    ///      cost bound it carried, and the debt the swap produced. The exerciser pays the third, and it is
    ///      neither of the first two — an exact-output exercise for `q` costs more than `q` at a fee-bearing
    ///      pool moving against the buyer, and the bound here is the whole `uint256` domain.
    function test_settlementAmount_isTheAuthoritativeDebtRatherThanTheRequest() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        assertGt(actualInput, EXERCISE_Q, "an exact-output exercise must cost more than the quantity it produces");
        assertLt(actualInput, UNCONSTRAINED_MAX_INPUT, "the cost bound must not be what is settled");

        uint256 fundedBefore = ustb.balanceOf(commitmentExerciseAuthority);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        assertEq(
            fundedBefore - ustb.balanceOf(commitmentExerciseAuthority),
            actualInput,
            "exactly the authoritative debt must be settled"
        );
    }

    /*//////////////////////////////////////////////////////////////
                       G8C-5 — EXACT COST BOUND
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a cost bound exactly equal to the authoritative debt is accepted.
    /// @dev The boundary that must not be off by one in the safe direction. `maxInput` is the most the
    ///      exerciser is willing to pay, so paying exactly that much is within the bound.
    function test_costBoundEqualToTheDebt_isAccepted() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, actualInput);

        _assertExactSettlementAndDelivery(before, commitmentExerciseAuthority, commitmentId, EXERCISE_Q, actualInput);
    }

    /// @notice Proves a cost bound one raw unit above the authoritative debt is accepted.
    function test_costBoundAboveTheDebt_isAccepted() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, actualInput + 1);

        _assertExactSettlementAndDelivery(before, commitmentExerciseAuthority, commitmentId, EXERCISE_Q, actualInput);
    }

    /// @notice Proves a cost bound one raw unit below the authoritative debt unwinds the whole exercise.
    /// @dev The refusal is reported against the debt production derived rather than against anything the
    ///      request supplied, and it takes the swap down with it: after it, the pool is exactly where it
    ///      was, nobody has paid, nobody has been delivered to, and no causal context survives that a later
    ///      attempt could build on.
    function test_costBoundBelowTheDebt_unwindsTheWholeExercise() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        vm.expectRevert(
            abi.encodeWithSelector(
                ExerciseRouter.ExerciseRouter__ExerciseCostExceedsMaxInput.selector, actualInput, actualInput - 1
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, actualInput - 1);

        _assertNoExerciseResidue(before, commitmentExerciseAuthority, commitmentId);
    }

    /*//////////////////////////////////////////////////////////////
                 G8C-6 — COST-PROTECTION ISOLATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the cost bound leaves no trace in any authoritative Standby state.
    /// @dev The tightest bound an exercise can carry is the exact debt, so if the field were going to reach
    ///      economic state anywhere this is the request that would show it. The causal context afterwards
    ///      carries exactly the seven bindings authorization resolved and no eighth, the commitment record
    ///      is untouched in every field, and both derived quantities are what the execution alone accounts
    ///      for — the bound changed the exercise's admissibility and nothing about its economics.
    function test_costBound_leavesNoTraceInAuthoritativeState() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);

        uint256 predictedCapacity =
            hook.prospectiveSupportingCapacityAfterSwap(_protectedExactOutputSwapParams(EXERCISE_Q));
        uint256 obligationBefore = hook.aggregateObligation();

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, actualInput);

        _assertExercisedContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "the cost bound must appear in no causal binding"
        );
        _assertCommitmentFactsUnchanged(commitmentId, admitted, "the cost bound must reach no commitment fact");

        assertEq(hook.aggregateObligation(), obligationBefore, "the cost bound must not move the obligation");
        assertEq(hook.supportingCapacity(), predictedCapacity, "capacity must be what the execution alone accounts for");
    }

    /*//////////////////////////////////////////////////////////////
                  G8C-11, G8C-12 — AUTHORITATIVE RECIPIENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves delivery follows the exercised commitment's own Beneficiary.
    /// @dev Two commitments exist with different Beneficiaries and one exercise authority between them. The
    ///      request names only the commitment and the quantity, so the recipient is decided entirely by
    ///      which commitment was exercised — and the other Beneficiary receives nothing.
    function test_delivery_followsTheExercisedCommitmentsBeneficiary() public {
        (uint256 firstCommitmentId,) = _establishTwoBeneficiaries();

        uint256 secondBeneficiaryBefore = usdc.balanceOf(secondBeneficiary);
        uint256 beneficiaryBefore = usdc.balanceOf(beneficiary);

        _authorizeAs(commitmentExerciseAuthority, firstCommitmentId, EXERCISE_Q);

        assertEq(
            usdc.balanceOf(beneficiary) - beneficiaryBefore,
            EXERCISE_Q,
            "the exercised commitment's Beneficiary must receive exactly q"
        );
        assertEq(usdc.balanceOf(secondBeneficiary), secondBeneficiaryBefore, "no other Beneficiary may receive");
    }

    /// @notice Proves the same request against the other commitment delivers to the other Beneficiary.
    /// @dev The complement, and the reason the first test is about the Beneficiary rather than about a
    ///      constant. Nothing in the request changes except which commitment it names.
    function test_delivery_followsTheOtherCommitmentsBeneficiary() public {
        (, uint256 secondCommitmentId) = _establishTwoBeneficiaries();

        uint256 secondBeneficiaryBefore = usdc.balanceOf(secondBeneficiary);
        uint256 beneficiaryBefore = usdc.balanceOf(beneficiary);

        _authorizeAs(commitmentExerciseAuthority, secondCommitmentId, EXERCISE_Q);

        assertEq(
            usdc.balanceOf(secondBeneficiary) - secondBeneficiaryBefore,
            EXERCISE_Q,
            "the exercised commitment's Beneficiary must receive exactly q"
        );
        assertEq(usdc.balanceOf(beneficiary), beneficiaryBefore, "no other Beneficiary may receive");
    }

    /*//////////////////////////////////////////////////////////////
            G8C-16, G8C-17 — NO FULFILLMENT, NO NEW LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a settled and delivered exercise still fulfils nothing.
    /// @dev The whole F8C boundary in one assertion set. Value has moved in both directions and the
    ///      Beneficiary has been paid, and yet Remaining Entitlement, the admitted extent, the aggregate
    ///      obligation, and every other admitted commitment fact are exactly what they were — because
    ///      reducing them is finalization's, and finalization does not exist.
    function test_settledAndDeliveredExercise_fulfilsNothing() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoFulfillmentConsequence(
            before, commitmentExerciseAuthority, commitmentId, "settlement and delivery must fulfil nothing"
        );
        _assertCommitmentFactsUnchanged(commitmentId, admitted, "settlement must touch no commitment fact");
    }

    /// @notice Proves the causal context is exactly where execution left it after settlement and delivery.
    /// @dev No `SETTLED`, no `DELIVERED`, and no consumption: R4 resolves the deltas of the execution the
    ///      Hook already proved, and says nothing new about it. The bindings are still the ones
    ///      authorization resolved, which is what a later finalization must be able to rely on.
    function test_causalContext_remainsExecutedAfterSettlementAndDelivery() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertExercisedContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "settlement and delivery must leave the causal context exactly EXECUTED"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    G8C-15 — ONE RESOLUTION SEQUENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a settled exercise cannot be settled or delivered a second time.
    /// @dev The second request is fully qualified on its own terms — the same authority, the same
    ///      commitment, a quantity well within the remainder, and a service that is still backed. It is
    ///      refused because the causal context of the first exercise is unresolved, and the Beneficiary is
    ///      paid exactly once.
    function test_secondExerciseAfterSettlement_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 beneficiaryBefore = usdc.balanceOf(beneficiary);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        vm.expectRevert(StandbyHook.StandbyHook__ExerciseAuthorizationAlreadyActive.selector);
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        assertEq(usdc.balanceOf(beneficiary) - beneficiaryBefore, EXERCISE_Q, "exactly one delivery may occur");
    }

    /*//////////////////////////////////////////////////////////////
                     G8C-18 — PAYMENT FAILURE ATOMICITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an exerciser who cannot pay unwinds the whole exercise.
    /// @dev The commitment is authentic, the authorization passes, and the swap executes — and then the
    ///      settlement transfer fails because the exerciser holds nothing. The router is holding far more
    ///      than the debt at that moment and none of it is used, which is the point: an exerciser who
    ///      cannot pay is a failed exercise, not a router-funded one.
    function test_exerciserWithoutFunds_unwindsTheWholeExercise() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _drainExerciser(commitmentExerciseAuthority);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        assertGt(before.routerInput, actualInput, "the router must be holding more than the debt it must not pay");

        vm.expectRevert(
            abi.encodeWithSelector(
                MockFixtureCurrency.MockFixtureCurrency__InsufficientBalance.selector,
                commitmentExerciseAuthority,
                0,
                actualInput
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoExerciseResidue(before, commitmentExerciseAuthority, commitmentId);
    }

    /// @notice Proves an insufficient allowance unwinds the whole exercise.
    /// @dev The exerciser is funded and the debt is affordable; only the amount the router was permitted to
    ///      coordinate is one raw unit short. Allowance is how the router coordinates a payment it never
    ///      holds, so an insufficient one is a failure to settle rather than an invitation to settle less.
    function test_insufficientAllowance_unwindsTheWholeExercise() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _approveExerciser(commitmentExerciseAuthority, actualInput - 1);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        vm.expectRevert(
            abi.encodeWithSelector(
                MockFixtureCurrency.MockFixtureCurrency__InsufficientAllowance.selector,
                commitmentExerciseAuthority,
                address(configuredExerciseRouter),
                actualInput - 1,
                actualInput
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoExerciseResidue(before, commitmentExerciseAuthority, commitmentId);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Admits two backed commitments with different Beneficiaries under one exercise authority.
    function _establishTwoBeneficiaries() internal returns (uint256 firstCommitmentId, uint256 secondCommitmentId) {
        uint128 entitlement = uint128(EXERCISE_Q);

        firstCommitmentId = _establishExercisable(entitlement);

        secondCommitmentId = _establishAs(
            establishmentAuthority,
            secondBeneficiary,
            commitmentExerciseAuthority,
            entitlement,
            uint64(block.timestamp),
            uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION
        );
    }

    /// @dev Removes every unit of input currency an exerciser holds.
    function _drainExerciser(address _exerciser) internal {
        uint256 held = ustb.balanceOf(_exerciser);

        vm.prank(_exerciser);
        bool drained = ustb.transfer(address(0xdead), held);

        assertTrue(drained, "the fixture must be able to remove the exerciser's funds");
    }
}

/// @notice Integration evidence that the production exercise path stays fail-closed until finalization
///         exists (G8C-19).
/// @dev The only difference from the fixture above is the one that matters: the configured ExerciseRouter
///      is the production `ExerciseRouter`, with its completion barrier intact. Everything else is
///      identical — the same Hook, the same pool, the same liquidity, the same production commitment, the
///      same funded and approved exerciser, and the same request.
///
///      What that isolates is the barrier itself. The exercise gets all the way through authorization,
///      execution, settlement, and delivery, and is then refused for the one thing that has not happened:
///      nothing consumed the causal proof. Because the proof is transaction-scoped, committing here would
///      leave a paid exerciser, a paid Beneficiary, an unreduced entitlement, and no surviving evidence
///      that any of it happened — so the whole exercise unwinds instead.
contract ProductionExerciseCompletionTest is BaseExerciseSettlementTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /// @dev The exercise quantity used throughout: 20,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 20_000_000_000;

    /*//////////////////////////////////////////////////////////////
                   G8C-19 — SLICE-COMPLETION SAFETY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a production exercise cannot commit while its causal proof is unconsumed.
    /// @dev The refusal names the position the context was actually left in, which is what makes it a
    ///      completion condition rather than a placeholder: `EXECUTED` is exactly the state finalization
    ///      will consume, and consuming it is what will let this same requirement pass.
    function test_productionExercise_cannotCompleteWhileUnfinalized() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        vm.expectRevert(
            abi.encodeWithSelector(
                ExerciseRouter.ExerciseRouter__ExerciseNotFinalized.selector,
                StandbyHook.ExerciseAuthorizationState.EXECUTED
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoExerciseResidue(before, commitmentExerciseAuthority, commitmentId);
    }

    /// @notice Proves the refusal survives every request shape a caller could try.
    /// @dev A generous cost bound, an exact one, and a whole-remainder quantity are all refused identically.
    ///      The barrier is not about the request and cannot be routed around by making the request better.
    function test_productionExercise_isRefusedWhateverTheRequest() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _expectUnfinalizedRefusal();
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, UNCONSTRAINED_MAX_INPUT);

        _expectUnfinalizedRefusal();
        _authorizeAs(commitmentExerciseAuthority, commitmentId, CANONICAL_ENTITLEMENT, UNCONSTRAINED_MAX_INPUT);

        _expectUnfinalizedRefusal();
        _authorizeAs(commitmentExerciseAuthority, commitmentId, 1, UNCONSTRAINED_MAX_INPUT);

        _assertNoExerciseResidue(before, commitmentExerciseAuthority, commitmentId);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Activates the service with the production router, completion barrier intact.
    function _resolveExerciseRouter() internal override returns (address router) {
        configuredExerciseRouter = new ExerciseRouter(hook);

        router = address(configuredExerciseRouter);
    }

    /// @dev Expects the production completion barrier's refusal of an unfinalized exercise.
    function _expectUnfinalizedRefusal() internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                ExerciseRouter.ExerciseRouter__ExerciseNotFinalized.selector,
                StandbyHook.ExerciseAuthorizationState.EXECUTED
            )
        );
    }
}
