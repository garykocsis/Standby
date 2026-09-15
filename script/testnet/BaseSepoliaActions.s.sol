// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {console2} from "forge-std/console2.sol";

import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {DemoActions} from "../DemoActions.s.sol";
import {NetworkConfig, PublicPeripheryConfig} from "../helpers/NetworkConfig.sol";
import {DeployedUniversalRouterCalldata, IDeployedUniversalRouter} from "../helpers/PublicPeriphery.sol";
import {StandbyActors, StandbyEnvironment} from "../helpers/StandbyEnvironment.sol";
import {StandbyFixtureConfig} from "../helpers/StandbyFixtureConfig.sol";

import {BaseSepoliaScript} from "./BaseSepoliaScript.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title BaseSepoliaActions
/// @notice Supplementary post-submission (F9T) reproduction of the canonical A1 → A2 → A3 → A4 lifecycle on
///         Base Sepolia, through the official Universal Router for ordinary swaps.
/// @dev The canonical actions, reused rather than restated. A1 is the inherited `establishCommitment` action and
///      A4 is the inherited `ExerciseRouter` action, both unchanged. The A3 refusal is checked by the inherited
///      exact-revert-data comparison.
///
///      Only the ordinary-swap perimeter differs. A2 and A3 are sent to the official Universal Router as an
///      exact-output single-pool v4 swap in the service's protected direction, settled and taken by the router's
///      authenticated `msgSender()` — the trader. The official router exposes no price limit for exact-output
///      swaps and hands the PoolManager `MIN_SQRT_PRICE + 1` (or `MAX_SQRT_PRICE - 1`), so the prospective
///      state the Hook derives is derived for exactly that proposal. For the canonical quantities the swap
///      completes inside the service domain long before either limit, so the derived state is the canonical one.
///
///      Each stage is its own entrypoint, so each is its own broadcast and its own transaction evidence, and each
///      checks the canonical authoritative state the stage must produce. Those checks run against the script's
///      own execution before transactions are sent; `verifyBaseSepoliaState` re-reads the mined chain afterwards.
///
///      A3 must not succeed, so like the canonical A3 it is a simulated attempt against live state rather than a
///      broadcast transaction. The inherited `run()` is the local-environment entrypoint and does not apply here.
contract BaseSepoliaActions is DemoActions, BaseSepoliaScript {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The trader's own input bound for the canonical ordinary swaps: 100,000.000000 MockUSTB.
    /// @dev Required by the official router's exact-output interface. Generous rather than unconstrained, and no
    ///      canonical outcome turns on it: neither canonical ordinary swap costs more than about 21,000 MockUSTB.
    uint256 public constant ORDINARY_SWAP_MAX_INPUT = 100_000_000_000;

    /// @notice The canonical final Supporting Capacity after A4: 15,000.000000 MockUSDC.
    /// @dev Expected verification value only, identical to the canonical acceptance expectation.
    uint256 public constant EXPECTED_A4_S = 15_000_000_000;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the authoritative Supporting Capacity is not the canonical stage value.
    /// @param expected The canonical stage value.
    /// @param actual The Supporting Capacity the Hook derives.
    error BaseSepoliaActions__SupportingCapacityMismatch(uint256 expected, uint256 actual);

    /// @notice Thrown when the authoritative Aggregate Capacity Obligation is not the canonical stage value.
    /// @param expected The canonical stage value.
    /// @param actual The Aggregate Capacity Obligation the Hook derives.
    error BaseSepoliaActions__CapacityObligationMismatch(uint256 expected, uint256 actual);

    /// @notice Thrown when the commitment's Remaining Entitlement is not the canonical stage value.
    /// @param expected The canonical stage value.
    /// @param actual The Remaining Entitlement the Hook records.
    error BaseSepoliaActions__RemainingEntitlementMismatch(uint256 expected, uint256 actual);

    /// @notice Thrown when the prospective capacity of a proposed ordinary swap is not the canonical value.
    /// @param expected The canonical prospective value.
    /// @param actual The prospective Supporting Capacity the Hook derives for the proposal.
    error BaseSepoliaActions__ProspectiveCapacityMismatch(uint256 expected, uint256 actual);

    /// @notice Thrown when the Beneficiary did not receive exactly the exercised quantity.
    /// @param expected The exercised quantity.
    /// @param actual The Beneficiary's protected-output balance increase.
    error BaseSepoliaActions__BeneficiaryDeliveryMismatch(uint256 expected, uint256 actual);

    /// @notice Thrown when a Standby contract holds protected output after the exercise.
    /// @param holder The Standby contract.
    /// @param balance The protected-output balance it holds.
    error BaseSepoliaActions__ProtectedOutputCustody(address holder, uint256 balance);

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice A1 — admits the canonical 50,000 MockUSDC commitment through the production O1 transition.
    /// @return commitmentId The identity the production admission transition returned.
    function admitCommitmentBaseSepolia() external returns (uint256 commitmentId) {
        (StandbyEnvironment memory environment, StandbyActors memory actors) = _loadBaseSepolia();

        commitmentId = _a1AdmitCommitment(environment, actors);

        _requireStageState(
            environment,
            commitmentId,
            StandbyFixtureConfig.EXPECTED_INITIAL_S,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
    }

    /// @notice A2 — the compatible 15,000 MockUSDC ordinary swap through the official Universal Router.
    /// @param _commitmentId The identity A1 established.
    function compatibleOrdinarySwapBaseSepolia(uint256 _commitmentId) external {
        (StandbyEnvironment memory environment, StandbyActors memory actors) = _loadBaseSepolia();
        PublicPeripheryConfig memory periphery = _peripheryOnly();

        StandbyHook hook = environment.hook;

        (PoolKey memory poolKey, SwapParams memory proposal) =
            _officialRouterProposal(hook, StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT);

        console2.log("A2 requested protected output:", StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT);
        console2.log("A2 prospective S':", hook.prospectiveSupportingCapacityAfterSwap(proposal));

        (bytes memory commands, bytes[] memory inputs) = DeployedUniversalRouterCalldata.exactOutputSingle(
            poolKey,
            proposal.zeroForOne,
            uint128(StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT),
            uint128(ORDINARY_SWAP_MAX_INPUT)
        );

        uint256 deadline = block.timestamp + PERIPHERY_DEADLINE_WINDOW;
        uint256 traderOutputBefore = environment.usdc.balanceOf(actors.trader);

        vm.startBroadcast(actors.trader);

        IDeployedUniversalRouter(periphery.universalRouter).execute(commands, inputs, deadline);

        vm.stopBroadcast();

        console2.log("A2 trader received:", environment.usdc.balanceOf(actors.trader) - traderOutputBefore);

        _reportState(environment, "A2");

        _requireStageState(
            environment,
            _commitmentId,
            StandbyFixtureConfig.EXPECTED_A2_S,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
    }

    /// @notice A3 — attempts the destructive 20,000 MockUSDC ordinary swap through the official Universal Router.
    /// @dev Simulated against live state, never broadcast. Reverts unless the refusal is exactly the Standby
    ///      backing-capacity rejection carrying the canonical prospective capacity and obligation.
    /// @param _commitmentId The identity A1 established.
    function attemptDestructiveOrdinarySwapBaseSepolia(uint256 _commitmentId) external {
        (StandbyEnvironment memory environment, StandbyActors memory actors) = _loadBaseSepolia();
        PublicPeripheryConfig memory periphery = _peripheryOnly();

        StandbyHook hook = environment.hook;

        (PoolKey memory poolKey, SwapParams memory proposal) =
            _officialRouterProposal(hook, StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT);

        uint256 prospectiveCapacity = hook.prospectiveSupportingCapacityAfterSwap(proposal);
        uint256 obligation = hook.aggregateObligation();

        if (prospectiveCapacity != StandbyFixtureConfig.EXPECTED_A3_PROSPECTIVE_S) {
            revert BaseSepoliaActions__ProspectiveCapacityMismatch(
                StandbyFixtureConfig.EXPECTED_A3_PROSPECTIVE_S, prospectiveCapacity
            );
        }

        console2.log("A3 requested protected output:", StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT);
        console2.log("A3 current authoritative S:", hook.supportingCapacity());
        console2.log("A3 prospective S':", prospectiveCapacity);
        console2.log("A3 required O:", obligation);

        (bytes memory commands, bytes[] memory inputs) = DeployedUniversalRouterCalldata.exactOutputSingle(
            poolKey,
            proposal.zeroForOne,
            uint128(StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT),
            uint128(ORDINARY_SWAP_MAX_INPUT)
        );

        uint256 deadline = block.timestamp + PERIPHERY_DEADLINE_WINDOW;
        IDeployedUniversalRouter router = IDeployedUniversalRouter(periphery.universalRouter);

        vm.prank(actors.trader);

        try router.execute(commands, inputs, deadline) {
            revert DemoActions__DestructiveSwapWasNotRejected();
        } catch (bytes memory reason) {
            _requireStandbyBackingRejection(hook, reason, prospectiveCapacity, obligation);
        }

        console2.log("A3 rejected by the Standby backing requirement");

        _reportState(environment, "post-A3");

        _requireStageState(
            environment,
            _commitmentId,
            StandbyFixtureConfig.EXPECTED_A2_S,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q,
            StandbyFixtureConfig.CANONICAL_COMMITMENT_Q
        );
    }

    /// @notice A4 — exercises the canonical commitment in full through the accepted ExerciseRouter.
    /// @param _commitmentId The identity A1 established.
    function exerciseCommitmentBaseSepolia(uint256 _commitmentId) external {
        (StandbyEnvironment memory environment, StandbyActors memory actors) = _loadBaseSepolia();

        uint256 beneficiaryBefore = environment.usdc.balanceOf(actors.beneficiary);

        _a4ExerciseCommitment(environment, actors, _commitmentId);

        uint256 delivered = environment.usdc.balanceOf(actors.beneficiary) - beneficiaryBefore;

        if (delivered != StandbyFixtureConfig.CANONICAL_COMMITMENT_Q) {
            revert BaseSepoliaActions__BeneficiaryDeliveryMismatch(
                StandbyFixtureConfig.CANONICAL_COMMITMENT_Q, delivered
            );
        }

        _requireNoProtectedOutputCustody(environment);

        _requireStageState(environment, _commitmentId, EXPECTED_A4_S, 0, 0);
    }

    /// @notice Re-reads the mined chain and requires one canonical stage state.
    /// @dev Read-only against the chain; run without `--broadcast`. Also requires that neither Standby contract
    ///      holds protected output, which holds at every canonical stage.
    /// @param _commitmentId The commitment whose Remaining Entitlement is checked; zero skips that check.
    /// @param _expectedS The canonical Supporting Capacity.
    /// @param _expectedO The canonical Aggregate Capacity Obligation.
    /// @param _expectedRemaining The canonical Remaining Entitlement.
    function verifyBaseSepoliaState(
        uint256 _commitmentId,
        uint256 _expectedS,
        uint256 _expectedO,
        uint256 _expectedRemaining
    ) external {
        (NetworkConfig memory config, PublicPeripheryConfig memory periphery) = _resolveBaseSepoliaInfrastructure();
        StandbyEnvironment memory environment = _baseSepoliaEnvironmentFromEnv(config);

        _requirePublicTopologyBindings(environment, periphery);

        _reportState(environment, "verified");

        if (_commitmentId != 0) _reportCommitment(environment, _commitmentId);

        _requireNoProtectedOutputCustody(environment);
        _requireStageState(environment, _commitmentId, _expectedS, _expectedO, _expectedRemaining);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves validated infrastructure, the deployed manifest, and the signing roles.
    function _loadBaseSepolia() internal returns (StandbyEnvironment memory environment, StandbyActors memory actors) {
        (NetworkConfig memory config, PublicPeripheryConfig memory periphery) = _resolveBaseSepoliaInfrastructure();

        environment = _baseSepoliaEnvironmentFromEnv(config);

        _requirePublicTopologyBindings(environment, periphery);

        actors = _rememberBaseSepoliaActors();
    }

    /// @dev Resolves the validated official periphery.
    function _peripheryOnly() internal returns (PublicPeripheryConfig memory periphery) {
        (, periphery) = _resolveBaseSepoliaInfrastructure();
    }

    /// @dev Builds the PoolManager swap proposal the official router makes for a canonical ordinary swap.
    ///
    ///      The pool and the protected direction are read from the Hook's own activated service basis. The price
    ///      limit is the one the official V4Router hands the PoolManager for every exact-output single swap.
    function _officialRouterProposal(StandbyHook _hook, uint256 _amountOut)
        internal
        view
        returns (PoolKey memory poolKey, SwapParams memory proposal)
    {
        StandbyHook.ProtectedExecutionService memory service = _hook.protectedExecutionService();

        poolKey = service.poolKey;

        proposal = SwapParams({
            zeroForOne: service.protectedZeroForOne,
            amountSpecified: int256(_amountOut),
            sqrtPriceLimitX96: service.protectedZeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
    }

    /// @dev Requires one canonical stage state from the Hook's authoritative derivations and records.
    function _requireStageState(
        StandbyEnvironment memory _environment,
        uint256 _commitmentId,
        uint256 _expectedS,
        uint256 _expectedO,
        uint256 _expectedRemaining
    ) internal view {
        uint256 capacity = _environment.hook.supportingCapacity();

        if (capacity != _expectedS) revert BaseSepoliaActions__SupportingCapacityMismatch(_expectedS, capacity);

        uint256 obligation = _environment.hook.aggregateObligation();

        if (obligation != _expectedO) revert BaseSepoliaActions__CapacityObligationMismatch(_expectedO, obligation);

        if (_commitmentId == 0) return;

        uint256 remaining = uint256(_environment.hook.commitment(_commitmentId).remainingEntitlement);

        if (remaining != _expectedRemaining) {
            revert BaseSepoliaActions__RemainingEntitlementMismatch(_expectedRemaining, remaining);
        }
    }

    /// @dev Requires neither the Hook nor the ExerciseRouter to hold protected output.
    function _requireNoProtectedOutputCustody(StandbyEnvironment memory _environment) internal view {
        uint256 hookBalance = _environment.usdc.balanceOf(address(_environment.hook));

        if (hookBalance != 0) {
            revert BaseSepoliaActions__ProtectedOutputCustody(address(_environment.hook), hookBalance);
        }

        uint256 routerBalance = _environment.usdc.balanceOf(address(_environment.exerciseRouter));

        if (routerBalance != 0) {
            revert BaseSepoliaActions__ProtectedOutputCustody(address(_environment.exerciseRouter), routerBalance);
        }
    }
}
