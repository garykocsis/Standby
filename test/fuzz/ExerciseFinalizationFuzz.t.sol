// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {BaseExerciseFinalizationTest} from "../shared/BaseExerciseFinalizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Fuzz evidence that durable fulfillment is exact across the whole admissible quantity domain
///         (G8D-B, G8D-C, G8D-D).
/// @dev The fulfillment consequence is one subtraction, and a subtraction is the kind of thing that is
///      right almost everywhere and wrong at an edge — at one raw unit, at the whole remainder, and at the
///      point where releasing the obligation is the only reason the resulting state is still backed. Every
///      run below performs a complete production exercise on the real pinned execution stack: a real
///      authorization, a real swap, a real settlement out of the exerciser's own account, a real delivery
///      to the Beneficiary, and a real finalization.
///
///      The expected outcome of every run is stated as arithmetic over the admitted extent and the
///      quantities the runs themselves chose, never read back from the derivation under test. Quantities
///      are bounded by what the frozen fixture can actually back rather than by what is convenient, so the
///      admissible domain is covered to both of its endpoints.
contract ExerciseFinalizationFuzzTest is BaseExerciseFinalizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /*//////////////////////////////////////////////////////////////
                      EXACT FULFILLMENT CONSEQUENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Any admissible quantity is fulfilled exactly, and nothing else about the commitment moves.
    function testFuzz_completedExercise_fulfilsExactlyTheExercisedQuantity(uint256 _qSeed) public {
        uint256 q = bound(_qSeed, 1, CANONICAL_ENTITLEMENT);

        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, q);

        _assertExactFulfillment(before, commitmentExerciseAuthority, commitmentId, q);
    }

    /// @notice Two successive exercises leave the exact arithmetic remainder and deliver the exact sum.
    /// @dev The second quantity is chosen against the remainder the first one produced, which is the whole
    ///      point: an implementation that fulfilled against the admitted extent rather than the current
    ///      remainder would pass the single-exercise case and fail here.
    function testFuzz_sequentialExercises_produceTheExactRemainder(uint256 _firstSeed, uint256 _secondSeed) public {
        uint256 first = bound(_firstSeed, 1, CANONICAL_ENTITLEMENT - 1);
        uint256 second = bound(_secondSeed, 1, CANONICAL_ENTITLEMENT - first);

        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, first);
        _authorizeAs(commitmentExerciseAuthority, commitmentId, second);

        SettlementState memory current = _settlementState(commitmentExerciseAuthority, commitmentId);

        assertEq(
            uint256(current.remainingEntitlement),
            uint256(CANONICAL_ENTITLEMENT) - first - second,
            "the remainder must be the admitted extent less everything fulfilled against it"
        );
        assertEq(
            uint256(current.originalEntitlement),
            uint256(CANONICAL_ENTITLEMENT),
            "no sequence of fulfillments may rewrite the admitted extent"
        );
        assertEq(
            current.aggregateObligation,
            before.aggregateObligation - first - second,
            "the derived obligation must release exactly the sum of what was fulfilled"
        );
        assertEq(
            current.beneficiaryOutput - before.beneficiaryOutput,
            first + second,
            "the Beneficiary must receive exactly the sum of what was fulfilled"
        );
    }

    /// @notice Any admissible entitlement can be exercised to exactly zero, releasing its whole obligation.
    /// @dev The extent is fuzzed as well as the quantity, up to everything the canonical geometry can back,
    ///      so exhaustion is exercised across the admissible commitment domain rather than at one size. What
    ///      it must produce is derived and not flagged: a zero remainder, a zero commitment obligation, and
    ///      a zero aggregate.
    function testFuzz_anyAdmissibleEntitlement_canBeExhaustedExactly(uint128 _entitlementSeed) public {
        uint128 entitlement = uint128(bound(_entitlementSeed, 1, _referenceSupportingCapacity()));

        uint256 commitmentId = _establishExercisable(entitlement);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, entitlement);

        _assertExactFulfillment(before, commitmentExerciseAuthority, commitmentId, entitlement);

        assertEq(
            uint256(_commitmentRecord(commitmentId).remainingEntitlement),
            0,
            "exhausting an entitlement must leave exactly zero"
        );
        assertEq(hook.commitmentObligation(commitmentId), 0, "an exhausted commitment must carry no obligation");
        assertEq(hook.aggregateObligation(), 0, "the aggregate must release the exhausted commitment entirely");
    }

    /// @notice A completed exercise of any admissible quantity leaves no reusable causal evidence.
    function testFuzz_completedExercise_leavesNoReusableCausalEvidence(uint256 _qSeed) public {
        uint256 q = bound(_qSeed, 1, CANONICAL_ENTITLEMENT);

        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, q);

        _assertNoAuthorizationContext("a finalized exercise must consume its causal proof entirely");
    }

    /// @notice The service remains backed by both independent reconstructions after any fulfillment.
    /// @dev Both derivations are checked against oracles that recompute them from authoritative PoolManager
    ///      state and from the persisted commitment facts, so a fulfillment that moved the remainder and the
    ///      capacity consistently but wrongly still fails here.
    function testFuzz_fulfilledService_remainsBackedByIndependentDerivation(uint256 _qSeed) public {
        uint256 q = bound(_qSeed, 1, CANONICAL_ENTITLEMENT);

        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, q);

        _assertDerivationsMatchOracles("the fulfilled state must match both independent reconstructions");

        assertGe(
            _referenceSupportingCapacity(),
            _referenceAggregateObligation(),
            "the independently derived state must remain backed after fulfillment"
        );
    }
}
