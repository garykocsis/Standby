// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {PoolId} from "v4-core/types/PoolId.sol";

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";

import {ExerciseDeltaClosureRouter} from "../harness/ExerciseDeltaClosureRouter.sol";
import {BaseAuthenticBackingTest} from "./BaseAuthenticBackingTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared real-path fixture for F8A O2 authorization evidence.
/// @dev Built on the F6B/F7 fixture without altering it: the same real pinned `PoolManager`, the same
///      canonical `StandbyHook` deployment, the same F1 currencies, the same F2 registry under its own
///      administrator, the same production activation, the same canonical liquidity added through the
///      production `beforeAddLiquidity` path, and the same production `establishCommitment` transition for
///      every commitment. Nothing is seeded: every commitment an F8A test authorizes against is authentic,
///      and every quantity it is measured against is derived from authoritative state.
///
///      What this layer adds is the exercise perimeter itself. The service is activated with a real
///      `ExerciseRouter` rather than a placeholder address, because F8A is the first slice in which the
///      configured ExerciseRouter is called rather than merely recorded. A second, identical router is
///      deployed alongside and configured nowhere: identical bytecode, no configuration, so everything
///      proven about it is a property of the Hook's configuration rather than of a difference in
///      implementation.
///
///      From F8B the configured router is `ExerciseDeltaClosureRouter` — the production `ExerciseRouter`
///      with mechanical PoolManager delta closure added and nothing else. It is needed because a completed
///      exercise now performs a real swap, and F8B implements no settlement, so no production path can
///      close the deltas that swap opens and no exercise could otherwise commit. Every authorization
///      predicate below is still decided by the production `authorizeExercise` against production state,
///      and every rejection below still occurs inside it, before any unlock. The closure contributes no
///      economics: it assigns no payer, enforces no cost bound, delivers nothing to the Beneficiary, and
///      attributes no fulfillment.
///
///      Roles stay separate throughout. The commitment's exercise authority is not the Beneficiary, not the
///      establishment authority, not the configuration authority, not a trader, not a liquidity provider,
///      not the registry administrator, and not either router — so an authorization that succeeds cannot be
///      succeeding because two distinct authorities happen to be the same account.
abstract contract BaseExerciseAuthorizationTest is BaseAuthenticBackingTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The ExerciseRouter the service was actually activated with.
    ExerciseRouter internal configuredExerciseRouter;

    /// @dev An identical ExerciseRouter bound to the same Hook and configured by nothing.
    ExerciseRouter internal unconfiguredExerciseRouter;

    /// @dev An account with no relationship to any commitment's exercise authority.
    address internal unauthorizedExerciser;

    /// @dev The `maxInput` a request carries when the test is not about `maxInput`.
    ///
    ///      Any value would do, which is the point: nothing implemented so far reads or forwards this
    ///      field, so no test outcome may depend on which value it is. Enforcing it against the input debt
    ///      the executed swap produces belongs to F8C. The suites that are about the field say so
    ///      explicitly and vary it across the `uint256` domain.
    uint256 internal constant UNCONSTRAINED_MAX_INPUT = type(uint256).max;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds the exercise perimeter to the activated canonical service.
    function setUp() public virtual override {
        super.setUp();

        unauthorizedExerciser = makeAddr("unauthorizedExerciser");

        unconfiguredExerciseRouter = new ExerciseRouter(hook);

        _fundDeltaClosure();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Activates the service with a real ExerciseRouter bound to this fixture's Hook.
    function _resolveExerciseRouter() internal virtual override returns (address router) {
        configuredExerciseRouter = new ExerciseDeltaClosureRouter(hook);

        router = address(configuredExerciseRouter);
    }

    /// @dev Gives the delta-closure router the currency it needs to close a committed execution's deltas.
    ///
    ///      Not funding, in any economic sense: it is the balance the mechanical closure draws on so that
    ///      the real PoolManager will let an otherwise valid execution commit. No exerciser is funded, no
    ///      approval is granted, and nothing here decides who pays for an exercise — that is F8C's.
    function _fundDeltaClosure() internal {
        ustb.mint(exerciseRouter, ACTOR_FUNDING);
        usdc.mint(exerciseRouter, ACTOR_FUNDING);
    }

    /// @dev The ExerciseRouter a causal context is expected to be bound to.
    ///
    ///      Overridable because a fixture may activate its service with a different coordinator — an
    ///      adversarial one, for the classification restrictions that must hold whatever the configured
    ///      router does.
    function _expectedContextRouter() internal view virtual returns (address router) {
        router = exerciseRouter;
    }

    /// @dev Makes an O2 exercise request as an originating exerciser, through the configured ExerciseRouter.
    ///
    ///      The request is the whole production coordination the router implements: it obtains Hook-owned
    ///      authorization and then performs the one protected execution that authorization admits. A
    ///      request that is refused at authorization therefore never reaches an execution, and one that
    ///      passes leaves execution evidence rather than a standing authorization.
    function _authorizeAs(address _exerciser, uint256 _commitmentId, uint256 _q) internal {
        _authorizeAs(_exerciser, _commitmentId, _q, UNCONSTRAINED_MAX_INPUT);
    }

    /// @dev The same request, with the exerciser's own cost bound chosen explicitly.
    ///
    ///      Only the suites that are about `maxInput` need this form. Everything else routes through the
    ///      shorter one, so no other test can accidentally come to depend on a particular bound.
    function _authorizeAs(address _exerciser, uint256 _commitmentId, uint256 _q, uint256 _maxInput) internal {
        vm.prank(_exerciser);
        configuredExerciseRouter.exercise(_commitmentId, _q, _maxInput);
    }

    /// @dev Runs the production O1 transition for a commitment whose exercise window is already open.
    ///
    ///      An `exercisableFrom` that has already passed is an ordinary admissible term, so this needs no
    ///      privileged path: the commitment is admitted exactly as any other, and is exercisable from the
    ///      moment it exists.
    function _establishExercisable(uint128 _originalEntitlement) internal returns (uint256 commitmentId) {
        commitmentId = _establishWithWindow(
            _originalEntitlement, uint64(block.timestamp), uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION
        );
    }

    /// @dev Reads the Hook-owned transaction-scoped causal context.
    function _authorizationContext() internal view returns (StandbyHook.ExerciseAuthorizationContext memory context) {
        context = hook.exerciseAuthorization();
    }

    /// @dev Proves the Hook holds no usable causal context at all.
    ///
    ///      Every field is checked, not only the state. A context that reported EMPTY while still carrying
    ///      a commitment, an actor, a Beneficiary, or a quantity would be exactly the reusable residue F8A
    ///      must not leave behind.
    function _assertNoAuthorizationContext(string memory _context) internal view {
        StandbyHook.ExerciseAuthorizationContext memory current = _authorizationContext();

        assertEq(uint256(current.state), uint256(StandbyHook.ExerciseAuthorizationState.EMPTY), _context);
        assertEq(PoolId.unwrap(current.serviceId), bytes32(0), _context);
        assertEq(current.commitmentId, 0, _context);
        assertEq(current.exerciseRouter, address(0), _context);
        assertEq(current.exerciser, address(0), _context);
        assertEq(current.beneficiary, address(0), _context);
        assertEq(current.q, 0, _context);
    }

    /// @dev Proves the Hook holds exactly the expected causal bindings, at an expected causal position.
    ///
    ///      The bindings are the same object throughout the O2 operation: authorization writes them and no
    ///      later stage may substitute one. Only the position advances, so the position is the parameter.
    function _assertCausalContext(
        StandbyHook.ExerciseAuthorizationState _state,
        uint256 _commitmentId,
        address _exerciser,
        address _beneficiary,
        uint256 _q,
        string memory _context
    ) internal view {
        StandbyHook.ExerciseAuthorizationContext memory current = _authorizationContext();

        assertEq(uint256(current.state), uint256(_state), _context);
        assertEq(PoolId.unwrap(current.serviceId), PoolId.unwrap(servicePoolId), _context);
        assertEq(current.commitmentId, _commitmentId, _context);
        assertEq(current.exerciseRouter, _expectedContextRouter(), _context);
        assertEq(current.exerciser, _exerciser, _context);
        assertEq(current.beneficiary, _beneficiary, _context);
        assertEq(current.q, _q, _context);
    }

    /// @dev Proves the Hook holds exactly the expected bindings, still awaiting its protected execution.
    function _assertAuthorizationContext(
        uint256 _commitmentId,
        address _exerciser,
        address _beneficiary,
        uint256 _q,
        string memory _context
    ) internal view {
        _assertCausalContext(
            StandbyHook.ExerciseAuthorizationState.AUTHORIZED, _commitmentId, _exerciser, _beneficiary, _q, _context
        );
    }

    /// @dev Proves a completed exercise request left exactly the expected bindings, with execution proven.
    ///
    ///      This is what a request that passes every authorization predicate now reaches, because the
    ///      request coordinates the protected execution as well as the authorization. The bindings asserted
    ///      are the ones authorization resolved — the commitment, the authenticated exerciser, the
    ///      Beneficiary taken from the commitment record, and the quantity — so an authorization predicate
    ///      that resolved the wrong fact still fails here.
    function _assertExercisedContext(
        uint256 _commitmentId,
        address _exerciser,
        address _beneficiary,
        uint256 _q,
        string memory _context
    ) internal view {
        _assertCausalContext(
            StandbyHook.ExerciseAuthorizationState.EXECUTED, _commitmentId, _exerciser, _beneficiary, _q, _context
        );
    }

    /// @dev The Supporting Capacity the canonical protected exercise of `q` would leave, from frozen
    ///      geometry rather than from the derivation under test.
    ///
    ///      The canonical position spans the whole service domain as one constant-liquidity interval, so an
    ///      exact-output protected exercise of `q` draws exactly `q` units out of the capacity-bearing
    ///      region — and everything the domain can still deliver once `q` exceeds it, because the exercise
    ///      is bounded by the protected boundary itself.
    function _expectedProspectiveExerciseCapacity(uint256 _q) internal view returns (uint256 capacity) {
        uint256 present = _referenceSupportingCapacity();

        capacity = _q >= present ? 0 : present - _q;
    }
}
