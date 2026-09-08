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

/// @notice Focused fuzz evidence for the F8A extent and actor predicates (G8A-5, G8A-7).
/// @dev Both properties are stated as biconditionals rather than as one-sided examples, because the risk in
///      each is a boundary slip rather than a missing check: an extent rule that accepted zero or excluded
///      the whole remainder would still pass every reasonable positive example, and an authority rule that
///      accepted a superset would too.
///
///      Every generated case is otherwise fully qualified — an authentic production-admitted commitment,
///      the configured ExerciseRouter, an open exercise window, an eligible Beneficiary, and backing that
///      comfortably survives the complete exercise — so nothing unrelated can mask the predicate under test.
///      Refusals are matched on the exact error and operands, so a run that expects a refusal passes only
///      when the Hook refused for the predicted reason.
contract ExerciseAuthorizationFuzzTest is BaseExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                          EXERCISE EXTENT
    //////////////////////////////////////////////////////////////*/

    /// @notice A request is authorized exactly when its quantity lies in `0 < q <= Remaining`.
    /// @dev The generated quantity ranges from zero to twice the admitted remainder, so both ends of the
    ///      half-open interval and a wide region beyond it are reached. An authorized run must bind exactly
    ///      the requested quantity and leave the remainder untouched; a refused one must leave no context.
    function testFuzz_exerciseExtent_isAuthorizedExactlyOnTheHalfOpenRemainder(uint128 _entitlementSeed, uint256 _qSeed)
        public
    {
        uint128 entitlement = uint128(_bound(uint256(_entitlementSeed), 1, StandbyFixtureConfig.EXPECTED_INITIAL_S));

        uint256 commitmentId = _establishExercisable(entitlement);

        uint256 q = _bound(_qSeed, 0, uint256(entitlement) * 2);

        if (q > 0 && q <= entitlement) {
            _authorizeAs(commitmentExerciseAuthority, commitmentId, q);

            _assertExercisedContext(
                commitmentId, commitmentExerciseAuthority, beneficiary, q, "a permissible extent must be authorized"
            );

            assertEq(
                hook.commitment(commitmentId).remainingEntitlement,
                entitlement,
                "an authorized extent still reduces no Remaining Entitlement"
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidExerciseExtent.selector, q, entitlement)
            );
            _authorizeAs(commitmentExerciseAuthority, commitmentId, q);

            _assertNoAuthorizationContext("an impermissible extent must leave no causal context");
        }
    }

    /*//////////////////////////////////////////////////////////////
                          EXERCISE AUTHORITY
    //////////////////////////////////////////////////////////////*/

    /// @notice A request is authorized exactly when the authenticated originator is the commitment's own
    ///         exercise authority.
    /// @dev The generated originator is either that authority or an unrelated account, and every other
    ///      predicate holds either way. Nothing about reaching the configured perimeter, or about the
    ///      request being otherwise perfect, substitutes for holding the authority.
    function testFuzz_onlyTheCommitmentExerciseAuthority_mayAuthorize(uint256 _exerciserSeed, bool _useAuthority)
        public
    {
        uint128 entitlement = 20_000_000_000;

        uint256 commitmentId = _establishExercisable(entitlement);

        address exerciser = _useAuthority
            ? commitmentExerciseAuthority
            : address(uint160(uint256(keccak256(abi.encode("fuzzedExerciser", _exerciserSeed)))));

        vm.assume(exerciser != commitmentExerciseAuthority || _useAuthority);

        if (exerciser == commitmentExerciseAuthority) {
            _authorizeAs(exerciser, commitmentId, entitlement);

            _assertExercisedContext(
                commitmentId, exerciser, beneficiary, entitlement, "the exercise authority must be authorized"
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    StandbyHook.StandbyHook__NotCommitmentExerciseAuthority.selector, commitmentId, exerciser
                )
            );
            _authorizeAs(exerciser, commitmentId, entitlement);

            _assertNoAuthorizationContext("a foreign originator must leave no causal context");
        }
    }

    /*//////////////////////////////////////////////////////////////
                      REQUEST-SURFACE INERTNESS
    //////////////////////////////////////////////////////////////*/

    /// @notice The exerciser's `maxInput` changes no outcome anywhere in the `uint256` domain.
    /// @dev The field is on the frozen request surface and still has no semantics here: it is exercise-local
    ///      cost protection, enforced against the authoritative PoolManager input debt an executed
    ///      exact-output swap produces. The swap now executes and that debt exists, but requiring
    ///      `actualInput <= maxInput` belongs to F8C together with settling it, so nothing consumes the
    ///      bound yet. This property is what "no semantics" means operationally — across every value the
    ///      domain admits, a refusal is the same refusal, an authorized exercise is the same exercise, the
    ///      causal bindings are identical, and the derived economics are untouched.
    ///
    ///      Both directions are covered in one run. The refusal comes first, because a refusal leaves the
    ///      single authorization slot free, so the same run can then show that the same bound authorizes a
    ///      permissible request.
    function testFuzz_maxInput_changesNoAuthorizationOutcome(uint256 _maxInput) public {
        uint128 entitlement = 20_000_000_000;
        uint256 q = 5_000_000_000;

        uint256 commitmentId = _establishExercisable(entitlement);

        uint256 impermissible = uint256(entitlement) + 1;

        vm.expectRevert(
            abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidExerciseExtent.selector, impermissible, entitlement)
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, impermissible, _maxInput);

        _assertNoAuthorizationContext("no maxInput may rescue an impermissible request");

        _authorizeAs(commitmentExerciseAuthority, commitmentId, q, _maxInput);

        _assertExercisedContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, q, "no maxInput may alter the causal bindings"
        );

        assertEq(hook.supportingCapacity(), _referenceSupportingCapacity(), "S must not depend on maxInput");
        assertEq(hook.aggregateObligation(), uint256(entitlement), "O must not depend on maxInput");
        assertEq(
            hook.commitment(commitmentId).remainingEntitlement,
            entitlement,
            "Remaining Entitlement must not depend on maxInput"
        );
    }
}
