// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {DeployStandbyHook} from "../../script/DeployStandbyHook.s.sol";
import {DeterministicFixtureDeployer} from "../../script/helpers/DeterministicFixtureDeployer.sol";
import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {IEligibilityRegistry} from "../../src/interfaces/IEligibilityRegistry.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockUSTB} from "../../src/mocks/MockUSTB.sol";

import {StandbyHookHarness} from "../harness/StandbyHookHarness.sol";
import {BaseUnbackedExerciseAuthorizationTest} from "../shared/BaseUnbackedExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Isolated evidence for the F8B causal transitions and for execution evidence the real
///         PoolManager cannot produce (G8B-5, G8B-6, G8B-8 through G8B-11).
/// @dev Two kinds of situation live here, and neither is reachable from production for the same reason:
///      the system works.
///
///      The first is malformed execution evidence. Production evidence is the PoolManager's own
///      `BalanceDelta` for a swap it has just performed, so a delta on the wrong currency side, with the
///      wrong sign, or for an amount the swap did not produce cannot arise on any authentic path. Refusing
///      such evidence is nonetheless a requirement, and verifying that refusal means presenting evidence no
///      real swap would.
///
///      The second is a causal position held open across a call. `EXECUTING` exists only between one
///      `beforeSwap` and its own `afterSwap`, inside a single PoolManager call frame nothing else can
///      enter, so the transitions guarding it can only be addressed one at a time from outside.
///
///      The harness supplies exactly that: the ability to write a causal position and to hand the two
///      production mechanics facts of the test's choosing. It adds no check and removes none — the
///      predicates being exercised are the production ones, running against production causal state. What
///      is harness-created is the starting position, and nothing here may be read as evidence about
///      authorization, admission, enforcement, integration, or acceptance behavior.
contract ProtectedExecutionEvidenceTest is BaseUnbackedExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The authorized quantity every seeded context carries: 20,000 MockUSDC.
    uint256 internal constant SEEDED_Q = 20_000_000_000;

    /// @dev The input side of a plausible protected execution delta. Its exact value is irrelevant: the
    ///      evidence comparison reads the protected-output side and nothing else.
    int128 internal constant PLAUSIBLE_INPUT = -20_050_000_000;

    /*//////////////////////////////////////////////////////////////
                    G8B-5 — BEFORESWAP IS NOT EXECUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a matching proposal reaches the in-flight position and can reach nothing further.
    /// @dev The whole distinction F8B rests on. The proposal is the exact admitted operation from the exact
    ///      bound router, and accepting it establishes only that the swap now in front of the PoolManager is
    ///      the authorized one. It is not evidence that any execution occurred, so the context advances to
    ///      `EXECUTING` and stops there.
    function test_matchingProposal_reachesExecutingAndNotExecuted() public {
        _seedContext(StandbyHook.ExerciseAuthorizationState.AUTHORIZED);

        serviceHarness.beginProtectedExecution(exerciseRouter, _protectedExactOutputSwapParams(SEEDED_Q));

        assertEq(
            uint256(_authorizationContext().state),
            uint256(StandbyHook.ExerciseAuthorizationState.EXECUTING),
            "an accepted proposal must reach EXECUTING"
        );
    }

    /// @notice Proves no causal position other than AUTHORIZED admits a protected execution.
    /// @dev The one restriction that covers a swap proposed before an authorization has decided, a second
    ///      swap while one is in flight, and another swap after execution.
    function test_onlyAnAuthorizedContext_admitsAProtectedExecution() public {
        StandbyHook.ExerciseAuthorizationState[3] memory refused = [
            StandbyHook.ExerciseAuthorizationState.AUTHORIZING,
            StandbyHook.ExerciseAuthorizationState.EXECUTING,
            StandbyHook.ExerciseAuthorizationState.EXECUTED
        ];

        for (uint256 i = 0; i < refused.length; ++i) {
            _seedContext(refused[i]);

            vm.expectRevert(
                abi.encodeWithSelector(
                    StandbyHook.StandbyHook__ExerciseExecutionNotAuthorized.selector, uint8(refused[i])
                )
            );
            serviceHarness.beginProtectedExecution(exerciseRouter, _protectedExactOutputSwapParams(SEEDED_Q));
        }
    }

    /*//////////////////////////////////////////////////////////////
                   G8B-9, G8B-10 — EXACT ACTUAL OUTPUT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves exactly the authorized protected output, and only that, establishes execution.
    function test_exactProtectedOutput_establishesExecution() public {
        _seedContext(StandbyHook.ExerciseAuthorizationState.EXECUTING);

        _recordEvidence(toBalanceDelta(PLAUSIBLE_INPUT, int128(int256(SEEDED_Q))));

        assertEq(
            uint256(_authorizationContext().state),
            uint256(StandbyHook.ExerciseAuthorizationState.EXECUTED),
            "exactly q on the protected-output side must establish execution"
        );
    }

    /// @notice Proves every malformed shape of execution evidence is refused.
    /// @dev Five different ways to be wrong, all failing the same exact comparison: one unit short, one unit
    ///      over, nothing at all, the right magnitude with the sign of a debt rather than a credit, and the
    ///      right magnitude on the input currency instead of the protected-output one.
    function test_malformedExecutionEvidence_isRefused() public {
        int128 q = int128(int256(SEEDED_Q));

        _expectRefusedEvidence(toBalanceDelta(PLAUSIBLE_INPUT, q - 1), int256(SEEDED_Q) - 1);
        _expectRefusedEvidence(toBalanceDelta(PLAUSIBLE_INPUT, q + 1), int256(SEEDED_Q) + 1);
        _expectRefusedEvidence(toBalanceDelta(PLAUSIBLE_INPUT, int128(0)), int256(0));
        _expectRefusedEvidence(toBalanceDelta(PLAUSIBLE_INPUT, -q), -int256(SEEDED_Q));
        _expectRefusedEvidence(toBalanceDelta(q, PLAUSIBLE_INPUT), int256(PLAUSIBLE_INPUT));
    }

    /// @notice Proves execution evidence is refused unless an execution is actually in flight.
    /// @dev `EMPTY -> EXECUTED` and `AUTHORIZED -> EXECUTED` are both refused, so intent can never become
    ///      evidence, and a second `EXECUTED` transition is refused so evidence can never be reused.
    function test_executionEvidence_requiresAnExecutionInFlight() public {
        StandbyHook.ExerciseAuthorizationState[3] memory refused = [
            StandbyHook.ExerciseAuthorizationState.EMPTY,
            StandbyHook.ExerciseAuthorizationState.AUTHORIZED,
            StandbyHook.ExerciseAuthorizationState.EXECUTED
        ];

        for (uint256 i = 0; i < refused.length; ++i) {
            _seedContext(refused[i]);

            vm.expectRevert(
                abi.encodeWithSelector(
                    StandbyHook.StandbyHook__NoProtectedExecutionInFlight.selector, uint8(refused[i])
                )
            );
            _recordEvidence(toBalanceDelta(PLAUSIBLE_INPUT, int128(int256(SEEDED_Q))));
        }
    }

    /// @notice Proves evidence must belong to the exact accepted operation, not merely arrive during one.
    /// @dev An in-flight execution does not make the next callback its own. Both conjuncts are falsified
    ///      separately: evidence presented by an account other than the bound ExerciseRouter, and evidence
    ///      claiming an operation other than the admitted one.
    function test_evidenceForAnotherOperation_isRefused() public {
        _seedContext(StandbyHook.ExerciseAuthorizationState.EXECUTING);

        BalanceDelta authentic = toBalanceDelta(PLAUSIBLE_INPUT, int128(int256(SEEDED_Q)));

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotAuthorizedExerciseExecutor.selector, address(swapPerimeter)
            )
        );
        serviceHarness.recordProtectedExecution(
            address(swapPerimeter), servicePoolKey, _protectedExactOutputSwapParams(SEEDED_Q), authentic
        );

        SwapParams memory otherOperation = _protectedExactOutputSwapParams(SEEDED_Q + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotTheAuthorizedProtectedExecution.selector,
                otherOperation.zeroForOne,
                otherOperation.amountSpecified,
                otherOperation.sqrtPriceLimitX96
            )
        );
        serviceHarness.recordProtectedExecution(exerciseRouter, servicePoolKey, otherOperation, authentic);

        assertEq(
            uint256(_authorizationContext().state),
            uint256(StandbyHook.ExerciseAuthorizationState.EXECUTING),
            "a refused presentation must not advance the context"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Writes a complete causal context at a chosen position, with authentic-looking bindings.
    function _seedContext(StandbyHook.ExerciseAuthorizationState _state) internal {
        serviceHarness.writeExerciseAuthorization(
            StandbyHook.ExerciseAuthorizationContext({
                state: _state,
                serviceId: servicePoolId,
                commitmentId: 1,
                exerciseRouter: exerciseRouter,
                exerciser: commitmentExerciseAuthority,
                beneficiary: beneficiary,
                q: SEEDED_Q
            })
        );
    }

    /// @dev Presents execution evidence for the admitted operation, from the bound router.
    function _recordEvidence(BalanceDelta _delta) internal {
        serviceHarness.recordProtectedExecution(
            exerciseRouter, servicePoolKey, _protectedExactOutputSwapParams(SEEDED_Q), _delta
        );
    }

    /// @dev Expects a presented delta to be refused as execution evidence, naming the output it carried.
    function _expectRefusedEvidence(BalanceDelta _delta, int256 _reportedOutput) internal {
        _seedContext(StandbyHook.ExerciseAuthorizationState.EXECUTING);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProtectedOutputNotExecuted.selector, _reportedOutput, SEEDED_Q
            )
        );
        _recordEvidence(_delta);
    }
}

/// @notice Isolated evidence that O2 classification and execution evidence follow the configured protected
///         direction (G8B-3, G8B-8).
/// @dev The canonical fixture is protected `zeroForOne`, so every other suite would pass unchanged if the
///      direction were hard-coded. This one activates a service whose protected direction is the mirror:
///      the protected output is currency0, the admitted execution is an exact-output swap in the
///      `oneForZero` direction, and the qualification boundary sits above the current price rather than
///      below it.
///
///      No liquidity, swap, or commitment is needed to establish the point, because neither mechanic under
///      test consults any of them: the admitted operation is reconstructed from the immutable service
///      basis and the authorized quantity, and the evidence comparison reads one side of a delta. The
///      service is real, activated by the production transition against a real initialized pool; the causal
///      context is harness-written, and is evidence about these two mechanics alone.
contract ProtectedExecutionDirectionTest is Test {
    using PoolIdLibrary for PoolKey;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The protected execution-quality boundary of a `oneForZero` service: above the current price.
    int24 internal constant MIRRORED_TICK_Q = 240;

    /// @dev The opposite realization-domain boundary of a `oneForZero` service.
    int24 internal constant MIRRORED_TICK_O = -240;

    /// @dev The authorized quantity, in raw units of the protected output currency0.
    uint256 internal constant SEEDED_Q = 20_000_000_000;

    address internal configurationAuthority;
    address internal mirroredExerciseRouter;

    IPoolManager internal poolManager;
    StandbyHookHarness internal serviceHarness;

    MockUSTB internal ustb;
    MockUSDC internal usdc;

    PoolKey internal servicePoolKey;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Activates a real service whose protected direction is `oneForZero`.
    function setUp() public {
        configurationAuthority = makeAddr("mirroredConfigurationAuthority");
        mirroredExerciseRouter = makeAddr("mirroredExerciseRouter");

        poolManager = IPoolManager(address(new PoolManager(address(this))));

        DeployStandbyHook deployer = new DeployStandbyHook();

        bytes memory constructorArgs = abi.encode(
            poolManager,
            configurationAuthority,
            makeAddr("mirroredUniversalRouter"),
            makeAddr("mirroredPositionManager")
        );

        (, bytes32 salt) = HookMiner.find(
            address(this),
            deployer.REQUIRED_HOOK_PERMISSION_MASK(),
            type(StandbyHookHarness).creationCode,
            constructorArgs
        );

        serviceHarness = new StandbyHookHarness{salt: salt}(
            poolManager,
            configurationAuthority,
            makeAddr("mirroredUniversalRouter"),
            makeAddr("mirroredPositionManager")
        );

        (ustb, usdc,) = new DeterministicFixtureDeployer().deployOrderedFixtureCurrencies();

        servicePoolKey = PoolKey({
            currency0: Currency.wrap(address(ustb)),
            currency1: Currency.wrap(address(usdc)),
            fee: StandbyFixtureConfig.LP_FEE,
            tickSpacing: StandbyFixtureConfig.TICK_SPACING,
            hooks: IHooks(address(serviceHarness))
        });

        poolManager.initialize(servicePoolKey, TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.INITIAL_TICK));

        vm.prank(configurationAuthority);
        serviceHarness.configureAndActivate(
            servicePoolKey,
            false,
            MIRRORED_TICK_Q,
            MIRRORED_TICK_O,
            IEligibilityRegistry(makeAddr("mirroredRegistry")),
            mirroredExerciseRouter,
            makeAddr("mirroredEstablishmentAuthority")
        );
    }

    /*//////////////////////////////////////////////////////////////
                     MIRRORED PROTECTED DIRECTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the admitted operation is the mirrored one, and the canonical one is refused.
    function test_mirroredService_admitsOnlyTheMirroredOperation() public {
        _seedContext(StandbyHook.ExerciseAuthorizationState.AUTHORIZED);

        SwapParams memory canonicalDirection = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(SEEDED_Q),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(MIRRORED_TICK_Q)
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotTheAuthorizedProtectedExecution.selector,
                canonicalDirection.zeroForOne,
                canonicalDirection.amountSpecified,
                canonicalDirection.sqrtPriceLimitX96
            )
        );
        serviceHarness.beginProtectedExecution(mirroredExerciseRouter, canonicalDirection);

        serviceHarness.beginProtectedExecution(mirroredExerciseRouter, _mirroredOperation());

        assertEq(
            uint256(serviceHarness.exerciseAuthorization().state),
            uint256(StandbyHook.ExerciseAuthorizationState.EXECUTING),
            "the mirrored operation must be the admitted one"
        );
    }

    /// @notice Proves the protected output is read from currency0 for a `oneForZero` service.
    /// @dev The mirror of the canonical evidence rule, and the reason it cannot be hard-coded: exactly `q`
    ///      on currency1 — the input side here — is refused, and exactly `q` on currency0 establishes
    ///      execution.
    function test_mirroredService_readsTheProtectedOutputFromCurrencyZero() public {
        _seedContext(StandbyHook.ExerciseAuthorizationState.EXECUTING);

        int128 q = int128(int256(SEEDED_Q));

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProtectedOutputNotExecuted.selector, int256(-20_050_000_000), SEEDED_Q
            )
        );
        serviceHarness.recordProtectedExecution(
            mirroredExerciseRouter, servicePoolKey, _mirroredOperation(), toBalanceDelta(-20_050_000_000, q)
        );

        serviceHarness.recordProtectedExecution(
            mirroredExerciseRouter, servicePoolKey, _mirroredOperation(), toBalanceDelta(q, -20_050_000_000)
        );

        assertEq(
            uint256(serviceHarness.exerciseAuthorization().state),
            uint256(StandbyHook.ExerciseAuthorizationState.EXECUTED),
            "currency0 must be the protected output of a oneForZero service"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev The exact-output protected execution a `oneForZero` service admits.
    function _mirroredOperation() internal pure returns (SwapParams memory params) {
        params = SwapParams({
            zeroForOne: false,
            amountSpecified: int256(SEEDED_Q),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(MIRRORED_TICK_Q)
        });
    }

    /// @dev Writes a complete causal context at a chosen position.
    function _seedContext(StandbyHook.ExerciseAuthorizationState _state) internal {
        serviceHarness.writeExerciseAuthorization(
            StandbyHook.ExerciseAuthorizationContext({
                state: _state,
                serviceId: servicePoolKey.toId(),
                commitmentId: 1,
                exerciseRouter: mirroredExerciseRouter,
                exerciser: makeAddr("mirroredExerciser"),
                beneficiary: makeAddr("mirroredBeneficiary"),
                q: SEEDED_Q
            })
        );
    }
}
