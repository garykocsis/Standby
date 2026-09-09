// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseCanonicalAcceptanceTest} from "../shared/BaseCanonicalAcceptanceTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Canonical acceptance evidence for the frozen Standby economic history (G9).
/// @dev One question, answered end to end: starting from an empty chain, can the completed production
///      realization be constructed and then reproduce the exact frozen Bootstrap → A1 → A2 → A3 rejection
///      → A4 sequence?
///
///      The sequence is one uninterrupted history over one live pool. The commitment A4 exercises is the
///      one A1 created, identified by the identity the production admission transition actually returned;
///      A2 acts on the state A1 left; A3 attacks the state A2 left; and A4 starts from the state A3 failed
///      to change. No stage reconstructs its own starting point, and no stage is proven against a fixture
///      that was prepared to be there already.
///
///      Every authoritative action is a production one — `establishCommitment` for admission, the trusted
///      ordinary-swap perimeter and the real `PoolManager` for both ordinary swaps, and the production
///      `ExerciseRouter` for the exercise — and every observation is read back from the PoolManager, the
///      Hook, or token balances. The frozen quantities (80,000 / 50,000 / 65,000 / 45,000 prospective /
///      15,000) are assertions against that authoritative state; both economic derivations are
///      additionally checked against independent reconstructions, and the prospective quantity A3 turns
///      on is the production derivation the enforcement path itself uses, never a test-owned substitute.
///
///      This suite inherits no fixture that pre-creates backed economic state, writes no storage, uses no
///      harness, and calls no test-only setter.
contract CanonicalStandbyFlowTest is BaseCanonicalAcceptanceTest {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The observed economic history of one complete canonical run.
    /// @dev Recorded so that a second, independently constructed system can be shown to reproduce the same
    ///      history exactly rather than merely to satisfy the same assertions.
    /// @param commitmentId The identity the production admission transition returned.
    /// @param bootstrapCapacity Supporting Capacity before the first canonical action.
    /// @param a1Capacity Supporting Capacity after admission.
    /// @param a1Obligation Aggregate Capacity Obligation after admission.
    /// @param a1Remaining Remaining Entitlement after admission.
    /// @param a2ProspectiveCapacity The prospective capacity the compatible swap was predicted to leave.
    /// @param a2Capacity Supporting Capacity after the compatible ordinary swap.
    /// @param a2Obligation Aggregate Capacity Obligation after the compatible ordinary swap.
    /// @param a2Remaining Remaining Entitlement after the compatible ordinary swap.
    /// @param a2TraderOutput The protected output the ordinary trader actually received.
    /// @param a3ProspectiveCapacity The prospective capacity the destructive attempt was predicted to leave.
    /// @param a3Capacity Supporting Capacity after the destructive attempt was rejected.
    /// @param a3Obligation Aggregate Capacity Obligation after the rejection.
    /// @param a3Remaining Remaining Entitlement after the rejection.
    /// @param a4Capacity Supporting Capacity after the full exercise.
    /// @param a4Obligation Aggregate Capacity Obligation after the full exercise.
    /// @param a4Remaining Remaining Entitlement after the full exercise.
    /// @param a4BeneficiaryDelivery The protected output the authoritative Beneficiary actually received.
    /// @param a4ExerciserInputPaid The input the authenticated exerciser actually paid.
    struct CanonicalHistory {
        uint256 commitmentId;
        uint256 bootstrapCapacity;
        uint256 a1Capacity;
        uint256 a1Obligation;
        uint128 a1Remaining;
        uint256 a2ProspectiveCapacity;
        uint256 a2Capacity;
        uint256 a2Obligation;
        uint128 a2Remaining;
        uint256 a2TraderOutput;
        uint256 a3ProspectiveCapacity;
        uint256 a3Capacity;
        uint256 a3Obligation;
        uint128 a3Remaining;
        uint256 a4Capacity;
        uint256 a4Obligation;
        uint128 a4Remaining;
        uint256 a4BeneficiaryDelivery;
        uint256 a4ExerciserInputPaid;
    }

    /// @notice Everything a rejected transition must leave exactly as it found it.
    /// @param supportingCapacity The authoritatively derived Supporting Capacity.
    /// @param aggregateObligation The authoritatively derived Aggregate Capacity Obligation.
    /// @param remainingEntitlement The exercised commitment's Remaining Entitlement.
    /// @param nextCommitmentId The identity the next admission would receive.
    /// @param occupiedReferences The number of occupied bounded enforcement-reference slots.
    /// @param sqrtPriceX96 The authoritative pool square-root price.
    /// @param tick The authoritative pool tick.
    /// @param liquidity The authoritative active liquidity.
    /// @param traderInput The ordinary trader's input-currency balance.
    /// @param traderOutput The ordinary trader's protected-output balance.
    /// @param beneficiaryOutput The authoritative Beneficiary's protected-output balance.
    struct RejectionState {
        uint256 supportingCapacity;
        uint256 aggregateObligation;
        uint128 remainingEntitlement;
        uint256 nextCommitmentId;
        uint256 occupiedReferences;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        uint256 traderInput;
        uint256 traderOutput;
        uint256 beneficiaryOutput;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The frozen terminal Supporting Capacity of the canonical sequence: 15,000.000000 MockUSDC.
    ///      An expected verification value from the canonical demonstration, never production truth.
    uint256 internal constant EXPECTED_A4_S = 15_000_000_000;

    /// @dev The exerciser's own cost bound for the canonical exercise: 100,000.000000 MockUSTB.
    ///
    ///      Generous rather than unconstrained. The canonical exercise costs a little over 50,000 MockUSTB,
    ///      so no canonical outcome turns on this number — but it is a real bound that production compares
    ///      the authoritative input debt against, rather than a value chosen to disable the comparison.
    uint256 internal constant CANONICAL_EXERCISE_MAX_INPUT = 100_000_000_000;

    /*//////////////////////////////////////////////////////////////
                    G9 — ONE UNINTERRUPTED CANONICAL HISTORY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a freshly constructed Standby realization reproduces the frozen canonical history.
    /// @dev The primary F9 acceptance claim, in one sequential transaction history over one live pool:
    ///
    ///      | stage     |                  S |      O | Remaining | result    |
    ///      | --------- | -----------------: | -----: | --------: | --------- |
    ///      | bootstrap |             80,000 |      0 |         — | ready     |
    ///      | A1        |             80,000 | 50,000 |    50,000 | pass      |
    ///      | A2        |             65,000 | 50,000 |    50,000 | pass      |
    ///      | A3        | prospective 45,000 | 50,000 |    50,000 | reject    |
    ///      | after A3  |             65,000 | 50,000 |    50,000 | unchanged |
    ///      | A4        |             15,000 |      0 |         0 | pass      |
    function test_CanonicalStandbyFlow() public {
        _runCanonicalHistory(canonical);
    }

    /*//////////////////////////////////////////////////////////////
                      G9 — DETERMINISTIC REPRODUCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a second, independently constructed system reproduces the identical history.
    /// @dev Determinism is part of the acceptance claim, so it is proven rather than assumed. The second
    ///      system shares nothing with the first: its own PoolManager, its own currencies, its own Hook at
    ///      its own mined address, its own registry, perimeters and coordinator, and its own seven
    ///      accounts. Every economic quantity the canonical history produces comes out the same, down to
    ///      the input the exerciser actually paid — which is the quantity a non-deterministic construction
    ///      would move first.
    function test_canonicalStandbyFlow_reproducesIdenticallyFromASecondFreshConstruction() public {
        CanonicalHistory memory first = _runCanonicalHistory(canonical);

        CanonicalSystem memory replica = _constructCanonicalSystem("replica");

        assertTrue(
            address(replica.environment.hook) != address(canonical.environment.hook),
            "the second construction must be an independent system"
        );
        assertTrue(
            address(replica.environment.poolManager) != address(canonical.environment.poolManager),
            "the second construction must have its own PoolManager"
        );

        CanonicalHistory memory second = _runCanonicalHistory(replica);

        assertEq(second.commitmentId, first.commitmentId, "the admitted identity must reproduce");
        assertEq(second.bootstrapCapacity, first.bootstrapCapacity, "bootstrap capacity must reproduce");
        assertEq(second.a1Capacity, first.a1Capacity, "A1 capacity must reproduce");
        assertEq(second.a1Obligation, first.a1Obligation, "A1 obligation must reproduce");
        assertEq(uint256(second.a1Remaining), uint256(first.a1Remaining), "A1 remainder must reproduce");
        assertEq(second.a2ProspectiveCapacity, first.a2ProspectiveCapacity, "A2 prediction must reproduce");
        assertEq(second.a2Capacity, first.a2Capacity, "A2 capacity must reproduce");
        assertEq(second.a2Obligation, first.a2Obligation, "A2 obligation must reproduce");
        assertEq(uint256(second.a2Remaining), uint256(first.a2Remaining), "A2 remainder must reproduce");
        assertEq(second.a2TraderOutput, first.a2TraderOutput, "A2 delivered output must reproduce");
        assertEq(second.a3ProspectiveCapacity, first.a3ProspectiveCapacity, "A3 prediction must reproduce");
        assertEq(second.a3Capacity, first.a3Capacity, "post-rejection capacity must reproduce");
        assertEq(second.a3Obligation, first.a3Obligation, "post-rejection obligation must reproduce");
        assertEq(uint256(second.a3Remaining), uint256(first.a3Remaining), "post-rejection remainder must reproduce");
        assertEq(second.a4Capacity, first.a4Capacity, "terminal capacity must reproduce");
        assertEq(second.a4Obligation, first.a4Obligation, "terminal obligation must reproduce");
        assertEq(uint256(second.a4Remaining), uint256(first.a4Remaining), "terminal remainder must reproduce");
        assertEq(second.a4BeneficiaryDelivery, first.a4BeneficiaryDelivery, "Beneficiary delivery must reproduce");
        assertEq(second.a4ExerciserInputPaid, first.a4ExerciserInputPaid, "the exercise cost must reproduce");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs the complete canonical history against one constructed system, asserting every stage.
    function _runCanonicalHistory(CanonicalSystem memory _system) internal returns (CanonicalHistory memory history) {
        _observeBootstrap(_system, history);

        _runA1Admit(_system, history);
        _runA2CompatibleOrdinarySwap(_system, history);
        _runA3DestructiveAttempt(_system, history);
        _runA4FullExercise(_system, history);
    }

    /// @dev Bootstrap — the canonical starting state the live history begins from.
    function _observeBootstrap(CanonicalSystem memory _system, CanonicalHistory memory _history) internal view {
        StandbyHook hook = _system.environment.hook;

        _history.bootstrapCapacity = hook.supportingCapacity();

        assertEq(
            _history.bootstrapCapacity,
            StandbyFixtureConfig.EXPECTED_INITIAL_S,
            "bootstrap must stand at S = 80,000 MockUSDC"
        );
        assertEq(hook.aggregateObligation(), 0, "bootstrap must stand at O = 0");
        assertEq(hook.nextCommitmentId(), 1, "bootstrap must hold no commitment");

        _assertDerivationsMatchOracles(_system, "bootstrap derivations must equal their reconstructions");
        _assertNoStandbyCustody(_system, "bootstrap must leave no protected output in Standby custody");
    }

    /// @dev A1 — admit the canonical 50,000 MockUSDC commitment through the production O1 transition.
    ///
    ///      The identity is the one production returned; nothing here synthesizes or pre-creates it, and
    ///      it is the identity A4 exercises. Admission establishes an obligation without consuming any
    ///      capacity, without moving the pool, and without paying the Beneficiary anything: that is the
    ///      whole point of the stage, so all three are asserted rather than assumed.
    function _runA1Admit(CanonicalSystem memory _system, CanonicalHistory memory _history) internal {
        StandbyHook hook = _system.environment.hook;

        (uint160 sqrtPriceBefore, int24 tickBefore, uint128 liquidityBefore) = _poolState(_system);
        uint256 beneficiaryBefore = _system.environment.usdc.balanceOf(_system.actors.beneficiary);

        vm.prank(_system.actors.establishmentAuthority);
        _history.commitmentId = hook.establishCommitment(
            _system.actors.beneficiary,
            _system.actors.exerciseAuthority,
            uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q),
            uint64(block.timestamp),
            uint64(block.timestamp) + CANONICAL_VALIDITY_DURATION
        );

        assertGt(_history.commitmentId, 0, "A1 must return an authentic commitment identity");

        StandbyHook.Commitment memory record = hook.commitment(_history.commitmentId);

        assertEq(
            PoolId.unwrap(record.serviceId),
            PoolId.unwrap(_system.serviceId),
            "the admitted commitment must belong to the bootstrapped service"
        );
        assertEq(record.beneficiary, _system.actors.beneficiary, "the admitted Beneficiary must be the canonical one");
        assertEq(
            record.exerciseAuthority,
            _system.actors.exerciseAuthority,
            "the admitted exercise authority must be the canonical one"
        );
        assertEq(
            uint256(record.originalEntitlement),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "A1 must admit Original Entitlement = 50,000 MockUSDC"
        );

        _history.a1Remaining = record.remainingEntitlement;
        _history.a1Capacity = hook.supportingCapacity();
        _history.a1Obligation = hook.aggregateObligation();

        assertEq(
            uint256(_history.a1Remaining),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "A1 must leave Remaining Entitlement = 50,000 MockUSDC"
        );
        assertEq(_history.a1Capacity, StandbyFixtureConfig.EXPECTED_INITIAL_S, "A1 must leave S = 80,000 MockUSDC");
        assertEq(
            _history.a1Obligation, StandbyFixtureConfig.CANONICAL_COMMITMENT_Q, "A1 must leave O = 50,000 MockUSDC"
        );

        (uint160 sqrtPriceAfter, int24 tickAfter, uint128 liquidityAfter) = _poolState(_system);

        assertEq(sqrtPriceAfter, sqrtPriceBefore, "O1 must not move the pool price");
        assertEq(tickAfter, tickBefore, "O1 must not move the pool tick");
        assertEq(liquidityAfter, liquidityBefore, "O1 must not change active liquidity");

        assertEq(
            _system.environment.usdc.balanceOf(_system.actors.beneficiary),
            beneficiaryBefore,
            "O1 must deliver nothing to the Beneficiary"
        );

        assertEq(_occupiedReferenceCount(_system), 1, "A1 must occupy exactly one enforcement reference");

        _assertDerivationsMatchOracles(_system, "A1 derivations must equal their reconstructions");
        _assertNoStandbyCustody(_system, "A1 must segregate no protected output into Standby custody");
    }

    /// @dev A2 — the compatible ordinary protected exact-output swap of 15,000 MockUSDC.
    ///
    ///      The decisive non-reservation stage. An ordinary trader with no relationship to the commitment
    ///      asks the shared pool for protected output while the full 50,000 obligation is outstanding, and
    ///      is served — so the obligation bounded how far the shared resource could be drawn down without
    ///      reserving any of it.
    function _runA2CompatibleOrdinarySwap(CanonicalSystem memory _system, CanonicalHistory memory _history) internal {
        StandbyHook hook = _system.environment.hook;

        SwapParams memory params = _protectedExactOutputSwapParams(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT);

        _history.a2ProspectiveCapacity = hook.prospectiveSupportingCapacityAfterSwap(params);

        assertEq(
            _history.a2ProspectiveCapacity,
            StandbyFixtureConfig.EXPECTED_A2_S,
            "A2 must be predicted to leave S' = 65,000 MockUSDC"
        );
        assertGe(
            _history.a2ProspectiveCapacity,
            hook.aggregateObligation(),
            "A2 must be a compatible transition: 65,000 >= 50,000"
        );

        uint256 traderOutputBefore = _system.environment.usdc.balanceOf(_system.actors.trader);
        uint256 traderInputBefore = _system.environment.ustb.balanceOf(_system.actors.trader);

        vm.prank(_system.actors.trader);
        _system.environment.swapPerimeter.swap(_system.poolKey, params, bytes(""));

        _history.a2TraderOutput = _system.environment.usdc.balanceOf(_system.actors.trader) - traderOutputBefore;

        assertEq(
            _history.a2TraderOutput,
            StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT,
            "the ordinary trader must receive exactly the requested 15,000 MockUSDC"
        );
        assertLt(
            _system.environment.ustb.balanceOf(_system.actors.trader),
            traderInputBefore,
            "the ordinary trader must have paid for it"
        );

        StandbyHook.Commitment memory record = hook.commitment(_history.commitmentId);

        _history.a2Remaining = record.remainingEntitlement;
        _history.a2Capacity = hook.supportingCapacity();
        _history.a2Obligation = hook.aggregateObligation();

        assertEq(_history.a2Capacity, StandbyFixtureConfig.EXPECTED_A2_S, "A2 must leave S = 65,000 MockUSDC");
        assertEq(
            _history.a2Obligation,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "an ordinary swap fulfils nothing, so O must remain 50,000 MockUSDC"
        );
        assertEq(
            uint256(_history.a2Remaining),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "an ordinary swap must not reduce Remaining Entitlement"
        );
        assertEq(
            uint256(record.originalEntitlement),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "an ordinary swap must not rewrite the admitted extent"
        );

        _assertDerivationsMatchOracles(_system, "A2 derivations must equal their reconstructions");
        _assertNoStandbyCustody(_system, "A2 must leave no protected output in Standby custody");
    }

    /// @dev A3 — the destructive ordinary protected exact-output attempt of 20,000 MockUSDC.
    ///
    ///      The request is otherwise entirely valid: the same eligible trader, the same trusted perimeter,
    ///      funded, approved, inside the service domain, with no slippage constraint. It is refused for
    ///      exactly one reason, and the expectation names that reason and both quantities the Hook
    ///      compared — so a refusal caused by eligibility, allowance, balance, topology, the domain, or an
    ///      unrelated v4 failure could not be mistaken for this one.
    ///
    ///      The prospective 45,000 is the production derivation the enforcement path itself uses, and it
    ///      is then proven never to have become authoritative.
    function _runA3DestructiveAttempt(CanonicalSystem memory _system, CanonicalHistory memory _history) internal {
        StandbyHook hook = _system.environment.hook;

        SwapParams memory params = _protectedExactOutputSwapParams(StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT);

        _history.a3ProspectiveCapacity = hook.prospectiveSupportingCapacityAfterSwap(params);

        assertEq(
            _history.a3ProspectiveCapacity,
            StandbyFixtureConfig.EXPECTED_A3_PROSPECTIVE_S,
            "A3 must be predicted to leave S' = 45,000 MockUSDC"
        );
        assertLt(
            _history.a3ProspectiveCapacity,
            hook.aggregateObligation(),
            "A3 must be a destructive transition: 45,000 < 50,000"
        );

        RejectionState memory before = _rejectionState(_system, _history.commitmentId);

        _expectHookRejection(
            _system,
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientProspectiveBacking.selector,
                StandbyFixtureConfig.EXPECTED_A3_PROSPECTIVE_S,
                StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
            )
        );

        vm.prank(_system.actors.trader);
        _system.environment.swapPerimeter.swap(_system.poolKey, params, bytes(""));

        _assertRejectionWasAtomic(_system, _history.commitmentId, before);

        _history.a3Capacity = hook.supportingCapacity();
        _history.a3Obligation = hook.aggregateObligation();
        _history.a3Remaining = hook.commitment(_history.commitmentId).remainingEntitlement;

        assertEq(_history.a3Capacity, StandbyFixtureConfig.EXPECTED_A2_S, "after A3 the service must stand at 65,000");
        assertEq(
            _history.a3Obligation,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "after A3 the obligation must still be 50,000"
        );
        assertEq(
            uint256(_history.a3Remaining),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "after A3 the remainder must still be 50,000"
        );

        _assertDerivationsMatchOracles(_system, "post-rejection derivations must equal their reconstructions");
    }

    /// @dev A4 — the full 50,000 MockUSDC exercise of the commitment A1 created.
    ///
    ///      Through the production `ExerciseRouter`, in one atomic transition that traverses the whole O2
    ///      realization: Hook-owned authorization, the exact-output protected execution, settlement of the
    ///      authoritative input debt out of the authenticated exerciser's own account, direct delivery by
    ///      the PoolManager to the authoritative Beneficiary, and causal finalization.
    ///
    ///      Nothing is mocked and nothing is closed mechanically. The delivery is measured as an increase
    ///      in the Beneficiary's balance and as a decrease in the PoolManager's, so the output provably
    ///      came out of the pool rather than out of anyone's custody, and the remainder reaches zero in
    ///      the same transition that delivered it.
    function _runA4FullExercise(CanonicalSystem memory _system, CanonicalHistory memory _history) internal {
        StandbyHook hook = _system.environment.hook;

        address poolManager = address(_system.environment.poolManager);

        uint256 beneficiaryBefore = _system.environment.usdc.balanceOf(_system.actors.beneficiary);
        uint256 exerciserInputBefore = _system.environment.ustb.balanceOf(_system.actors.exerciseAuthority);
        uint256 poolManagerInputBefore = _system.environment.ustb.balanceOf(poolManager);
        uint256 poolManagerOutputBefore = _system.environment.usdc.balanceOf(poolManager);

        vm.prank(_system.actors.exerciseAuthority);
        _system.environment.exerciseRouter.exercise(
            _history.commitmentId, StandbyFixtureConfig.CANONICAL_COMMITMENT_Q, CANONICAL_EXERCISE_MAX_INPUT
        );

        _history.a4ExerciserInputPaid =
            exerciserInputBefore - _system.environment.ustb.balanceOf(_system.actors.exerciseAuthority);

        assertGt(_history.a4ExerciserInputPaid, 0, "the exercise must have cost the exerciser real input");
        assertLe(
            _history.a4ExerciserInputPaid,
            CANONICAL_EXERCISE_MAX_INPUT,
            "the authoritative input debt must respect the exerciser's own cost bound"
        );
        assertEq(
            _system.environment.ustb.balanceOf(poolManager) - poolManagerInputBefore,
            _history.a4ExerciserInputPaid,
            "exactly that debt must have been settled to the PoolManager"
        );

        _history.a4BeneficiaryDelivery =
            _system.environment.usdc.balanceOf(_system.actors.beneficiary) - beneficiaryBefore;

        assertEq(
            _history.a4BeneficiaryDelivery,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "the Beneficiary must receive exactly 50,000 MockUSDC"
        );
        assertEq(
            poolManagerOutputBefore - _system.environment.usdc.balanceOf(poolManager),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "exactly that quantity must have left the PoolManager"
        );
        assertEq(
            _system.environment.usdc.balanceOf(_system.actors.exerciseAuthority),
            0,
            "the exerciser must receive no protected output"
        );

        StandbyHook.Commitment memory record = hook.commitment(_history.commitmentId);

        _history.a4Remaining = record.remainingEntitlement;
        _history.a4Capacity = hook.supportingCapacity();
        _history.a4Obligation = hook.aggregateObligation();

        assertEq(uint256(_history.a4Remaining), 0, "A4 must terminate at Remaining Entitlement = 0");
        assertEq(_history.a4Obligation, 0, "A4 must terminate at O = 0");
        assertEq(_history.a4Capacity, EXPECTED_A4_S, "A4 must terminate at S = 15,000 MockUSDC");
        assertEq(
            uint256(record.originalEntitlement),
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            "fulfillment must not rewrite the admitted extent"
        );

        assertEq(_occupiedReferenceCount(_system), 1, "a fulfilled commitment keeps its enforcement reference");

        assertEq(
            uint256(hook.exerciseAuthorization().state),
            uint256(StandbyHook.ExerciseAuthorizationState.EMPTY),
            "a completed exercise must leave no reusable causal context"
        );

        _assertDerivationsMatchOracles(_system, "terminal derivations must equal their reconstructions");
        _assertNoStandbyCustody(_system, "A4 must leave no protected output in Standby custody");
    }

    /// @dev Captures everything a rejected transition must leave exactly as it found it.
    function _rejectionState(CanonicalSystem memory _system, uint256 _commitmentId)
        internal
        view
        returns (RejectionState memory state)
    {
        (uint160 sqrtPriceX96, int24 tick, uint128 liquidity) = _poolState(_system);

        StandbyHook hook = _system.environment.hook;

        state = RejectionState({
            supportingCapacity: hook.supportingCapacity(),
            aggregateObligation: hook.aggregateObligation(),
            remainingEntitlement: hook.commitment(_commitmentId).remainingEntitlement,
            nextCommitmentId: hook.nextCommitmentId(),
            occupiedReferences: _occupiedReferenceCount(_system),
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            liquidity: liquidity,
            traderInput: _system.environment.ustb.balanceOf(_system.actors.trader),
            traderOutput: _system.environment.usdc.balanceOf(_system.actors.trader),
            beneficiaryOutput: _system.environment.usdc.balanceOf(_system.actors.beneficiary)
        });
    }

    /// @dev Proves the rejected transition left no authoritative residue on any surface.
    ///
    ///      Pool state surviving the revert is necessary but not sufficient: a transition that had already
    ///      moved value between the trader and the pool would show up in the balances and nowhere else.
    function _assertRejectionWasAtomic(
        CanonicalSystem memory _system,
        uint256 _commitmentId,
        RejectionState memory _before
    ) internal view {
        RejectionState memory current = _rejectionState(_system, _commitmentId);

        assertEq(current.supportingCapacity, _before.supportingCapacity, "a rejected A3 must not change capacity");
        assertEq(current.aggregateObligation, _before.aggregateObligation, "a rejected A3 must not change obligation");
        assertEq(
            uint256(current.remainingEntitlement),
            uint256(_before.remainingEntitlement),
            "a rejected A3 must not change the remainder"
        );
        assertEq(current.nextCommitmentId, _before.nextCommitmentId, "a rejected A3 must consume no identity");
        assertEq(current.occupiedReferences, _before.occupiedReferences, "a rejected A3 must not touch the index");
        assertEq(current.sqrtPriceX96, _before.sqrtPriceX96, "a rejected A3 must not move the price");
        assertEq(current.tick, _before.tick, "a rejected A3 must not move the tick");
        assertEq(current.liquidity, _before.liquidity, "a rejected A3 must not change active liquidity");
        assertEq(current.traderInput, _before.traderInput, "a rejected A3 must not take the trader's input");
        assertEq(current.traderOutput, _before.traderOutput, "a rejected A3 must not pay the trader");
        assertEq(current.beneficiaryOutput, _before.beneficiaryOutput, "a rejected A3 must deliver nothing");
    }

    /// @dev Proves neither the Hook nor the coordinator holds protected output.
    function _assertNoStandbyCustody(CanonicalSystem memory _system, string memory _context) internal view {
        assertEq(_system.environment.usdc.balanceOf(address(_system.environment.hook)), 0, _context);
        assertEq(_system.environment.usdc.balanceOf(address(_system.environment.exerciseRouter)), 0, _context);
    }
}
