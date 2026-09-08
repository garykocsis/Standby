// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseExerciseAuthorizationTest} from "../shared/BaseExerciseAuthorizationTest.t.sol";
import {BaseUnbackedExerciseAuthorizationTest} from "../shared/BaseUnbackedExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for F8B O2 execution classification and execution evidence on the real
///         execution stack (G8B-1, G8B-3 through G8B-5, G8B-8 through G8B-11, G8B-13, G8B-14, G8B-18).
/// @dev Every execution here is performed by the real pinned `PoolManager` against a real pool holding real
///      liquidity, for a commitment the production O1 transition admitted, through the production
///      authorization and the production execution coordination. Nothing about the classification decision
///      or the execution evidence is seeded.
///
///      One thing is not production: the deltas the swap opens are closed mechanically by the fixture's
///      delta-closure router, because input settlement and Beneficiary delivery are F8C's and no production
///      path can close them yet. That closure is accounting plumbing and carries no economics — which these
///      tests assert rather than assume, by checking that the Beneficiary receives nothing, that the Hook
///      takes custody of nothing, and that no Remaining Entitlement or obligation moves.
///
///      The predicted-versus-actual evidence deliberately compares three quantities that were produced
///      three different ways: the F5 prospective derivation's prediction, taken before the execution; the
///      production derivation over the pool the execution actually left; and the independent
///      `ReferenceCalculations` reconstruction over that same actual state. A prediction that were merely
///      close would authorize exercises against a state that never existed.
contract ProtectedExecutionTest is BaseExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /// @dev The exercise quantity used wherever the test is not about the quantity: 20,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 20_000_000_000;

    /// @dev The Supporting Capacity the canonical exercise leaves: 80,000 - 20,000 MockUSDC.
    uint256 internal constant EXPECTED_POST_EXECUTION_S = 60_000_000_000;

    /*//////////////////////////////////////////////////////////////
              G8B-1, G8B-8, G8B-9 — AUTHORIZED EXECUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an authorized exercise executes exactly `q` and records exactly that as evidence.
    /// @dev The canonical positive case, end to end on the real stack. The causal context reaches
    ///      `EXECUTED` with every binding authorization resolved still intact, and the pool genuinely
    ///      produced `q` of the protected output currency — which is checked against the currency that
    ///      actually left the PoolManager rather than against the amount that was requested.
    function test_authorizedExercise_executesExactlyQAndRecordsEvidence() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 producedBefore = usdc.balanceOf(address(configuredExerciseRouter));

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertExercisedContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "the executed context must carry exactly the authorized bindings"
        );

        assertEq(
            usdc.balanceOf(address(configuredExerciseRouter)) - producedBefore,
            EXERCISE_Q,
            "the pool must actually have produced exactly the authorized protected output"
        );
    }

    /// @notice Proves execution evidence changes no commitment state and delivers nothing.
    /// @dev `EXECUTED` means the authorized swap happened, and deliberately nothing more. The input debt
    ///      was closed by test plumbing rather than settled, no cost bound was enforced, the Beneficiary
    ///      received nothing, Remaining Entitlement is untouched, and the authoritative obligation is
    ///      exactly what it was — so nothing here may be read as settlement, delivery, or fulfillment.
    function test_executionEvidence_fulfilsNothing() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        StandbyHook.Commitment memory admitted = hook.commitment(commitmentId);

        uint256 beneficiaryBefore = usdc.balanceOf(beneficiary);
        uint256 hookBefore = usdc.balanceOf(address(hook));
        uint256 obligationBefore = hook.aggregateObligation();

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertCommitmentFactsUnchanged(commitmentId, admitted, "execution must touch no commitment fact");

        assertEq(
            hook.commitment(commitmentId).remainingEntitlement,
            CANONICAL_ENTITLEMENT,
            "execution evidence must not reduce Remaining Entitlement"
        );
        assertEq(hook.aggregateObligation(), obligationBefore, "execution evidence must not reduce the obligation");
        assertEq(usdc.balanceOf(beneficiary), beneficiaryBefore, "execution evidence is not Beneficiary delivery");
        assertEq(usdc.balanceOf(address(hook)), hookBefore, "the Hook must take custody of no protected output");
    }

    /*//////////////////////////////////////////////////////////////
                   G8B-13 — PREDICTED VERSUS ACTUAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the F5 prediction the authorization was decided on is the state the pool reached.
    /// @dev Three independently produced quantities are required to agree: the prospective Supporting
    ///      Capacity derived before the execution from the canonical protected execution, the production
    ///      derivation over the pool the execution actually left, and the independent reconstruction over
    ///      that same actual state. The frozen fixture expectation pins the value itself, so agreement
    ///      cannot be agreement on a wrong number.
    ///
    ///      Active liquidity is asserted unchanged as well, because equal capacity at unequal liquidity
    ///      would mean the price landed somewhere else.
    function test_executedExercise_reachesTheF5PredictedPostState() public {
        _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 predictedCapacity =
            hook.prospectiveSupportingCapacityAfterSwap(_protectedExactOutputSwapParams(EXERCISE_Q));

        (,, uint128 liquidityBefore) = _servicePoolState();

        assertEq(predictedCapacity, EXPECTED_POST_EXECUTION_S, "the prediction must be the frozen expectation");

        _authorizeAs(commitmentExerciseAuthority, 1, EXERCISE_Q);

        (uint160 sqrtPriceAfter,, uint128 liquidityAfter) = _servicePoolState();

        assertEq(hook.supportingCapacity(), predictedCapacity, "the actual post-state must be the predicted one");
        assertEq(
            _referenceSupportingCapacity(),
            predictedCapacity,
            "the independent reconstruction of the actual post-state must agree"
        );
        assertEq(liquidityAfter, liquidityBefore, "the execution must not have crossed a liquidity boundary");
        assertLt(sqrtPriceAfter, uint160(1) << 96, "the protected execution must have moved the price down");
    }

    /*//////////////////////////////////////////////////////////////
                      G8B-4, G8B-18 — O2 / O3 EXCLUSION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves ordinary swaps keep their ordinary O3 treatment when no O2 operation is in progress.
    /// @dev Both halves, against an authentic positive obligation: a backed ordinary swap is admitted, and
    ///      a backing-destructive one is refused by the ordinary comparison rather than by anything the
    ///      execution classifier introduced. Existence of an O2 path may not weaken O3.
    function test_ordinarySwaps_keepTheirO3TreatmentWithoutAnO2Context() public {
        _establishExercisable(CANONICAL_ENTITLEMENT);

        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT));

        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_A2_S, "the ordinary swap was ordinary");

        _expectBackingRejection(
            IHooks.beforeSwap.selector,
            StandbyFixtureConfig.EXPECTED_A2_S - StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT));
    }

    /// @notice Proves an ordinary swap cannot proceed while an O2 causal context is unresolved.
    /// @dev The swap used here is one the ordinary O3 rule would admit without hesitation — a backed,
    ///      eligible, correctly routed protected swap. It is refused anyway, because the service is inside
    ///      an O2 operation whose authorization was decided against `S' >= O - q` rather than `S' >= O`.
    ///      Letting it through would enforce the wrong rule against the wrong state.
    function test_ordinarySwap_whileAnO2ContextIsUnresolved_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ExerciseExecutionNotAuthorized.selector,
                StandbyHook.ExerciseAuthorizationState.EXECUTED
            )
        );
        _swapAs(eligibleTrader, _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT));
    }

    /*//////////////////////////////////////////////////////////////
                       G8B-11 — EXACTLY ONE EXERCISE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves execution evidence cannot be reused by a second exercise in the same transaction.
    /// @dev The second request is fully qualified on its own terms — the same authority, the same
    ///      commitment, a quantity well within the remainder, and a service that is still backed. It is
    ///      refused because the causal context of the first exercise is unresolved, which is the single
    ///      restriction that covers a second authorization, a second execution, and an overwrite alike.
    function test_secondExercise_againstAnUnresolvedContext_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        vm.expectRevert(StandbyHook.StandbyHook__ExerciseAuthorizationAlreadyActive.selector);
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertExercisedContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "a refused second exercise must not disturb the standing evidence"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     G8B-9 — EXACT EXECUTION EXTENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an exercise of exactly the Supporting Capacity executes exactly.
    /// @dev The boundary the qualification price limit creates. An exact-output execution for the whole of
    ///      Supporting Capacity lands exactly on `P_Q` and produces exactly `q`, leaving no capacity behind
    ///      — which is an ordinary valid state, not a failure. One raw unit more would be undeliverable,
    ///      and the fuzzed backing evidence covers that side.
    function test_exerciseOfTheWholeSupportingCapacity_executesExactly() public {
        uint128 entitlement = uint128(StandbyFixtureConfig.EXPECTED_INITIAL_S);

        uint256 commitmentId = _establishExercisable(entitlement);

        uint256 producedBefore = usdc.balanceOf(address(configuredExerciseRouter));

        _authorizeAs(commitmentExerciseAuthority, commitmentId, entitlement);

        _assertExercisedContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, entitlement, "exact capacity must execute exactly"
        );

        assertEq(
            usdc.balanceOf(address(configuredExerciseRouter)) - producedBefore,
            uint256(entitlement),
            "the pool must have produced the whole authorized quantity"
        );
        assertEq(hook.supportingCapacity(), 0, "the execution must land exactly on the qualification boundary");
    }
}

/// @notice Integration evidence that a failed protected execution unwinds the whole exercise (G8B-9,
///         G8B-10, G8B-12).
/// @dev The failing execution has to be a real one, and reaching it requires a state the production system
///      maintains against: a commitment whose Remaining Entitlement exceeds what the pool can deliver
///      before `P_Q`. `S >= O >= q` holds on every reachable path, so the remainder is harness-written —
///      the same harness contribution the F8A backing evidence already rests on — and everything else is
///      authentic: the pool, the liquidity, the commitment, the authorization, the router, and the swap.
///
///      What that buys is the one case RR-O2-9 legislates for. The authorization passes, the PoolManager
///      performs the swap, and the swap produces everything the domain has rather than the `q` that was
///      requested. A partial individual exercise is a failure of the complete O2, so the containing
///      transaction reverts — and with it the authorization, the execution marker, and the swap itself.
contract ProtectedExecutionFailureTest is BaseUnbackedExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev An authentically admissible entitlement: 20,000 MockUSDC.
    uint128 internal constant ADMITTED_ENTITLEMENT = 20_000_000_000;

    /// @dev A remainder the canonical pool cannot deliver: 120,000 MockUSDC against 80,000 of capacity.
    uint128 internal constant UNDELIVERABLE_REMAINING = 120_000_000_000;

    /*//////////////////////////////////////////////////////////////
                    FAILED EXECUTION ATOMICITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a partial actual output cannot produce execution evidence.
    /// @dev The request is for `q` and the pool produces less, which Uniswap treats as an ordinary
    ///      successful swap. Standby does not: the evidence comparison is exact, so the swap is refused
    ///      after it has already executed and the PoolManager unwinds it.
    function test_partialActualOutput_cannotProduceExecutionEvidence() public {
        uint256 commitmentId = _establishExercisable(ADMITTED_ENTITLEMENT);

        _writeRemainingEntitlement(commitmentId, UNDELIVERABLE_REMAINING);

        uint256 deliverable = _referenceSupportingCapacity();

        assertLt(deliverable, UNDELIVERABLE_REMAINING, "the fixture must be asking for more than the pool holds");

        _expectHookRejection(
            IHooks.afterSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProtectedOutputNotExecuted.selector,
                int256(deliverable),
                uint256(UNDELIVERABLE_REMAINING)
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, UNDELIVERABLE_REMAINING);
    }

    /// @notice Proves a failed protected execution leaves nothing behind and cannot be continued.
    /// @dev The production ExerciseRouter has no failure branch: the PoolManager call is not caught, so a
    ///      failed execution propagates out of `exercise` and unwinds the authorization that preceded it
    ///      along with the swap. That matters because the execution marker is transaction-scoped — a router
    ///      that caught the failure would find the context restored to AUTHORIZED and could execute against
    ///      it again. This one cannot: after the failure there is no context at all, the pool is exactly
    ///      where it was, and the next exercise in the very same transaction is a fresh authorization
    ///      subject to every predicate again.
    function test_failedExecution_unwindsTheExerciseAndCannotBeRetried() public {
        uint256 commitmentId = _establishExercisable(ADMITTED_ENTITLEMENT);

        _writeRemainingEntitlement(commitmentId, UNDELIVERABLE_REMAINING);

        (uint160 sqrtPriceBefore, int24 tickBefore, uint128 liquidityBefore) = _servicePoolState();

        vm.expectRevert();
        _authorizeAs(commitmentExerciseAuthority, commitmentId, UNDELIVERABLE_REMAINING);

        _assertNoAuthorizationContext("a failed execution must leave no causal context");

        (uint160 sqrtPriceAfter, int24 tickAfter, uint128 liquidityAfter) = _servicePoolState();

        assertEq(sqrtPriceAfter, sqrtPriceBefore, "a failed execution must leave the pool price untouched");
        assertEq(tickAfter, tickBefore, "a failed execution must leave the pool tick untouched");
        assertEq(liquidityAfter, liquidityBefore, "a failed execution must leave active liquidity untouched");
        assertEq(
            hook.commitment(commitmentId).remainingEntitlement,
            UNDELIVERABLE_REMAINING,
            "a failed execution must fulfil nothing"
        );

        vm.expectRevert();
        _authorizeAs(commitmentExerciseAuthority, commitmentId, UNDELIVERABLE_REMAINING);

        _assertNoAuthorizationContext("a repeated attempt must gain nothing from the failed one");

        _writeRemainingEntitlement(commitmentId, ADMITTED_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, ADMITTED_ENTITLEMENT);

        _assertExercisedContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            ADMITTED_ENTITLEMENT,
            "the next exercise must be a fresh authorization rather than a continuation"
        );
    }
}
