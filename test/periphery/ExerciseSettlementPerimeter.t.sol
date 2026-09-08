// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseExerciseSettlementTest} from "../shared/BaseExerciseSettlementTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Periphery evidence that the O2 coordinator acquires no economic authority by coordinating
///         settlement and delivery (G8C-7, G8C-11, G8C-13, G8C-14, G8C-15).
/// @dev Moving value is the point at which a coordinator is most likely to quietly become a principal. It
///      now pulls currency from an account and directs currency to another, and the question every test
///      below asks is the same one from a different angle: where did the authority for each of those come
///      from, and can anything outside the Hook supply it instead.
///
///      The answers are structural rather than defensive. The payer and the recipient are read from the
///      Hook-owned causal context, the amounts are read from authoritative PoolManager accounting, and the
///      request surface carries no field through which either could be named — so there is no path to close
///      rather than a path that is checked. What is verified here is that those structures hold: that the
///      settlement entry point cannot be reached except through the PoolManager, that a fully funded router
///      is still not a payer, that an account other than the exercise authority cannot buy its way in by
///      funding one, and that a resolved exercise cannot be resolved again.
contract ExerciseSettlementPerimeterTest is BaseExerciseSettlementTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical commitment entitlement: 50,000 MockUSDC.
    uint128 internal constant CANONICAL_ENTITLEMENT = uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);

    /// @dev The exercise quantity used throughout: 20,000 MockUSDC.
    uint256 internal constant EXERCISE_Q = 20_000_000_000;

    /*//////////////////////////////////////////////////////////////
                   G8C-14 — SETTLEMENT ENTRY AUTHORITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the settlement callback cannot be entered by anyone but the PoolManager.
    /// @dev The callback now carries the exerciser's own cost bound, and a caller who could invoke it
    ///      directly would be supplying that bound for someone else's exercise. It is refused before the
    ///      payload is used for anything, whoever the caller is and whatever bound the payload names.
    function test_directSettlementCallback_isRefused() public {
        _establishExercisable(CANONICAL_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(ExerciseRouter.ExerciseRouter__NotPoolManager.selector, unauthorizedExerciser)
        );

        vm.prank(unauthorizedExerciser);
        configuredExerciseRouter.unlockCallback(abi.encode(type(uint256).max));
    }

    /// @notice Proves the settlement callback establishes nothing even for the commitment's own authority.
    /// @dev The exercise authority is the one account that may exercise this commitment, and it still
    ///      cannot reach settlement except through the operation that produced a debt to settle.
    function test_directSettlementCallback_isRefusedForTheExerciseAuthority() public {
        _establishExercisable(CANONICAL_ENTITLEMENT);

        vm.expectRevert(
            abi.encodeWithSelector(ExerciseRouter.ExerciseRouter__NotPoolManager.selector, commitmentExerciseAuthority)
        );

        vm.prank(commitmentExerciseAuthority);
        configuredExerciseRouter.unlockCallback(abi.encode(type(uint256).max));
    }

    /*//////////////////////////////////////////////////////////////
                    G8C-7 — THE ROUTER IS NOT A PAYER
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a router holding both currencies in quantity funds nothing.
    /// @dev The router's balances are measured before and after a successful exercise. It could have paid
    ///      the whole debt many times over and its balance does not move by a single raw unit in either
    ///      currency, because the payer is a Hook-owned fact rather than whoever happens to have funds.
    function test_fundedRouter_neitherFundsNorReceives() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        uint256 routerInputBefore = ustb.balanceOf(address(configuredExerciseRouter));
        uint256 routerOutputBefore = usdc.balanceOf(address(configuredExerciseRouter));

        assertGt(routerInputBefore, actualInput, "the router must be able to cover the debt it must not pay");

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        assertEq(ustb.balanceOf(address(configuredExerciseRouter)), routerInputBefore, "the router is not the payer");
        assertEq(
            usdc.balanceOf(address(configuredExerciseRouter)),
            routerOutputBefore,
            "the router takes no protected-output custody"
        );
    }

    /// @notice Proves a third party cannot become the payer by funding and approving the router.
    /// @dev The account is funded exactly as an exerciser would be and approves the router exactly as an
    ///      exerciser would. It is refused for the only reason that matters — it is not the commitment's
    ///      exercise authority — and its balance is untouched, so an outsider cannot buy into an exercise
    ///      by making itself able to pay for one.
    function test_fundedThirdParty_cannotBecomeThePayer() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _fundExerciser(unauthorizedExerciser, ACTOR_FUNDING);
        _approveExerciser(unauthorizedExerciser, type(uint256).max);

        SettlementState memory before = _settlementState(unauthorizedExerciser, commitmentId);

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__NotCommitmentExerciseAuthority.selector, commitmentId, unauthorizedExerciser
            )
        );
        _authorizeAs(unauthorizedExerciser, commitmentId, EXERCISE_Q);

        _assertNoExerciseResidue(before, unauthorizedExerciser, commitmentId);
    }

    /// @notice Proves a third party's approval does not redirect an authorized exercise's payment.
    /// @dev The complement: the outsider funds and approves, and then the real exercise authority exercises.
    ///      The debt still comes out of the authority's own account, because the payer is the authenticated
    ///      originating exerciser of this causal context and nobody else's willingness changes that.
    function test_thirdPartyApproval_doesNotFundAnAuthorizedExercise() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _fundExerciser(unauthorizedExerciser, ACTOR_FUNDING);
        _approveExerciser(unauthorizedExerciser, type(uint256).max);

        uint256 actualInput = _probeActualInput(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        uint256 outsiderBefore = ustb.balanceOf(unauthorizedExerciser);
        uint256 authorityBefore = ustb.balanceOf(commitmentExerciseAuthority);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        assertEq(ustb.balanceOf(unauthorizedExerciser), outsiderBefore, "a willing outsider must not be charged");
        assertEq(
            authorityBefore - ustb.balanceOf(commitmentExerciseAuthority),
            actualInput,
            "the authenticated exerciser must fund its own exercise"
        );
    }

    /*//////////////////////////////////////////////////////////////
                  G8C-11, G8C-13 — DELIVERY AUTHORITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the delivered output comes from the PoolManager and lands only on the Beneficiary.
    /// @dev Measured as a closed system: exactly `q` leaves the PoolManager, exactly `q` arrives at the
    ///      Beneficiary, and no other participant's protected-output balance moves at all. There is nowhere
    ///      the output could have been staged, and nothing left over to withdraw later.
    function test_protectedOutput_movesOnlyFromThePoolManagerToTheBeneficiary() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        SettlementState memory before = _settlementState(commitmentExerciseAuthority, commitmentId);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        SettlementState memory current = _settlementState(commitmentExerciseAuthority, commitmentId);

        assertEq(before.poolManagerOutput - current.poolManagerOutput, EXERCISE_Q, "the output leaves the PoolManager");
        assertEq(current.beneficiaryOutput - before.beneficiaryOutput, EXERCISE_Q, "the Beneficiary receives it");
        assertEq(current.routerOutput, before.routerOutput, "the router is not an intermediary");
        assertEq(current.hookOutput, before.hookOutput, "the Hook is not an intermediary");
        assertEq(current.exerciserOutput, before.exerciserOutput, "the exerciser is not the recipient");
    }

    /*//////////////////////////////////////////////////////////////
                    G8C-15 — ONE RESOLUTION SEQUENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a resolved exercise cannot be resolved again through a second unlock.
    /// @dev The router opens exactly one unlock per request, and a second request in the same transaction
    ///      is refused by the Hook before any unlock is attempted — so there is no second settlement, no
    ///      second delivery, and no way to re-enter the resolution sequence for a context that has already
    ///      been through it.
    function test_resolvedExercise_cannotBeResolvedAgain() public {
        uint256 commitmentId = _establishExercisable(CANONICAL_ENTITLEMENT);

        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        SettlementState memory resolved = _settlementState(commitmentExerciseAuthority, commitmentId);

        vm.expectRevert(StandbyHook.StandbyHook__ExerciseAuthorizationAlreadyActive.selector);
        _authorizeAs(commitmentExerciseAuthority, commitmentId, EXERCISE_Q);

        SettlementState memory current = _settlementState(commitmentExerciseAuthority, commitmentId);

        assertEq(current.exerciserInput, resolved.exerciserInput, "no second settlement may occur");
        assertEq(current.beneficiaryOutput, resolved.beneficiaryOutput, "no second delivery may occur");
        assertEq(current.poolManagerInput, resolved.poolManagerInput, "no second debt may be paid");
        assertEq(current.poolManagerOutput, resolved.poolManagerOutput, "no second credit may be discharged");
    }
}
