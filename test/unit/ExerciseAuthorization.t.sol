// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {PoolId} from "v4-core/types/PoolId.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseUnbackedExerciseAuthorizationTest} from "../shared/BaseUnbackedExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Isolated evidence for the F8A predicates whose failing side no production-reachable state can
///         exhibit (G8A-4, G8A-8, G8A-11).
/// @dev Three F8A requirements have a failing side the reachable system cannot produce, and that is a
///      property of the protocol working rather than a gap in the evidence:
///
///      - insufficient prospective exercise backing, because `S' >= O - q` reduces to `S >= O` inside the
///        canonical single-interval geometry, and `S >= O` is the invariant every authoritative transition
///        already maintains;
///      - a commitment belonging to another Protected Execution Service, because this Hook admits
///        commitments under exactly one service and stamps every record with it;
///      - an authorization overlapping one still in flight, because every external read production
///        authorization performs before writing its result is a static call.
///
///      Each is nonetheless a requirement, and each is verified here against the production predicate with
///      the harness supplying only the otherwise-unreachable precondition. That state is harness-created
///      and is evidence about these predicates alone: nothing here may be read as evidence about admission,
///      enforcement, integration, or acceptance behavior.
contract ExerciseAuthorizationUnitTest is BaseUnbackedExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev An authentically admissible entitlement: 20,000 MockUSDC.
    uint128 internal constant ADMITTED_ENTITLEMENT = 20_000_000_000;

    /// @dev The exercise quantity used throughout: 20,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 20_000_000_000;

    /// @dev The capacity a protected exercise of `EXERCISE_Q` leaves from the canonical bootstrap:
    ///      80,000 - 20,000 MockUSDC.
    uint256 internal constant EXPECTED_EXERCISE_PROSPECTIVE_S = 60_000_000_000;

    /*//////////////////////////////////////////////////////////////
                    PROSPECTIVE EXERCISE BACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an exercise that would leave the service unbacked is refused.
    /// @dev The obligation is inflated to 120,000 MockUSDC against a service holding 80,000 of capacity, so
    ///      a complete successful exercise of 20,000 would leave 60,000 of capacity against 100,000 of
    ///      remaining obligation. The refusal names that exact pair, so it cannot be credited to the extent
    ///      check, the eligibility check, or anything else.
    function test_insufficientProspectiveExerciseBacking_isRejected() public {
        uint256 commitmentId = _establishExercisable(ADMITTED_ENTITLEMENT);

        _writeRemainingEntitlement(commitmentId, 120_000_000_000);

        assertEq(hook.supportingCapacity(), StandbyFixtureConfig.EXPECTED_INITIAL_S, "capacity is authentic");
        assertEq(hook.aggregateObligation(), 120_000_000_000, "the harness produced an unbacked obligation");

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientProspectiveExerciseBacking.selector,
                EXPECTED_EXERCISE_PROSPECTIVE_S,
                uint256(100_000_000_000)
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("an unbacked exercise must leave no causal context");
    }

    /// @notice Proves the backing decision is made at exactly the right unit.
    /// @dev The pair of runs differs by one raw MockUSDC unit of obligation and nothing else. At
    ///      `Remaining = 80,000` the exercise leaves 60,000 against exactly 60,000 and is authorized; one
    ///      unit more of obligation leaves 60,000 against 60,001 and is refused. Exact sufficiency passes,
    ///      and the first unit past it does not.
    function test_prospectiveExerciseBacking_decidesAtTheExactUnit() public {
        uint256 commitmentId = _establishExercisable(ADMITTED_ENTITLEMENT);

        _writeRemainingEntitlement(commitmentId, uint128(StandbyFixtureConfig.EXPECTED_INITIAL_S) + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientProspectiveExerciseBacking.selector,
                EXPECTED_EXERCISE_PROSPECTIVE_S,
                EXPECTED_EXERCISE_PROSPECTIVE_S + 1
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _writeRemainingEntitlement(commitmentId, uint128(StandbyFixtureConfig.EXPECTED_INITIAL_S));

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertExercisedContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, EXERCISE_Q, "S' == O - q must be authorized"
        );
    }

    /// @notice Proves a refused exercise authorization reduces neither the obligation nor the remainder.
    /// @dev The comparison is against a prospective post-fulfillment obligation, and evaluating it must not
    ///      be mistaken for applying it. Both the aggregate and the commitment's own remainder come out of
    ///      the refusal exactly as they went in.
    function test_refusedBackingCheck_reducesNoObligation() public {
        uint256 commitmentId = _establishExercisable(ADMITTED_ENTITLEMENT);

        _writeRemainingEntitlement(commitmentId, 120_000_000_000);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientProspectiveExerciseBacking.selector,
                EXPECTED_EXERCISE_PROSPECTIVE_S,
                uint256(100_000_000_000)
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        assertEq(hook.aggregateObligation(), 120_000_000_000, "the obligation must be unchanged");
        assertEq(
            hook.commitment(commitmentId).remainingEntitlement,
            120_000_000_000,
            "Remaining Entitlement must be unchanged"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          SERVICE BINDING
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a commitment admitted under another service cannot be authorized here.
    /// @dev The record is otherwise perfectly formed — a genuine Beneficiary, this fixture's genuine
    ///      exercise authority, an open window, a positive remainder — and it names a different service.
    ///      That alone is disqualifying, because the semantics the authorization would be evaluated under
    ///      are not the semantics the commitment was admitted under.
    function test_commitmentOfAnotherService_isRejected() public {
        PoolId foreignServiceId = PoolId.wrap(keccak256("a different Protected Execution Service"));

        uint256 commitmentId = serviceHarness.recordCommitment(
            StandbyHook.Commitment({
                serviceId: foreignServiceId,
                beneficiary: beneficiary,
                exercisableFrom: uint64(block.timestamp),
                exerciseAuthority: commitmentExerciseAuthority,
                validUntil: uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION,
                originalEntitlement: ADMITTED_ENTITLEMENT,
                remainingEntitlement: ADMITTED_ENTITLEMENT
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CommitmentNotInService.selector, commitmentId, foreignServiceId
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("a foreign service must leave no causal context");
    }

    /*//////////////////////////////////////////////////////////////
                      IN-FLIGHT AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an authorization cannot begin while another is still in flight.
    /// @dev The slot is claimed before authorization consults anything outside the Hook, which is what makes
    ///      an overlapping authorization impossible rather than merely unlikely. Production cannot hold the
    ///      claim open — every such read is a static call — so the claim is held here directly, and a fully
    ///      qualified request that would otherwise succeed is refused while it is held.
    function test_authorizationInFlight_blocksAnotherAuthorization() public {
        uint256 commitmentId = _establishExercisable(ADMITTED_ENTITLEMENT);

        serviceHarness.beginExerciseAuthorization();

        assertEq(
            uint256(_authorizationContext().state),
            uint256(StandbyHook.ExerciseAuthorizationState.AUTHORIZING),
            "the slot must be claimed"
        );

        vm.expectRevert(StandbyHook.StandbyHook__ExerciseAuthorizationAlreadyActive.selector);
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        StandbyHook.ExerciseAuthorizationContext memory current = _authorizationContext();

        assertEq(
            uint256(current.state),
            uint256(StandbyHook.ExerciseAuthorizationState.AUTHORIZING),
            "the refused attempt must not have advanced the slot"
        );
        assertEq(current.commitmentId, 0, "an in-flight claim carries no bindings");
        assertEq(current.exerciser, address(0), "an in-flight claim carries no bindings");
        assertEq(current.beneficiary, address(0), "an in-flight claim carries no bindings");
        assertEq(current.q, 0, "an in-flight claim carries no bindings");
    }

    /// @notice Proves the in-flight claim is discarded when the authorization that made it fails.
    /// @dev The claim lives in transient storage inside the same call frame as the predicates, so a refusal
    ///      unwinds it with everything else. There is no separate release path to forget, and no refusal
    ///      can leave the single authorization slot stuck.
    function test_failedAuthorization_discardsItsInFlightClaim() public {
        uint256 commitmentId = _establishExercisable(ADMITTED_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotCommitmentExerciseAuthority.selector, commitmentId, unauthorizedExerciser
            )
        );
        _authorizeAs(unauthorizedExerciser, commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("a refused attempt must release the slot it claimed");

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertExercisedContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, EXERCISE_Q, "the slot must still be usable"
        );
    }
}
