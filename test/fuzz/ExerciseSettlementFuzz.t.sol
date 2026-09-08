// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";

import {BaseExerciseSettlementTest} from "../shared/BaseExerciseSettlementTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Fuzz evidence that the authoritative settlement derivation is exact across the whole signed
///         delta domain and both protected directions (G8C-1 through G8C-4).
/// @dev The derivation is a side selection, a sign decision, and a conversion, and each of those is the
///      kind of thing that is right almost everywhere and wrong at an edge. Both delta halves are fuzzed
///      independently across the full `int128` range, in both directions, so no run can pass by reading
///      the correct side for the wrong reason or by being handed a comfortable value.
///
///      The expected outcome of every run is computed from the frozen meaning of a v4 delta — the input
///      side is the one the executed direction spends, and a negative amount is what the swap caller owes —
///      never from the production branch structure.
contract ExerciseSettlementDerivationFuzzTest is BaseExerciseSettlementTest {
    /*//////////////////////////////////////////////////////////////
                    AUTHORITATIVE DEBT DERIVATION
    //////////////////////////////////////////////////////////////*/

    /// @notice The debt is the executed direction's input side, and only when that side is a debt.
    function testFuzz_authoritativeDebt_isTheExecutedDirectionsInputSide(
        bool _zeroForOne,
        int128 _amount0,
        int128 _amount1
    ) public {
        SwapParams memory params = _exactOutputSwapParams(_zeroForOne, 1);

        int256 expectedInputSide = _zeroForOne ? int256(_amount0) : int256(_amount1);

        if (expectedInputSide >= 0) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ExerciseRouter.ExerciseRouter__NoAuthoritativeInputDebt.selector, expectedInputSide
                )
            );
            settlementExerciseRouter.executedExerciseSettlement(
                servicePoolKey, params, toBalanceDelta(_amount0, _amount1)
            );

            return;
        }

        (Currency inputCurrency, Currency outputCurrency, uint256 actualInput) = settlementExerciseRouter
            .executedExerciseSettlement(servicePoolKey, params, toBalanceDelta(_amount0, _amount1));

        assertEq(
            Currency.unwrap(inputCurrency),
            _zeroForOne ? address(ustb) : address(usdc),
            "the spent currency must be the one the executed direction spends"
        );
        assertEq(
            Currency.unwrap(outputCurrency),
            _zeroForOne ? address(usdc) : address(ustb),
            "the produced currency must be the one the executed direction produces"
        );
        assertEq(actualInput, uint256(-expectedInputSide), "the debt must be the exact magnitude of the input side");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds an exact-output swap in either direction, confined to that direction's boundary.
    function _exactOutputSwapParams(bool _zeroForOne, uint256 _amountOut)
        internal
        pure
        returns (SwapParams memory params)
    {
        params = _swapParams(
            _zeroForOne, int256(_amountOut), _zeroForOne ? StandbyFixtureConfig.TICK_Q : StandbyFixtureConfig.TICK_O
        );
    }
}

/// @notice Fuzz evidence that a real exercise settles and delivers exactly, under every cost bound
///         (G8C-2, G8C-5, G8C-8, G8C-10, G8C-12, G8C-16).
/// @dev The counterpart to the derivation properties above, on the real stack and with nothing seeded: an
///      authentic commitment, the production authorization, the production execution, and the production
///      settlement and delivery against the real pinned PoolManager.
///
///      Both fuzzed dimensions are the ones a wrong implementation would get away with at a chosen point.
///      The quantity is explored across the whole admissible extent, and the cost bound across a range that
///      straddles the authoritative debt from below and above — where the debt itself is obtained from
///      production's own refusal rather than from an estimate, so the boundary is the real one.
contract ExerciseSettlementQuantityFuzzTest is BaseExerciseSettlementTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /// @dev The exercise quantity used where the quantity is not what is being fuzzed: 20,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 20_000_000_000;

    /*//////////////////////////////////////////////////////////////
                      EXACT SETTLEMENT AND DELIVERY
    //////////////////////////////////////////////////////////////*/

    /// @notice Every admissible quantity settles the exact debt and delivers exactly that quantity.
    function testFuzz_exercise_settlesTheExactDebtAndDeliversExactlyQ(uint256 _qSeed) public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 q = _bound(_qSeed, 1, CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, q);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, q);

        _assertExactSettlementAndDelivery(before, commitmentExerciseAuthority, commitmentId, q, actualInput);
        _assertNoFulfillmentConsequence(
            before, commitmentExerciseAuthority, commitmentId, "no quantity may fulfil anything"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          EXACT COST BOUND
    //////////////////////////////////////////////////////////////*/

    /// @notice An exercise proceeds if and only if the authoritative debt is within the requested bound.
    /// @dev The bound is fuzzed on both sides of the real debt, so the accepted and refused regions meet
    ///      exactly at equality. A run that is refused must be refused for the debt production derived —
    ///      the reported pair is checked, not just the selector — and must leave nothing behind.
    function testFuzz_costBound_admitsExactlyTheAuthoritativeDebt(uint256 _boundSeed) public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        uint256 maxInput = _bound(_boundSeed, actualInput - 1000, actualInput + 1000);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        if (actualInput > maxInput) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ExerciseRouter.ExerciseRouter__ExerciseCostExceedsMaxInput.selector, actualInput, maxInput
                )
            );
        }

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q, maxInput);

        if (actualInput > maxInput) {
            _assertNoExerciseResidue(before, commitmentExerciseAuthority, commitmentId);
        } else {
            _assertExactSettlementAndDelivery(
                before, commitmentExerciseAuthority, commitmentId, EXERCISE_Q, actualInput
            );
        }
    }
}
