// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseUnbackedExerciseAuthorizationTest} from "../shared/BaseUnbackedExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Focused fuzz evidence for the F8A prospective-exercise backing boundary (G8A-8).
/// @dev The property under test is the F8A backing claim stated as a biconditional: an exercise is
///      authorized if and only if the Supporting Capacity the protected execution would leave still covers
///      the Aggregate Capacity Obligation a complete successful exercise would leave.
///
///      Both sides of the comparison are supplied independently on every run. The obligation is
///      reconstructed by `ReferenceCalculations` from the persisted commitment facts; the prospective
///      capacity is stated from the frozen canonical geometry rather than obtained from the derivation
///      under test, because the canonical position spans the whole service domain as one constant-liquidity
///      interval — so an exact-output protected exercise of `q` draws exactly `q` out of the
///      capacity-bearing region, and everything the domain can still deliver once `q` exceeds it, since the
///      exercise is bounded by the protected boundary itself.
///
///      The reachable system maintains `S >= O` on every authoritative transition, and inside that geometry
///      the comparison then reduces to `S >= O` as well, so the refusing side of this boundary is not
///      reachable through production paths. The obligation is therefore harness-written, which is the only
///      harness contribution here and is evidence about this comparison alone: the commitment is authentic,
///      the pool is real, the capacity is authentic, and the authorization travels the real router path.
///
///      Generated obligations are biased toward the decision boundary, because an off-by-one or an
///      inclusive/exclusive slip would live within a few raw units of exact sufficiency.
contract ExerciseBackingFuzzTest is BaseUnbackedExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Upper bound on a fuzzed obligation. Well beyond anything the canonical pool can back, so runs
    ///      reach far into the refusing region as well as sitting on the boundary.
    uint256 internal constant MAX_FUZZED_REMAINING = 200_000 * 10 ** 6;

    /// @dev The widest deliberate miss, in raw protected-output units, when a run aims at the boundary.
    int256 internal constant MAX_BOUNDARY_NUDGE = 3;

    /*//////////////////////////////////////////////////////////////
                        BACKING DECISION BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice An exercise is authorized exactly when the complete successful exercise stays backed.
    /// @dev Every other predicate holds on every run — the configured router, the authenticated authority,
    ///      an open window, an eligible Beneficiary, and `0 < q <= Remaining` — so the only decision left is
    ///      the backing comparison. A refused run must name the exact independently predicted pair, and must
    ///      leave the obligation, the remainder, and the causal context untouched.
    ///
    ///      An authorized run whose quantity exceeds what the pool can deliver before `P_Q` is refused on
    ///      the other side of the operation, by the execution evidence rather than by the backing
    ///      comparison, and that distinction is asserted rather than smoothed over. Such a run exists only
    ///      because the harness wrote an obligation the pool never backed: inside a reachable state
    ///      `S >= O >= q` holds, so the exact-output execution always produces exactly `q`. Here it produces
    ///      everything the domain has and no more, which is a partial individual exercise, and RR-O2-9
    ///      makes that a failure of the complete O2 rather than a smaller exercise. That the run reaches the
    ///      execution rejection at all is itself evidence that its authorization was admitted.
    function testFuzz_authorization_isAdmittedExactlyWhenTheCompleteExerciseStaysBacked(
        uint256 _remainingSeed,
        uint256 _qSeed,
        bool _aimAtBoundary,
        int8 _nudgeSeed
    ) public {
        uint256 commitmentId = _establishExercisable(1);

        uint256 capacity = _referenceSupportingCapacity();

        uint128 remaining = _boundedRemaining(_remainingSeed, _aimAtBoundary, _nudgeSeed, capacity);

        _writeRemainingEntitlement(commitmentId, remaining);

        uint256 obligation = _referenceAggregateObligation();

        assertEq(obligation, uint256(remaining), "the single live commitment is the whole obligation");

        uint256 q = _bound(_qSeed, 1, uint256(remaining));

        uint256 expectedProspective = q >= capacity ? 0 : capacity - q;
        uint256 prospectiveObligation = obligation - q;

        if (expectedProspective >= prospectiveObligation) {
            if (q > capacity) {
                _expectHookRejection(
                    IHooks.afterSwap.selector,
                    abi.encodeWithSelector(
                        StandbyHook.StandbyHook__ProtectedOutputNotExecuted.selector, int256(capacity), q
                    )
                );
                _authorizeAs(commitmentExerciseAuthority, commitmentId, q);

                _assertNoAuthorizationContext("an undeliverable exercise must leave no causal context");
            } else {
                _authorizeAs(commitmentExerciseAuthority, commitmentId, q);

                _assertExercisedContext(
                    commitmentId, commitmentExerciseAuthority, beneficiary, q, "a backed exercise must be authorized"
                );
            }
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    StandbyHook.StandbyHook__InsufficientProspectiveExerciseBacking.selector,
                    expectedProspective,
                    prospectiveObligation
                )
            );
            _authorizeAs(commitmentExerciseAuthority, commitmentId, q);

            _assertNoAuthorizationContext("an unbacked exercise must leave no causal context");
        }

        assertEq(hook.aggregateObligation(), obligation, "authorization must not reduce the obligation");
        assertEq(
            hook.commitment(commitmentId).remainingEntitlement,
            remaining,
            "authorization must not reduce Remaining Entitlement"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Bounds a fuzzed remainder, optionally aiming it at the decision boundary.
    ///
    ///      Exact sufficiency sits at a remainder equal to present Supporting Capacity, so a boundary run
    ///      lands within a few raw units of the decision on either side of it. This chooses an input to
    ///      explore; the expected outcome is computed afterwards from the independent expectation, so an
    ///      imprecise aim costs coverage and can never make a run pass.
    function _boundedRemaining(uint256 _remainingSeed, bool _aimAtBoundary, int8 _nudgeSeed, uint256 _capacity)
        internal
        pure
        returns (uint128 remaining)
    {
        if (!_aimAtBoundary) return uint128(_bound(_remainingSeed, 1, MAX_FUZZED_REMAINING));

        int256 aimed = int256(_capacity) + bound(int256(_nudgeSeed), -MAX_BOUNDARY_NUDGE, MAX_BOUNDARY_NUDGE);

        remaining = aimed < int256(1) ? 1 : uint128(uint256(aimed));
    }
}
