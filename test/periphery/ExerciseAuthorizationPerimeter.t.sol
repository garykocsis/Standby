// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";
import {IActorAwarePeriphery} from "../../src/interfaces/IActorAwarePeriphery.sol";

import {BaseExerciseAuthorizationTest} from "../shared/BaseExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice A contract that answers the attribution question with whatever it was told to say.
/// @dev Test instrumentation for the forged-attribution case. It implements the perimeter interface
///      faithfully and lies about its answer, which is the point: what stops it is not the quality of its
///      answer but that nothing ever asks it. It is not the configured ExerciseRouter of any service.
contract ClaimingExerciseRouter is IActorAwarePeriphery {
    StandbyHook public immutable i_hook;

    address public claimedExerciser;

    constructor(StandbyHook _hook) {
        i_hook = _hook;
    }

    /// @notice Attempts O2 authorization while claiming an arbitrary originating exerciser.
    /// @param _commitmentId The commitment to attempt.
    /// @param _q The quantity to attempt.
    /// @param _claimedExerciser The exerciser this contract will claim originated the request.
    function exercise(uint256 _commitmentId, uint256 _q, address _claimedExerciser) external {
        claimedExerciser = _claimedExerciser;

        i_hook.authorizeExercise(_commitmentId, _q);
    }

    /// @inheritdoc IActorAwarePeriphery
    function msgSender() external view returns (address actor) {
        actor = claimedExerciser;
    }
}

/// @notice Periphery evidence that the F8A exercise perimeter and originator attribution hold their
///         architectural boundaries (G8A-1 through G8A-3).
/// @dev The boundary under test is an ordering rule as much as a trust rule, and it is the same rule the
///      ordinary-transition perimeters follow: the Hook authenticates that its caller is exactly the
///      ExerciseRouter its one-shot configuration designates, and only then asks that router who originated
///      the request. Reversing the order would let any contract implementing the attribution interface
///      nominate an exerciser, which is precisely what these tests demonstrate cannot happen.
///
///      Three identities stay distinct throughout and are never collapsed: the account that called the
///      router, the router itself, and the commitment's exercise authority. The router coordinates the
///      request; it is never a party to the commitment.
contract ExerciseAuthorizationPerimeterTest is BaseExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A commitment comfortably inside the canonical bootstrap capacity: 20,000 MockUSDC.
    uint128 internal constant EXERCISE_ENTITLEMENT = 20_000_000_000;

    /// @dev Half of it, so the requested extent is unambiguously permissible: 10,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 10_000_000_000;

    /*//////////////////////////////////////////////////////////////
                        EXERCISE PERIMETER
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an account cannot authorize an exercise by calling the Hook directly.
    /// @dev Not even the account that genuinely holds the commitment's exercise authority. Holding exercise
    ///      authority is a fact about a commitment; reaching the authorization transition at all is a fact
    ///      about the perimeter, and the perimeter question is answered first.
    function test_directCaller_cannotAuthorizeExercise() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotExerciseRouter.selector, commitmentExerciseAuthority)
        );
        vm.prank(commitmentExerciseAuthority);
        hook.authorizeExercise(commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("a refused perimeter must leave no causal context");
    }

    /// @notice Proves an identical but unconfigured ExerciseRouter authorizes nothing.
    /// @dev Same bytecode, same Hook binding, same faithful attribution, same genuine exercise authority
    ///      calling it. The only difference is that the service was not activated with it, and that is the
    ///      whole difference: the exercise perimeter is a configured identity, not a code shape.
    function test_unconfiguredExerciseRouter_cannotAuthorizeExercise() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotExerciseRouter.selector, address(unconfiguredExerciseRouter)
            )
        );
        vm.prank(commitmentExerciseAuthority);
        unconfiguredExerciseRouter.exercise(commitmentId, EXERCISE_Q, UNCONSTRAINED_MAX_INPUT);

        _assertNoAuthorizationContext("a refused perimeter must leave no causal context");
    }

    /// @notice Proves the trusted ordinary-transition perimeters are not the exercise perimeter.
    /// @dev The swap perimeter and the liquidity perimeter are trusted for their own transition families
    ///      and authorize nothing in O2. Perimeter trust is per role, and the roles do not merge.
    function test_ordinaryTransitionPerimeters_cannotAuthorizeExercise() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotExerciseRouter.selector, address(swapPerimeter))
        );
        vm.prank(address(swapPerimeter));
        hook.authorizeExercise(commitmentId, EXERCISE_Q);

        vm.expectRevert(
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotExerciseRouter.selector, address(liquidityPerimeter))
        );
        vm.prank(address(liquidityPerimeter));
        hook.authorizeExercise(commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("a refused perimeter must leave no causal context");
    }

    /*//////////////////////////////////////////////////////////////
                       ORIGINATOR ATTRIBUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the Hook recovers the originating exerciser from the configured ExerciseRouter.
    /// @dev Direct evidence of the recovery rather than an inference from the outcome: the attribution
    ///      query the Hook performs must be made against the configured router, and the authorization that
    ///      results must bind the account that actually called it.
    function test_authorization_recoversTheOriginatorFromTheConfiguredRouter() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        vm.expectCall(address(configuredExerciseRouter), abi.encodeCall(IActorAwarePeriphery.msgSender, ()));

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertExercisedContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "the bound exerciser must be the account that called the configured router"
        );
    }

    /// @notice Proves attribution distinguishes exercisers rather than authorizing the perimeter as a whole.
    /// @dev Same router, same commitment, same quantity, two different originating callers, opposite
    ///      outcomes. Reaching the perimeter is not holding the authority.
    function test_wrongOriginatingExerciser_isRejected() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotCommitmentExerciseAuthority.selector, commitmentId, unauthorizedExerciser
            )
        );
        _authorizeAs(unauthorizedExerciser, commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("a refused exerciser must leave no causal context");

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertExercisedContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, EXERCISE_Q, "the authority itself may authorize"
        );
    }

    /// @notice Proves the originator is the direct caller and never the transaction origin.
    /// @dev The genuine exercise authority calls the router from a transaction someone else originated, and
    ///      it works; then the transaction origin holds the authority while somebody else calls, and it does
    ///      not. `tx.origin` is not an economic actor and is never consulted.
    function test_originatingExerciser_isTheDirectCallerAndNotTheTransactionOrigin() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotCommitmentExerciseAuthority.selector, commitmentId, unauthorizedExerciser
            )
        );
        vm.prank(unauthorizedExerciser, commitmentExerciseAuthority);
        configuredExerciseRouter.exercise(commitmentId, EXERCISE_Q, UNCONSTRAINED_MAX_INPUT);

        vm.prank(commitmentExerciseAuthority, unauthorizedExerciser);
        configuredExerciseRouter.exercise(commitmentId, EXERCISE_Q, UNCONSTRAINED_MAX_INPUT);

        _assertExercisedContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "the bound exerciser must be the direct caller"
        );
    }

    /// @notice Proves a contract that forges an attribution answer is never asked for one.
    /// @dev It implements the interface, it names a genuine exercise authority, and its answer would have
    ///      been accepted from the configured router. It is refused at the perimeter, before its claim is
    ///      consulted at all, which is what makes attribution safe rather than merely checked.
    function test_forgedAttribution_isRefusedBeforeItIsConsulted() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        ClaimingExerciseRouter claiming = new ClaimingExerciseRouter(hook);

        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__NotExerciseRouter.selector, address(claiming)));
        vm.prank(unauthorizedExerciser);
        claiming.exercise(commitmentId, EXERCISE_Q, commitmentExerciseAuthority);

        _assertNoAuthorizationContext("a forged attribution must leave no causal context");
    }

    /*//////////////////////////////////////////////////////////////
                    ROUTER IDENTITY IS NOT AUTHORITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the configured ExerciseRouter cannot exercise a commitment held in its own name.
    /// @dev The commitment's exercise authority is the router's own address, so if router identity could
    ///      ever satisfy commitment-specific authority this is where it would. It cannot: the authenticated
    ///      exerciser is the account that originated the request, and that is never the router.
    function test_exerciseRouterIdentity_neverSatisfiesCommitmentExerciseAuthority() public {
        uint256 commitmentId = _establishAs(
            establishmentAuthority,
            beneficiary,
            address(configuredExerciseRouter),
            EXERCISE_ENTITLEMENT,
            uint64(block.timestamp),
            uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotCommitmentExerciseAuthority.selector, commitmentId, unauthorizedExerciser
            )
        );
        _authorizeAs(unauthorizedExerciser, commitmentId, EXERCISE_Q);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotCommitmentExerciseAuthority.selector,
                commitmentId,
                commitmentExerciseAuthority
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("no caller may exercise a commitment held in the router's name");
    }

    /// @notice Proves the configured ExerciseRouter cannot authorize without a request in flight.
    /// @dev The router is the configured perimeter, so it passes the perimeter question. It still fails,
    ///      because attribution fails closed: an absent execution context is not an economic actor, and the
    ///      router will not substitute a plausible one.
    function test_configuredRouter_cannotAuthorizeOutsideARequest() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        vm.expectRevert(ExerciseRouter.ExerciseRouter__NoActiveExerciseContext.selector);
        vm.prank(address(configuredExerciseRouter));
        hook.authorizeExercise(commitmentId, EXERCISE_Q);

        _assertNoAuthorizationContext("a failed attribution must leave no causal context");
    }

    /// @notice Proves the ExerciseRouter exposes no usable exerciser outside a request.
    function test_exerciseRouter_exposesNoExerciserWithoutARequest() public {
        vm.expectRevert(ExerciseRouter.ExerciseRouter__NoActiveExerciseContext.selector);
        configuredExerciseRouter.msgSender();

        vm.prank(commitmentExerciseAuthority);
        vm.expectRevert(ExerciseRouter.ExerciseRouter__NoActiveExerciseContext.selector);
        unconfiguredExerciseRouter.msgSender();
    }

    /*//////////////////////////////////////////////////////////////
                      REQUEST-SURFACE INERTNESS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a `maxInput` of zero authorizes exactly what any other value authorizes.
    /// @dev Zero is the value most likely to be mistaken for a constraint — it would refuse every real
    ///      exercise if anything enforced it — and it changes nothing here. `maxInput` is the exerciser's
    ///      own cost bound against the authoritative input debt the executed swap produces, and enforcing
    ///      it belongs to F8C together with settling that debt, so the field reaches no code and no
    ///      decision.
    function test_maxInputOfZero_authorizesIdentically() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, 0);

        _assertMaxInputIndependentAuthorization(commitmentId);
    }

    /// @notice Proves a `maxInput` below the requested quantity authorizes exactly the same request.
    /// @dev A bound smaller than the output being asked for is the shape that would most obviously fail a
    ///      cost check. Authorization is unmoved, because authorization is not a cost check.
    function test_maxInputBelowTheRequestedQuantity_authorizesIdentically() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, EXERCISE_Q - 1);

        _assertMaxInputIndependentAuthorization(commitmentId);
    }

    /// @notice Proves a `maxInput` at the top of the domain authorizes exactly the same request.
    function test_maxInputAtTheTopOfTheDomain_authorizesIdentically() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, type(uint256).max);

        _assertMaxInputIndependentAuthorization(commitmentId);
    }

    /// @notice Proves `maxInput` can neither rescue nor cause a refusal.
    /// @dev The same otherwise-invalid request is refused identically at both ends of the domain — same
    ///      error, same operands, same absence of a causal context — and a valid one then succeeds while
    ///      carrying the bound that supposedly refused the first. Nothing about the outcome is a function
    ///      of this field.
    function test_maxInput_neitherRescuesNorCausesARefusal() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        uint256 impermissible = uint256(EXERCISE_ENTITLEMENT) + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidExerciseExtent.selector, impermissible, EXERCISE_ENTITLEMENT
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, impermissible, 0);
        _assertNoAuthorizationContext("a zero bound must not change a refusal");

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidExerciseExtent.selector, impermissible, EXERCISE_ENTITLEMENT
            )
        );
        _authorizeAs(commitmentExerciseAuthority, commitmentId, impermissible, type(uint256).max);
        _assertNoAuthorizationContext("an unbounded bound must not change a refusal");

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, 0);

        _assertMaxInputIndependentAuthorization(commitmentId);
    }

    /// @notice Proves the exerciser context does not survive the request that established it.
    /// @dev The Hook's own causal context is a separate question and deliberately outlives the call: the
    ///      router's attribution is per request, while whether an authorization may be replaced or reused is
    ///      a Standby economic question the Hook owns.
    function test_exerciserContext_isClearedAfterARequest() public {
        uint256 commitmentId = _establishExercisable(EXERCISE_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        vm.expectRevert(ExerciseRouter.ExerciseRouter__NoActiveExerciseContext.selector);
        configuredExerciseRouter.msgSender();

        _assertExercisedContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "the Hook-owned causal context is not the router's attribution context"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Asserts the one authorization outcome every `maxInput` must produce.
    ///
    ///      Deliberately the whole outcome rather than a success flag: the commitment, the actor, the
    ///      Beneficiary, the service, and the quantity bound into the context, plus the derived economics
    ///      and the commitment's own remainder. A `maxInput` that shifted any of them — a different `q`, a
    ///      different Beneficiary, a different attribution, a different `S` or `O` — would show up here.
    function _assertMaxInputIndependentAuthorization(uint256 _commitmentId) internal view {
        _assertExercisedContext(
            _commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "the causal bindings must not depend on maxInput"
        );

        assertEq(hook.supportingCapacity(), _referenceSupportingCapacity(), "S must not depend on maxInput");
        assertEq(hook.aggregateObligation(), _referenceAggregateObligation(), "O must not depend on maxInput");
        assertEq(
            hook.commitment(_commitmentId).remainingEntitlement,
            EXERCISE_ENTITLEMENT,
            "Remaining Entitlement must not depend on maxInput"
        );
    }
}
