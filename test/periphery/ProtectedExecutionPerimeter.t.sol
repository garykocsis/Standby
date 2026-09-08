// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseAdversarialExerciseTest} from "../shared/BaseAdversarialExerciseTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Periphery evidence that O2 classification survives a hostile configured ExerciseRouter (G8B-1
///         through G8B-4, G8B-7, G8B-11).
/// @dev The service here is activated with `AdversarialExerciseRouter` in the configured O2 coordinator
///      role. It is a real configured router with real originating-user attribution, and it proposes
///      operations the production router structurally cannot: a swap with no authorization behind it, a
///      substituted quantity, direction, price limit or pool, two swaps against one authorization, and a
///      second authorization.
///
///      What every test below establishes is the same thing from a different angle: the configured router
///      is trusted for exactly one fact — who originated the request — and acquires no ability to classify
///      an execution, manufacture evidence, or reuse an authorization by being the configured router.
///      Classification is conjunctive, and each conjunct is falsified separately here.
contract ProtectedExecutionPerimeterTest is BaseAdversarialExerciseTest {
    using PoolIdLibrary for PoolKey;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /// @dev The exercise quantity used throughout: 20,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 20_000_000_000;

    /// @dev A payload shaped to imitate a Standby causal context.
    bytes internal forgedCausalPayload;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Prepares a payload that names everything an authorization binds.
    function setUp() public virtual override {
        super.setUp();

        forgedCausalPayload = abi.encode(
            servicePoolId,
            uint256(1),
            address(adversarialExerciseRouter),
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q
        );
    }

    /*//////////////////////////////////////////////////////////////
                  G8B-1, G8B-2 — AUTHORIZATION REQUIRED
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the configured router's identity alone classifies nothing.
    /// @dev The proposal is exactly the shape an authorized exercise takes — the configured service pool,
    ///      the protected direction, exact output, a plausible quantity, the qualification boundary — from
    ///      exactly the configured ExerciseRouter. With no authorization behind it there is no O2 operation
    ///      in progress, so the Hook treats it as the ordinary swap it is and refuses it at the ordinary
    ///      perimeter, which the ExerciseRouter is not.
    function test_configuredRouterIdentityAlone_doesNotClassifyO2() public {
        _establishExercisable(CANONICAL_ENTITLEMENT);

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__UntrustedSwapPerimeter.selector, address(adversarialExerciseRouter)
            )
        );
        adversarialExerciseRouter.swapWithoutAuthorization(
            servicePoolKey, _protectedExactOutputSwapParams(EXERCISE_Q), bytes("")
        );

        _assertNoAuthorizationContext("an unauthorized swap must create no causal context");
    }

    /// @notice Proves a payload that imitates a causal context manufactures nothing.
    /// @dev The Hook never reads `hookData`, and the point of asserting it is that a payload naming the
    ///      service, a commitment, the configured router, the exercise authority, the Beneficiary, and a
    ///      quantity changes no outcome at all — the refusal is byte-for-byte the one the empty payload
    ///      produced.
    function test_forgedCausalPayload_manufacturesNoAuthorization() public {
        _establishExercisable(CANONICAL_ENTITLEMENT);

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__UntrustedSwapPerimeter.selector, address(adversarialExerciseRouter)
            )
        );
        adversarialExerciseRouter.swapWithoutAuthorization(
            servicePoolKey, _protectedExactOutputSwapParams(EXERCISE_Q), forgedCausalPayload
        );

        _assertNoAuthorizationContext("a forged payload must create no causal context");
    }

    /*//////////////////////////////////////////////////////////////
                    G8B-3 — EXACT OPERATION IDENTITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an authorized exercise of exactly the admitted shape is classified O2.
    /// @dev The positive control for every rejection below, and the reason they are attributable. The same
    ///      hostile router, the same authorization, and the one operation the Hook admits: it executes, and
    ///      the resulting evidence carries the bindings the authorization resolved. Classification is a
    ///      property of the operation rather than of the contract proposing it.
    function test_authorizedExactOperation_isClassifiedO2() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        vm.prank(commitmentExerciseAuthority);
        adversarialExerciseRouter.authorizeThenSwap(
            commitmentId, EXERCISE_Q, servicePoolKey, _protectedExactOutputSwapParams(EXERCISE_Q), bytes("")
        );

        _assertExercisedContext(
            commitmentId,
            commitmentExerciseAuthority,
            beneficiary,
            EXERCISE_Q,
            "the exact admitted operation must be classified as the O2 execution"
        );
    }

    /// @notice Proves a forged payload changes nothing about an operation that is genuinely authorized.
    /// @dev The complement of the manufacture case. `hookData` cannot create classification, and it cannot
    ///      disturb it either: the same admitted operation with an imitative payload executes identically.
    function test_forgedCausalPayload_changesNothingAboutAnAuthorizedExecution() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        vm.prank(commitmentExerciseAuthority);
        adversarialExerciseRouter.authorizeThenSwap(
            commitmentId, EXERCISE_Q, servicePoolKey, _protectedExactOutputSwapParams(EXERCISE_Q), forgedCausalPayload
        );

        _assertExercisedContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, EXERCISE_Q, "hookData may not change an outcome"
        );
    }

    /// @notice Proves a substituted quantity cannot satisfy the authorization.
    /// @dev One raw unit either side, and nothing at all. Each is a different operation from the one the
    ///      authorization admits, and the exercise it would perform is not the exercise that was decided.
    function test_substitutedQuantity_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _expectExecutionMismatch(_protectedExactOutputSwapParams(EXERCISE_Q - 1));
        _authorizeThenSwap(commitmentId, _protectedExactOutputSwapParams(EXERCISE_Q - 1));

        _expectExecutionMismatch(_protectedExactOutputSwapParams(EXERCISE_Q + 1));
        _authorizeThenSwap(commitmentId, _protectedExactOutputSwapParams(EXERCISE_Q + 1));
    }

    /// @notice Proves an exact-input swap cannot satisfy an exact-output authorization.
    /// @dev Under the pinned v4 convention a negative `amountSpecified` names a desired input, so the same
    ///      magnitude in the same direction at the same boundary is still a different operation: it fixes
    ///      what the exerciser spends instead of what the Beneficiary is owed.
    function test_exactInputSubstitution_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SwapParams memory exactInput = _protectedSwapParams(EXERCISE_Q);

        _expectExecutionMismatch(exactInput);
        _authorizeThenSwap(commitmentId, exactInput);
    }

    /// @notice Proves the opposite direction cannot satisfy the authorization.
    function test_substitutedDirection_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SwapParams memory opposite = _swapParams(false, int256(EXERCISE_Q), StandbyFixtureConfig.TICK_O);

        _expectExecutionMismatch(opposite);
        _authorizeThenSwap(commitmentId, opposite);
    }

    /// @notice Proves a substituted qualification boundary cannot satisfy the authorization.
    /// @dev Everything else matches: the pool, the direction, exact output, the exact quantity. The price
    ///      limit is the service's own execution-quality boundary, and an exercise executed against a
    ///      different one is not the exercise the service promised.
    function test_substitutedQualificationBoundary_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SwapParams memory shiftedBoundary =
            _swapParams(true, int256(EXERCISE_Q), StandbyFixtureConfig.TICK_Q + StandbyFixtureConfig.TICK_SPACING);

        _expectExecutionMismatch(shiftedBoundary);
        _authorizeThenSwap(commitmentId, shiftedBoundary);
    }

    /// @notice Proves no other pool can carry the authorized execution.
    /// @dev A Hook address encodes its permissions, so anyone may bind this Hook to another pool. That pool
    ///      is not this service, and an authorization for this service cannot be executed against it.
    function test_substitutedPool_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        PoolKey memory foreignKey = PoolKey({
            currency0: Currency.wrap(address(ustb)),
            currency1: Currency.wrap(address(usdc)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        poolManager.initialize(foreignKey, TickMath.getSqrtPriceAtTick(0));

        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(StandbyHook.StandbyHook__PoolIsNotConfiguredService.selector, foreignKey.toId())
        );

        vm.prank(commitmentExerciseAuthority);
        adversarialExerciseRouter.authorizeThenSwap(
            commitmentId, EXERCISE_Q, foreignKey, _protectedExactOutputSwapParams(EXERCISE_Q), bytes("")
        );
    }

    /*//////////////////////////////////////////////////////////////
                       G8B-11 — EXACTLY ONE SWAP
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves one authorization admits exactly one swap, whatever the second one looks like.
    /// @dev Both shapes of second interaction inside the same unlock: a repeat of the admitted execution,
    ///      and an unrelated ordinary swap. Neither may proceed, because the causal context is no longer
    ///      AUTHORIZED once its execution has happened — a second execution and a nested unrelated
    ///      interaction are the same refusal.
    function test_secondSwapInsideOneAuthorization_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SwapParams memory admitted = _protectedExactOutputSwapParams(EXERCISE_Q);

        _expectExecutedContextRejection();

        vm.prank(commitmentExerciseAuthority);
        adversarialExerciseRouter.authorizeThenSwapTwice(commitmentId, EXERCISE_Q, servicePoolKey, admitted, admitted);

        _expectExecutedContextRejection();

        vm.prank(commitmentExerciseAuthority);
        adversarialExerciseRouter.authorizeThenSwapTwice(
            commitmentId, EXERCISE_Q, servicePoolKey, admitted, _protectedSwapParams(1_000_000_000)
        );
    }

    /// @notice Proves a second authorization cannot coexist with an unresolved one.
    /// @dev Attempted before anything executes, so the refusal is about the causal context alone rather
    ///      than about execution evidence.
    function test_secondAuthorization_isRejected() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        vm.expectRevert(StandbyHook.StandbyHook__ExerciseAuthorizationAlreadyActive.selector);

        vm.prank(commitmentExerciseAuthority);
        adversarialExerciseRouter.authorizeTwice(commitmentId, EXERCISE_Q, EXERCISE_Q);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev The context router of this fixture is the hostile coordinator the service was activated with.
    function _expectedContextRouter() internal view override returns (address router) {
        router = address(adversarialExerciseRouter);
    }

    /// @dev Authorizes the canonical quantity and then proposes some other operation against it.
    function _authorizeThenSwap(uint256 _commitmentId, SwapParams memory _params) internal {
        vm.prank(commitmentExerciseAuthority);
        adversarialExerciseRouter.authorizeThenSwap(_commitmentId, EXERCISE_Q, servicePoolKey, _params, bytes(""));
    }

    /// @dev Expects the refusal of an operation that is not the one the authorization admits.
    function _expectExecutionMismatch(SwapParams memory _params) internal {
        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotTheAuthorizedProtectedExecution.selector,
                _params.zeroForOne,
                _params.amountSpecified,
                _params.sqrtPriceLimitX96
            )
        );
    }

    /// @dev Expects the refusal of any swap proposed while an execution has already happened.
    function _expectExecutedContextRejection() internal {
        _expectHookRejection(
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ExerciseExecutionNotAuthorized.selector,
                StandbyHook.ExerciseAuthorizationState.EXECUTED
            )
        );
    }
}
