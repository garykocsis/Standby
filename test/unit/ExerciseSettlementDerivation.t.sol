// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BalanceDelta, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";

import {UnfinalizedExerciseRouter} from "../harness/UnfinalizedExerciseRouter.sol";
import {BaseExerciseSettlementTest} from "../shared/BaseExerciseSettlementTest.t.sol";
import {BaseUnbackedExerciseAuthorizationTest} from "../shared/BaseUnbackedExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Unit evidence for the authoritative settlement derivation of an executed protected swap
///         (G8C-1 through G8C-4).
/// @dev The derivation answers three questions about one executed operation: which currency it spends,
///      which currency it produces, and how much it owes. All three come from the operation itself and the
///      `BalanceDelta` the PoolManager produced for it, and getting any of them wrong would settle the
///      wrong currency, deliver the wrong currency, or pay the wrong amount — while every surrounding
///      check still passed.
///
///      The real PoolManager cannot produce the cases that matter here. It will only ever hand back a
///      well-formed delta for a swap it actually performed, so a wrong-signed input side, a zero input
///      side, and a delta whose negative amount is on the output side are all unreachable in production —
///      which is precisely why the derivation must refuse them and why refusing them is verifiable only
///      through the harness pass-through. Everything below is the production derivation running unmodified.
contract ExerciseSettlementDerivationTest is BaseExerciseSettlementTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A plausible protected-output amount: 20,000 MockUSDC.
    int128 internal constant PLAUSIBLE_OUTPUT = 20_000_000_000;

    /// @dev The debt a plausible protected execution of that quantity would owe.
    int128 internal constant PLAUSIBLE_DEBT = -20_050_000_000;

    /*//////////////////////////////////////////////////////////////
                    G8C-1 — AUTHORITATIVE CURRENCIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a protected `zeroForOne` execution spends currency0 and produces currency1.
    function test_protectedDirection_spendsCurrency0AndProducesCurrency1() public view {
        (Currency inputCurrency, Currency outputCurrency, uint256 actualInput) = settlementExerciseRouter
            .executedExerciseSettlement(
            servicePoolKey, _protectedExactOutputSwapParams(uint256(uint128(PLAUSIBLE_OUTPUT))), _delta()
        );

        assertEq(Currency.unwrap(inputCurrency), address(ustb), "currency0 is spent in the protected direction");
        assertEq(Currency.unwrap(outputCurrency), address(usdc), "currency1 is produced in the protected direction");
        assertEq(actualInput, uint256(uint128(-PLAUSIBLE_DEBT)), "the debt is the currency0 side of the delta");
    }

    /// @notice Proves a `oneForZero` execution spends currency1 and produces currency0.
    /// @dev The mirror, on the same delta. Only the direction of the executed operation changes, and it
    ///      changes which side of the delta is the debt as well as which currency each side names — so a
    ///      derivation that had hardcoded the canonical fixture's direction would report the output side as
    ///      the amount owed and settle it in the wrong currency.
    function test_oppositeDirection_spendsCurrency1AndProducesCurrency0() public view {
        (Currency inputCurrency, Currency outputCurrency, uint256 actualInput) = settlementExerciseRouter
            .executedExerciseSettlement(
            servicePoolKey, _oppositeExactOutputSwapParams(uint256(uint128(PLAUSIBLE_OUTPUT))), _mirroredDelta()
        );

        assertEq(Currency.unwrap(inputCurrency), address(usdc), "currency1 is spent in the opposite direction");
        assertEq(Currency.unwrap(outputCurrency), address(ustb), "currency0 is produced in the opposite direction");
        assertEq(actualInput, uint256(uint128(-PLAUSIBLE_DEBT)), "the debt is the currency1 side of the delta");
    }

    /*//////////////////////////////////////////////////////////////
              G8C-2, G8C-3 — SIGNED INTERPRETATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a credit-signed input side is refused rather than settled.
    /// @dev A positive amount is currency the PoolManager owes, and there is no sense in which it is an
    ///      amount to be paid. Taking its magnitude would produce a plausible-looking settlement out of a
    ///      delta that says the opposite of what settlement assumes.
    function test_creditSignedInputSide_isRefused() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ExerciseRouter.ExerciseRouter__NoAuthoritativeInputDebt.selector, int256(PLAUSIBLE_OUTPUT)
            )
        );
        settlementExerciseRouter.executedExerciseSettlement(
            servicePoolKey,
            _protectedExactOutputSwapParams(uint256(uint128(PLAUSIBLE_OUTPUT))),
            toBalanceDelta(PLAUSIBLE_OUTPUT, PLAUSIBLE_OUTPUT)
        );
    }

    /// @notice Proves a zero input side is refused rather than settled as a free exercise.
    function test_zeroInputSide_isRefused() public {
        vm.expectRevert(
            abi.encodeWithSelector(ExerciseRouter.ExerciseRouter__NoAuthoritativeInputDebt.selector, int256(0))
        );
        settlementExerciseRouter.executedExerciseSettlement(
            servicePoolKey,
            _protectedExactOutputSwapParams(uint256(uint128(PLAUSIBLE_OUTPUT))),
            toBalanceDelta(0, PLAUSIBLE_OUTPUT)
        );
    }

    /// @notice Proves the debt is read from the executed direction's input side, not from whichever side
    ///         happens to be negative.
    /// @dev The delta here is the canonical one with its halves exchanged: the debt sits on the protected
    ///      output side and the credit on the input side. A derivation that searched for a negative amount
    ///      would find one, settle the output currency, and be wrong twice; this one refuses, because the
    ///      side it must read is decided by the operation and not by the values.
    function test_debtOnTheWrongSide_isRefused() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ExerciseRouter.ExerciseRouter__NoAuthoritativeInputDebt.selector, int256(PLAUSIBLE_OUTPUT)
            )
        );
        settlementExerciseRouter.executedExerciseSettlement(
            servicePoolKey,
            _protectedExactOutputSwapParams(uint256(uint128(PLAUSIBLE_OUTPUT))),
            toBalanceDelta(PLAUSIBLE_OUTPUT, PLAUSIBLE_DEBT)
        );
    }

    /*//////////////////////////////////////////////////////////////
                      G8C-4 — SAFE CONVERSION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the extreme of the signed delta domain converts exactly rather than wrapping.
    /// @dev `type(int128).min` is the one value whose negation is not representable in its own type, and
    ///      negating it in place would wrap back to itself — turning the largest debt the PoolManager can
    ///      express into a nonsensical magnitude. Widening before negating converts it exactly.
    function test_minimumSignedDebt_convertsExactly() public view {
        (,, uint256 actualInput) = settlementExerciseRouter.executedExerciseSettlement(
            servicePoolKey,
            _protectedExactOutputSwapParams(uint256(uint128(PLAUSIBLE_OUTPUT))),
            toBalanceDelta(type(int128).min, PLAUSIBLE_OUTPUT)
        );

        assertEq(actualInput, 2 ** 127, "the minimum signed delta must convert to its exact magnitude");
    }

    /// @notice Proves the smallest expressible debt is a debt.
    /// @dev One raw unit is not nothing, and the boundary between "refused" and "settled" is exactly at
    ///      zero rather than near it.
    function test_smallestSignedDebt_isSettleable() public view {
        (,, uint256 actualInput) = settlementExerciseRouter.executedExerciseSettlement(
            servicePoolKey,
            _protectedExactOutputSwapParams(uint256(uint128(PLAUSIBLE_OUTPUT))),
            toBalanceDelta(-1, PLAUSIBLE_OUTPUT)
        );

        assertEq(actualInput, 1, "one raw unit of debt must be settleable");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev The delta a plausible protected execution would produce: currency0 owed, currency1 received.
    function _delta() internal pure returns (BalanceDelta delta) {
        delta = toBalanceDelta(PLAUSIBLE_DEBT, PLAUSIBLE_OUTPUT);
    }

    /// @dev The same delta for the opposite direction: currency1 owed, currency0 received.
    function _mirroredDelta() internal pure returns (BalanceDelta delta) {
        delta = toBalanceDelta(PLAUSIBLE_OUTPUT, PLAUSIBLE_DEBT);
    }

    /// @dev Builds an opposite-direction exact-output swap confined to the service domain.
    function _oppositeExactOutputSwapParams(uint256 _amountOut) internal pure returns (SwapParams memory params) {
        params = _swapParams(false, int256(_amountOut), StandbyFixtureConfig.TICK_O);
    }
}

/// @notice Unit evidence that settlement and delivery require the Hook's own execution proof (G8C-14).
/// @dev Resolution moves an exerciser's currency and pays a Beneficiary, and the only authority that any of
///      that is owed is the Hook-owned causal context reaching `EXECUTED`. In production that position is
///      the only one resolution can ever encounter, because it runs immediately after a swap the Hook
///      accepted and proved — which is exactly why the refusal of every other position is unreachable there
///      and has to be presented directly.
///
///      The router under test is a fresh production router rather than the configured one, and it is
///      deliberately not the coordinator this service was activated with. It still refuses, because what
///      authorizes resolution is the causal position rather than the identity of whoever asks.
contract ExerciseSettlementCausalPrerequisiteTest is BaseUnbackedExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The authorized quantity every seeded context carries: 20,000 MockUSDC.
    uint256 internal constant SEEDED_Q = 20_000_000_000;

    /// @dev The debt a plausible protected execution of that quantity would owe.
    int128 internal constant PLAUSIBLE_DEBT = -20_050_000_000;

    /// @dev A production router bound to this fixture's Hook, with its resolution reachable directly.
    UnfinalizedExerciseRouter internal resolvingRouter;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds a directly reachable production resolution path to the harness fixture.
    function setUp() public virtual override {
        super.setUp();

        resolvingRouter = new UnfinalizedExerciseRouter(hook);
    }

    /*//////////////////////////////////////////////////////////////
                  G8C-14 — EXECUTION PROOF REQUIRED
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an absent causal context authorizes no settlement and no delivery.
    function test_absentContext_authorizesNoResolution() public {
        _expectResolutionRefusal(StandbyHook.ExerciseAuthorizationState.EMPTY);

        _resolve();
    }

    /// @notice Proves an authorization that has not executed authorizes no settlement and no delivery.
    /// @dev The complete bindings are present — this commitment, this exerciser, this Beneficiary, this
    ///      quantity — and every one of them is what a resolution would need. What is missing is the only
    ///      thing that makes a debt exist: proof that the swap happened.
    function test_authorizedButUnexecutedContext_authorizesNoResolution() public {
        _seedContext(StandbyHook.ExerciseAuthorizationState.AUTHORIZED);

        _expectResolutionRefusal(StandbyHook.ExerciseAuthorizationState.AUTHORIZED);

        _resolve();
    }

    /// @notice Proves a swap that is merely in flight authorizes no settlement and no delivery.
    /// @dev `EXECUTING` means the Hook accepted the proposal, not that the pool produced anything. Settling
    ///      against it would pay for an execution whose actual result has not been seen.
    function test_inFlightContext_authorizesNoResolution() public {
        _seedContext(StandbyHook.ExerciseAuthorizationState.EXECUTING);

        _expectResolutionRefusal(StandbyHook.ExerciseAuthorizationState.EXECUTING);

        _resolve();
    }

    /// @notice Proves an in-flight authorization decision authorizes no settlement and no delivery.
    function test_undecidedContext_authorizesNoResolution() public {
        _seedContext(StandbyHook.ExerciseAuthorizationState.AUTHORIZING);

        _expectResolutionRefusal(StandbyHook.ExerciseAuthorizationState.AUTHORIZING);

        _resolve();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Presents a plausible executed exercise to the production resolution.
    function _resolve() internal {
        resolvingRouter.resolveExecutedExercise(
            servicePoolKey,
            _protectedExactOutputSwapParams(SEEDED_Q),
            toBalanceDelta(PLAUSIBLE_DEBT, int128(int256(SEEDED_Q))),
            type(uint256).max
        );
    }

    /// @dev Expects the refusal of a resolution offered against a causal position that proves nothing.
    function _expectResolutionRefusal(StandbyHook.ExerciseAuthorizationState _state) internal {
        vm.expectRevert(abi.encodeWithSelector(ExerciseRouter.ExerciseRouter__ExerciseNotExecuted.selector, _state));
    }

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
