// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {TickMath} from "v4-core/libraries/TickMath.sol";
import {toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseExerciseAuthorizationTest} from "../shared/BaseExerciseAuthorizationTest.t.sol";
import {BaseUnbackedExerciseAuthorizationTest} from "../shared/BaseUnbackedExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Fuzz evidence that O2 classification and execution evidence are exact (G8B-3, G8B-9).
/// @dev The two F8B decisions are equality decisions, and an equality decision is exactly the kind that
///      fails at one raw unit, one tick, or one flipped flag. Both are therefore explored across their
///      whole input shape rather than at chosen points: an operation is admitted if and only if it is the
///      one the service defines for the authorized quantity, and a delta is execution evidence if and only
///      if its protected-output side is exactly that quantity.
///
///      Both properties are stated independently of the production branch structure. The expected outcome
///      of every run is computed from the frozen service semantics — the canonical protected direction, the
///      exact-output convention of the pinned `SwapParams`, the authorized quantity, and the configured
///      qualification boundary — and never from the derivation under test.
///
///      The causal positions these mechanics guard exist only inside a PoolManager call frame, so the
///      harness supplies the starting position and nothing else. Every predicate exercised is production.
contract ProtectedExecutionFuzzTest is BaseUnbackedExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The authorized quantity every seeded context carries: 20,000 MockUSDC.
    uint256 internal constant SEEDED_Q = 20_000_000_000;

    /// @dev The input side of a plausible protected execution delta.
    int128 internal constant PLAUSIBLE_INPUT = -20_050_000_000;

    /// @dev The span of limit ticks explored. Wide enough to include both service boundaries, both
    ///      liquidity boundaries, and the current price, so a near miss is as likely as a far one.
    int24 internal constant LIMIT_TICK_SPAN = 600;

    /*//////////////////////////////////////////////////////////////
                        O2 OPERATION IDENTITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Exactly one operation is the authorized protected execution.
    /// @dev Direction, mode and quantity, and qualification boundary are fuzzed together, so a run misses
    ///      on one conjunct, several, or none. The admitted case is the single point where all three agree
    ///      with the service's own definition; everything else is refused, and the refusal names the
    ///      operation that was proposed.
    function testFuzz_onlyTheServiceDefinedOperation_isClassifiedO2(
        bool _zeroForOne,
        int256 _amountSeed,
        int24 _limitTickSeed
    ) public {
        int256 amountSpecified = bound(_amountSeed, -int256(SEEDED_Q) - 2, int256(SEEDED_Q) + 2);
        int24 limitTick = int24(bound(int256(_limitTickSeed), -LIMIT_TICK_SPAN, LIMIT_TICK_SPAN));

        SwapParams memory proposed = SwapParams({
            zeroForOne: _zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(limitTick)
        });

        bool admitted = _zeroForOne == StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE
            && amountSpecified == int256(SEEDED_Q) && limitTick == StandbyFixtureConfig.TICK_Q;

        _seedContext(StandbyHook.ExerciseAuthorizationState.AUTHORIZED);

        if (!admitted) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    StandbyHook.StandbyHook__NotTheAuthorizedProtectedExecution.selector,
                    proposed.zeroForOne,
                    proposed.amountSpecified,
                    proposed.sqrtPriceLimitX96
                )
            );
        }

        serviceHarness.beginProtectedExecution(exerciseRouter, proposed);

        assertEq(
            uint256(_authorizationContext().state),
            uint256(
                admitted
                    ? StandbyHook.ExerciseAuthorizationState.EXECUTING
                    : StandbyHook.ExerciseAuthorizationState.AUTHORIZED
            ),
            "only the service-defined operation may advance the causal context"
        );
    }

    /// @notice No account other than the bound ExerciseRouter can propose the authorized execution.
    /// @dev The operation is the admitted one on every run, so the sender is the only thing deciding.
    function testFuzz_onlyTheBoundRouter_mayProposeTheExecution(address _sender) public {
        _seedContext(StandbyHook.ExerciseAuthorizationState.AUTHORIZED);

        if (_sender != exerciseRouter) {
            vm.expectRevert(
                abi.encodeWithSelector(StandbyHook.StandbyHook__NotAuthorizedExerciseExecutor.selector, _sender)
            );
        }

        serviceHarness.beginProtectedExecution(_sender, _protectedExactOutputSwapParams(SEEDED_Q));
    }

    /*//////////////////////////////////////////////////////////////
                        EXECUTION EVIDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Exactly the authorized quantity on the protected-output side, and nothing else, is evidence.
    /// @dev The output side is fuzzed across both signs and both sides of the authorized quantity, and the
    ///      input side is fuzzed independently so that no run can pass by reading the wrong half of the
    ///      delta. Partial output, excess output, a debt-signed amount, and nothing at all are all refused
    ///      by the same comparison.
    function testFuzz_onlyExactlyQ_isExecutionEvidence(int128 _outputSeed, int128 _inputSeed) public {
        int128 output = int128(bound(int256(_outputSeed), -int256(SEEDED_Q) - 3, int256(SEEDED_Q) + 3));
        int128 input = int128(bound(int256(_inputSeed), -int256(SEEDED_Q) * 2, int256(SEEDED_Q) * 2));

        _seedContext(StandbyHook.ExerciseAuthorizationState.EXECUTING);

        bool executed = output == int128(int256(SEEDED_Q));

        if (!executed) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    StandbyHook.StandbyHook__ProtectedOutputNotExecuted.selector, int256(output), SEEDED_Q
                )
            );
        }

        serviceHarness.recordProtectedExecution(
            exerciseRouter, servicePoolKey, _protectedExactOutputSwapParams(SEEDED_Q), toBalanceDelta(input, output)
        );

        assertEq(
            uint256(_authorizationContext().state),
            uint256(
                executed
                    ? StandbyHook.ExerciseAuthorizationState.EXECUTED
                    : StandbyHook.ExerciseAuthorizationState.EXECUTING
            ),
            "only exactly the authorized protected output may establish execution"
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
}

/// @notice Fuzz evidence that a real authorized exercise produces exactly its authorized quantity
///         (G8B-9, G8B-13, G8B-14).
/// @dev The counterpart to the harness properties above, on the real stack and with nothing seeded: an
///      authentic commitment, the production authorization, the production execution coordination, and the
///      real pinned PoolManager. The quantity is fuzzed across the whole admissible extent, and each run
///      requires the currency that actually left the pool to equal it exactly, the F5 prediction to equal
///      the state the pool reached, and the commitment to be exactly as it was.
contract ProtectedExecutionQuantityFuzzTest is BaseExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /*//////////////////////////////////////////////////////////////
                    EXACT REAL PROTECTED OUTPUT
    //////////////////////////////////////////////////////////////*/

    /// @notice A real authorized exercise produces exactly `q`, at every admissible quantity.
    function testFuzz_authorizedExercise_producesExactlyQ(uint256 _qSeed) public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 q = _bound(_qSeed, 1, CANONICAL_ENTITLEMENT);

        uint256 predictedCapacity = hook.prospectiveSupportingCapacityAfterSwap(_protectedExactOutputSwapParams(q));

        uint256 producedBefore = usdc.balanceOf(address(configuredExerciseRouter));

        _authorizeAs(commitmentExerciseAuthority, commitmentId, q);

        _assertExercisedContext(
            commitmentId, commitmentExerciseAuthority, beneficiary, q, "every admissible quantity must execute exactly"
        );

        assertEq(
            usdc.balanceOf(address(configuredExerciseRouter)) - producedBefore,
            q,
            "the pool must have produced exactly the authorized quantity"
        );
        assertEq(hook.supportingCapacity(), predictedCapacity, "the actual post-state must be the predicted one");
        assertEq(_referenceSupportingCapacity(), predictedCapacity, "the independent reconstruction must agree");
        assertEq(
            hook.commitment(commitmentId).remainingEntitlement,
            CANONICAL_ENTITLEMENT,
            "execution evidence must fulfil nothing"
        );
    }
}
