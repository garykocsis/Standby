// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";

import {UnfinalizedExerciseRouter} from "../harness/UnfinalizedExerciseRouter.sol";
import {BaseExerciseAuthorizationTest} from "./BaseExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared real-path fixture for F8C settlement and Beneficiary-delivery evidence.
/// @dev Built on the F8A/F8B fixture without altering it: the same real pinned `PoolManager`, the same
///      canonical `StandbyHook` deployment, the same F1 currencies, the same F2 registry under its own
///      administrator, the same production activation, the same canonical liquidity added through the
///      production `beforeAddLiquidity` path, and the same production `establishCommitment` transition for
///      every commitment. Nothing economic is seeded.
///
///      Two things differ from the F8B layer, and both are about being able to observe production R4 at
///      all.
///
///      The configured ExerciseRouter is `UnfinalizedExerciseRouter` rather than the F8B delta-closure
///      router. That is the production `ExerciseRouter` with its completion barrier lifted and nothing else
///      changed: the input-debt derivation, the `maxInput` comparison, the exerciser-funded settlement, and
///      the direct Beneficiary delivery are all production code running unmodified against the real
///      PoolManager. The barrier has to be lifted because production deliberately refuses to return from an
///      exercise whose causal proof has not been consumed, and nothing at this slice can consume it — so
///      every production exercise unwinds before its own settlement could be measured. Lifting it proves
///      nothing about whether a production O2 completes, and the suites below never claim it does; the
///      production barrier itself is verified separately, against the production router.
///
///      And the exerciser is funded and approves the router, because the exerciser is now the payer. The
///      funding is input currency only: an exerciser holding none of the protected output currency cannot
///      be the source of anything the Beneficiary receives.
///
///      What is deliberately *not* narrowed is the router's own pre-funding, inherited from the F8B layer.
///      A router holding a large balance of both currencies while every settlement still comes out of the
///      exerciser's account is what makes "the router could have paid and did not" a checkable claim rather
///      than an absence.
///
///      Roles stay separate throughout. The exerciser is not the Beneficiary, so a delivery that landed
///      with the payer would be visible; neither is the router, the Hook, the establishment authority, the
///      configuration authority, a trader, a liquidity provider, or the registry administrator.
abstract contract BaseExerciseSettlementTest is BaseExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Everything an exercise moves, and everything it must leave exactly as it found it.
    /// @dev Deliberately spans every account a settlement or a delivery could land in, both currencies, and
    ///      the authoritative economic facts F8C must not touch. Checking only the Beneficiary would miss
    ///      output that also passed through the router; checking only Remaining Entitlement would miss an
    ///      obligation released early.
    /// @param exerciserInput The authenticated exerciser's input-currency balance.
    /// @param exerciserOutput The authenticated exerciser's protected-output balance.
    /// @param beneficiaryOutput The authoritative Beneficiary's protected-output balance.
    /// @param routerInput The configured ExerciseRouter's input-currency balance.
    /// @param routerOutput The configured ExerciseRouter's protected-output balance.
    /// @param hookInput The Hook's input-currency balance.
    /// @param hookOutput The Hook's protected-output balance.
    /// @param poolManagerInput The PoolManager's input-currency balance.
    /// @param poolManagerOutput The PoolManager's protected-output balance.
    /// @param remainingEntitlement The exercised commitment's authoritative Remaining Entitlement.
    /// @param originalEntitlement The exercised commitment's admitted entitlement extent.
    /// @param aggregateObligation The re-derived Aggregate Capacity Obligation.
    /// @param sqrtPriceX96 The authoritative pool square-root price.
    /// @param tick The authoritative pool tick.
    /// @param liquidity The authoritative active liquidity.
    struct SettlementState {
        uint256 exerciserInput;
        uint256 exerciserOutput;
        uint256 beneficiaryOutput;
        uint256 routerInput;
        uint256 routerOutput;
        uint256 hookInput;
        uint256 hookOutput;
        uint256 poolManagerInput;
        uint256 poolManagerOutput;
        uint128 remainingEntitlement;
        uint128 originalEntitlement;
        uint256 aggregateObligation;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The configured router, typed so the production derivation pass-through is reachable.
    UnfinalizedExerciseRouter internal settlementExerciseRouter;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Makes the canonical exercise authority an exerciser that can actually pay.
    function setUp() public virtual override {
        super.setUp();

        _fundExerciser(commitmentExerciseAuthority, ACTOR_FUNDING);
        _approveExerciser(commitmentExerciseAuthority, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Activates the service with the production router whose completion barrier is lifted.
    function _resolveExerciseRouter() internal virtual override returns (address router) {
        settlementExerciseRouter = new UnfinalizedExerciseRouter(hook);

        configuredExerciseRouter = settlementExerciseRouter;

        router = address(configuredExerciseRouter);
    }

    /// @dev Gives an exerciser input currency, and only input currency.
    function _fundExerciser(address _exerciser, uint256 _amount) internal {
        ustb.mint(_exerciser, _amount);
    }

    /// @dev Lets the configured router coordinate an exerciser's payment, up to a chosen bound.
    function _approveExerciser(address _exerciser, uint256 _allowance) internal {
        vm.prank(_exerciser);
        ustb.approve(address(configuredExerciseRouter), _allowance);
    }

    /// @dev Discovers the authoritative input debt an exercise would produce, from production itself.
    ///
    ///      The only authority on what an exercise costs is the swap the PoolManager performs, so this asks
    ///      production what that swap cost — by requesting the exercise under a cost bound of zero, which no
    ///      real debt can satisfy, and reading the debt out of the refusal production reports. The refusal
    ///      unwinds the swap along with everything else, so the pool is exactly where it was and the same
    ///      request will produce the same debt again.
    ///
    ///      That is what makes the `maxInput` boundaries testable as boundaries. A bound derived from a
    ///      quote, an estimate, or an arithmetic reconstruction would be a bound on a different number than
    ///      the one production compares against, and equality against the wrong number proves nothing.
    function _probeActualInput(address _exerciser, uint256 _commitmentId, uint256 _q)
        internal
        returns (uint256 actualInput)
    {
        vm.prank(_exerciser);

        try configuredExerciseRouter.exercise(_commitmentId, _q, 0) {
            revert("a zero cost bound must refuse every real exercise");
        } catch (bytes memory reason) {
            actualInput = _decodeCostBreach(reason);
        }
    }

    /// @dev Reads the authoritative input debt out of production's own cost-bound refusal.
    function _decodeCostBreach(bytes memory _reason) internal pure returns (uint256 actualInput) {
        if (bytes4(_reason) != ExerciseRouter.ExerciseRouter__ExerciseCostExceedsMaxInput.selector) {
            revert("the exercise must have been refused by its cost bound");
        }

        bytes memory payload = new bytes(_reason.length - 4);

        for (uint256 i = 0; i < payload.length; ++i) {
            payload[i] = _reason[i + 4];
        }

        (actualInput,) = abi.decode(payload, (uint256, uint256));
    }

    /// @dev Captures every balance and authoritative fact an exercise could move.
    ///
    ///      The obligation is re-derived rather than remembered from an earlier call, so a comparison is
    ///      between two authoritative derivations rather than between a derivation and a cached number.
    function _settlementState(address _exerciser, uint256 _commitmentId)
        internal
        view
        returns (SettlementState memory state)
    {
        (uint160 sqrtPriceX96, int24 tick, uint128 liquidity) = _servicePoolState();

        StandbyHook.Commitment memory record = hook.commitment(_commitmentId);

        state = SettlementState({
            exerciserInput: ustb.balanceOf(_exerciser),
            exerciserOutput: usdc.balanceOf(_exerciser),
            beneficiaryOutput: usdc.balanceOf(record.beneficiary),
            routerInput: ustb.balanceOf(address(configuredExerciseRouter)),
            routerOutput: usdc.balanceOf(address(configuredExerciseRouter)),
            hookInput: ustb.balanceOf(address(hook)),
            hookOutput: usdc.balanceOf(address(hook)),
            poolManagerInput: ustb.balanceOf(address(poolManager)),
            poolManagerOutput: usdc.balanceOf(address(poolManager)),
            remainingEntitlement: record.remainingEntitlement,
            originalEntitlement: record.originalEntitlement,
            aggregateObligation: hook.aggregateObligation(),
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            liquidity: liquidity
        });
    }

    /// @dev Proves a successful exercise moved exactly what it must and nothing else.
    ///
    ///      Four independent statements, each of which a wrong settlement would break on its own: the
    ///      exerciser paid the exact debt, the PoolManager received exactly that debt, the Beneficiary
    ///      received exactly the authorized quantity, and it came out of the PoolManager rather than out of
    ///      anyone's custody. The router and the Hook are checked on both currencies, because a coordinator
    ///      that briefly held either would be a custodian.
    function _assertExactSettlementAndDelivery(
        SettlementState memory _before,
        address _exerciser,
        uint256 _commitmentId,
        uint256 _q,
        uint256 _actualInput
    ) internal view {
        SettlementState memory current = _settlementState(_exerciser, _commitmentId);

        assertEq(
            _before.exerciserInput - current.exerciserInput,
            _actualInput,
            "the authenticated exerciser must fund exactly the authoritative input debt"
        );
        assertEq(
            current.poolManagerInput - _before.poolManagerInput,
            _actualInput,
            "exactly that debt must reach the PoolManager"
        );
        assertEq(
            current.beneficiaryOutput - _before.beneficiaryOutput,
            _q,
            "the authoritative Beneficiary must receive exactly the authorized quantity"
        );
        assertEq(
            _before.poolManagerOutput - current.poolManagerOutput,
            _q,
            "exactly that quantity must leave the PoolManager"
        );

        assertEq(current.exerciserOutput, _before.exerciserOutput, "the exerciser must receive no protected output");
        assertEq(current.routerInput, _before.routerInput, "the router must not fund settlement");
        assertEq(current.routerOutput, _before.routerOutput, "the router must take no protected-output custody");
        assertEq(current.hookInput, _before.hookInput, "the Hook must not fund settlement");
        assertEq(current.hookOutput, _before.hookOutput, "the Hook must take no protected-output custody");
    }

    /// @dev Proves settlement and delivery changed no Standby economic fact.
    ///
    ///      Everything finalization owns and F8C must leave untouched: the entitlement, its remainder, and
    ///      the aggregate obligation. A settled and delivered exercise is still an unfulfilled one.
    function _assertNoFulfillmentConsequence(
        SettlementState memory _before,
        address _exerciser,
        uint256 _commitmentId,
        string memory _context
    ) internal view {
        SettlementState memory current = _settlementState(_exerciser, _commitmentId);

        assertEq(uint256(current.remainingEntitlement), uint256(_before.remainingEntitlement), _context);
        assertEq(uint256(current.originalEntitlement), uint256(_before.originalEntitlement), _context);
        assertEq(current.aggregateObligation, _before.aggregateObligation, _context);
    }

    /// @dev Proves a rejected exercise left no residue of any kind, on any surface.
    function _assertNoExerciseResidue(SettlementState memory _before, address _exerciser, uint256 _commitmentId)
        internal
        view
    {
        SettlementState memory current = _settlementState(_exerciser, _commitmentId);

        assertEq(current.exerciserInput, _before.exerciserInput, "a rejected exercise must not take payment");
        assertEq(current.exerciserOutput, _before.exerciserOutput, "a rejected exercise must not pay the exerciser");
        assertEq(current.beneficiaryOutput, _before.beneficiaryOutput, "a rejected exercise must deliver nothing");
        assertEq(current.routerInput, _before.routerInput, "a rejected exercise must not move router currency0");
        assertEq(current.routerOutput, _before.routerOutput, "a rejected exercise must not move router currency1");
        assertEq(current.hookInput, _before.hookInput, "a rejected exercise must not move Hook currency0");
        assertEq(current.hookOutput, _before.hookOutput, "a rejected exercise must not move Hook currency1");
        assertEq(current.poolManagerInput, _before.poolManagerInput, "a rejected exercise must not settle input");
        assertEq(current.poolManagerOutput, _before.poolManagerOutput, "a rejected exercise must not release output");
        assertEq(
            uint256(current.remainingEntitlement),
            uint256(_before.remainingEntitlement),
            "a rejected exercise must fulfil nothing"
        );
        assertEq(
            uint256(current.originalEntitlement),
            uint256(_before.originalEntitlement),
            "a rejected exercise must change no admitted term"
        );
        assertEq(
            current.aggregateObligation, _before.aggregateObligation, "a rejected exercise must release no obligation"
        );
        assertEq(current.sqrtPriceX96, _before.sqrtPriceX96, "a rejected exercise must leave the pool price untouched");
        assertEq(current.tick, _before.tick, "a rejected exercise must leave the pool tick untouched");
        assertEq(current.liquidity, _before.liquidity, "a rejected exercise must leave active liquidity untouched");

        _assertNoAuthorizationContext("a rejected exercise must leave no reusable causal context");
    }
}
