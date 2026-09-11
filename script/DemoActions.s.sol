// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {EligibilityRegistry} from "../src/EligibilityRegistry.sol";
import {ExerciseRouter} from "../src/ExerciseRouter.sol";
import {StandbyHook} from "../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../src/demo/ActorAwareTestRouter.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockUSTB} from "../src/mocks/MockUSTB.sol";

import {StandbyActors, StandbyEnvironment} from "./helpers/StandbyEnvironment.sol";
import {StandbyFixtureConfig} from "./helpers/StandbyFixtureConfig.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title DemoActions
/// @notice The four canonical judged Standby actions, performed through real production transitions.
/// @dev The non-browser path through the canonical demonstration, and the fallback if browser presentation
///      fails. It reproduces the protocol transitions rather than the interface: every action here is the
///      same production call the canonical acceptance history makes — `establishCommitment` for admission,
///      the trusted ordinary-swap perimeter for both ordinary swaps, and the `ExerciseRouter` for the
///      exercise — and every quantity it reports is read back from the Hook, the PoolManager, or token
///      balances.
///
///      It constructs nothing. Deployment belongs to `DeployDemoEnvironment` and the canonical pre-A1 state
///      belongs to `BootstrapStandby`; this script takes an environment those two already produced, named
///      by the same `STANDBY_*` environment variables bootstrap reads, and acts on it. It writes no
///      economic state of its own, holds no authority, and has no privileged path: each action is broadcast
///      from the account the protocol itself requires, and the deployed contracts are free to refuse it.
///
///      A3 is the one action that must not succeed, so it is performed as a simulated attempt rather than
///      a broadcast transaction: a rejected transition never becomes authoritative, and there is no
///      transaction for a broadcasting script to send. The attempt is made as the eligible trader, the
///      revert data is decoded, and it is required to be exactly the Standby backing-capacity rejection
///      carrying the two quantities the Hook compared — so a refusal caused by eligibility, allowance,
///      balance, the service domain, or an unrelated Uniswap failure fails this script instead of passing
///      as the canonical rejection.
contract DemoActions is Script {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The validity duration the canonical admitted commitment carries.
    uint64 public constant CANONICAL_VALIDITY_DURATION = 30 days;

    /// @notice The exerciser's own cost bound for the canonical exercise: 100,000.000000 MockUSTB.
    /// @dev Generous rather than unconstrained. The canonical exercise costs a little over 50,000 MockUSTB,
    ///      so no canonical outcome turns on this number — but production compares the authoritative input
    ///      debt against it, so it is a real bound rather than a value chosen to disable the comparison.
    uint256 public constant CANONICAL_EXERCISE_MAX_INPUT = 100_000_000_000;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the canonical destructive ordinary swap was not refused at all.
    error DemoActions__DestructiveSwapWasNotRejected();

    /// @notice Thrown when the destructive ordinary swap was refused for some other reason.
    /// @param reason The raw revert data the attempt actually produced.
    error DemoActions__UnexpectedRejectionReason(bytes reason);

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Runs the complete canonical A1 → A2 → A3 → A4 sequence against a bootstrapped environment.
    /// @dev One uninterrupted history over one live pool: A4 exercises the identity A1 returned, and no
    ///      stage reconstructs its own starting point.
    /// @return commitmentId The identity the production admission transition returned.
    function run() external returns (uint256 commitmentId) {
        StandbyEnvironment memory environment = _environmentFromEnv();
        StandbyActors memory actors = _actorsFromEnv();

        _reportState(environment, "bootstrap");

        commitmentId = _a1AdmitCommitment(environment, actors);
        _a2CompatibleOrdinarySwap(environment, actors);
        _a3AttemptDestructiveOrdinarySwap(environment, actors);
        _a4ExerciseCommitment(environment, actors, commitmentId);
    }

    /// @notice A1 — admits the canonical 50,000 MockUSDC commitment through the production O1 transition.
    /// @return commitmentId The identity the production admission transition returned.
    function admitCommitment() external returns (uint256 commitmentId) {
        commitmentId = _a1AdmitCommitment(_environmentFromEnv(), _actorsFromEnv());
    }

    /// @notice A2 — executes the compatible ordinary protected exact-output swap of 15,000 MockUSDC.
    function compatibleOrdinarySwap() external {
        _a2CompatibleOrdinarySwap(_environmentFromEnv(), _actorsFromEnv());
    }

    /// @notice A3 — attempts the capacity-destroying ordinary protected swap of 20,000 MockUSDC.
    /// @dev Expected to be refused. The attempt is simulated rather than broadcast, and this call reverts
    ///      unless the refusal is the specific Standby backing-capacity rejection.
    function attemptDestructiveOrdinarySwap() external {
        _a3AttemptDestructiveOrdinarySwap(_environmentFromEnv(), _actorsFromEnv());
    }

    /// @notice A4 — exercises a commitment in full through the production ExerciseRouter / O2 path.
    /// @param _commitmentId The identity A1 established.
    function exerciseCommitment(uint256 _commitmentId) external {
        _a4ExerciseCommitment(_environmentFromEnv(), _actorsFromEnv(), _commitmentId);
    }

    /// @notice Reports the canonical proposed-transaction parameters of the demonstration.
    /// @dev Proposed transaction facts, not protocol state: the quantities a judge asks Standby for and the
    ///      price limit the canonical ordinary swap carries. They are reported from the frozen fixture
    ///      library and the pinned Uniswap tick math so that a presentation layer consuming them never has
    ///      to restate either, and the service boundary they are derived against is read from the Hook.
    function printDemoParameters() external view {
        StandbyHook hook = StandbyHook(vm.envAddress("STANDBY_HOOK"));

        console2.log("STANDBY_PARAM sqrtPriceLimitX96", uint256(_canonicalSwapPriceLimit(hook)));
        console2.log("STANDBY_PARAM commitmentQ", StandbyFixtureConfig.CANONICAL_COMMITMENT_Q);
        console2.log("STANDBY_PARAM compatibleSwapOutput", StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT);
        console2.log("STANDBY_PARAM destructiveSwapOutput", StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT);
        console2.log("STANDBY_PARAM exerciseMaxInput", CANONICAL_EXERCISE_MAX_INPUT);
        console2.log("STANDBY_PARAM validityDuration", uint256(CANONICAL_VALIDITY_DURATION));
        console2.log("STANDBY_PARAM protectedZeroForOne", hook.protectedExecutionService().protectedZeroForOne);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev A1 — admission through the service's own establishment authority.
    ///
    ///      Admission establishes an obligation without consuming capacity and without segregating any
    ///      MockUSDC, which is the whole economic point of the stage; both are visible in the reported
    ///      state rather than asserted here.
    function _a1AdmitCommitment(StandbyEnvironment memory _environment, StandbyActors memory _actors)
        internal
        returns (uint256 commitmentId)
    {
        vm.startBroadcast(_actors.establishmentAuthority);

        commitmentId = _environment.hook.establishCommitment(
            _actors.beneficiary,
            _actors.exerciseAuthority,
            uint128(StandbyFixtureConfig.CANONICAL_COMMITMENT_Q),
            uint64(block.timestamp),
            uint64(block.timestamp) + CANONICAL_VALIDITY_DURATION
        );

        vm.stopBroadcast();

        console2.log("A1 admitted commitment id:", commitmentId);

        _reportState(_environment, "A1");
        _reportCommitment(_environment, commitmentId);
    }

    /// @dev A2 — the compatible ordinary swap, through the trusted perimeter as the eligible trader.
    ///
    ///      The decisive non-reservation stage: an ordinary trader with no relationship to the commitment
    ///      draws protected output from the same shared pool while the full obligation is outstanding.
    function _a2CompatibleOrdinarySwap(StandbyEnvironment memory _environment, StandbyActors memory _actors) internal {
        StandbyHook hook = _environment.hook;

        (PoolKey memory poolKey, SwapParams memory params) =
            _canonicalOrdinarySwap(hook, StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT);

        console2.log("A2 requested protected output:", StandbyFixtureConfig.COMPATIBLE_ORDINARY_SWAP_OUTPUT);
        console2.log("A2 prospective S':", hook.prospectiveSupportingCapacityAfterSwap(params));

        uint256 traderOutputBefore = _environment.usdc.balanceOf(_actors.trader);

        vm.startBroadcast(_actors.trader);

        _environment.swapPerimeter.swap(poolKey, params, bytes(""));

        vm.stopBroadcast();

        console2.log("A2 trader received:", _environment.usdc.balanceOf(_actors.trader) - traderOutputBefore);

        _reportState(_environment, "A2");
    }

    /// @dev A3 — the capacity-destroying ordinary attempt, refused for exactly one reason.
    ///
    ///      Otherwise entirely valid: the same eligible trader, the same trusted perimeter, funded,
    ///      approved, and inside the service domain. The expected rejection is reconstructed from the
    ///      production preview and the authoritative obligation, so the check names both quantities the
    ///      Hook actually compared rather than merely observing that something failed.
    function _a3AttemptDestructiveOrdinarySwap(StandbyEnvironment memory _environment, StandbyActors memory _actors)
        internal
    {
        StandbyHook hook = _environment.hook;

        (PoolKey memory poolKey, SwapParams memory params) =
            _canonicalOrdinarySwap(hook, StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT);

        uint256 prospectiveCapacity = hook.prospectiveSupportingCapacityAfterSwap(params);
        uint256 obligation = hook.aggregateObligation();

        console2.log("A3 requested protected output:", StandbyFixtureConfig.DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT);
        console2.log("A3 current authoritative S:", hook.supportingCapacity());
        console2.log("A3 prospective S':", prospectiveCapacity);
        console2.log("A3 required O:", obligation);

        vm.prank(_actors.trader);

        try _environment.swapPerimeter.swap(poolKey, params, bytes("")) {
            revert DemoActions__DestructiveSwapWasNotRejected();
        } catch (bytes memory reason) {
            _requireStandbyBackingRejection(hook, reason, prospectiveCapacity, obligation);
        }

        console2.log("A3 rejected by the Standby backing requirement");

        _reportState(_environment, "post-A3");
    }

    /// @dev A4 — the full exercise of the admitted commitment through the production O2 path.
    ///
    ///      The extent is the commitment's own authoritative Remaining Entitlement, and the delivery is
    ///      measured as the increase in the authoritative Beneficiary's own MockUSDC balance.
    function _a4ExerciseCommitment(
        StandbyEnvironment memory _environment,
        StandbyActors memory _actors,
        uint256 _commitmentId
    ) internal {
        StandbyHook.Commitment memory record = _environment.hook.commitment(_commitmentId);

        uint256 beneficiaryBefore = _environment.usdc.balanceOf(record.beneficiary);
        uint256 exerciserInputBefore = _environment.ustb.balanceOf(_actors.exerciseAuthority);

        vm.startBroadcast(_actors.exerciseAuthority);

        _environment.exerciseRouter.exercise(
            _commitmentId, uint256(record.remainingEntitlement), CANONICAL_EXERCISE_MAX_INPUT
        );

        vm.stopBroadcast();

        console2.log(
            "A4 Beneficiary MockUSDC delivered:", _environment.usdc.balanceOf(record.beneficiary) - beneficiaryBefore
        );
        console2.log(
            "A4 exerciser MockUSTB paid:", exerciserInputBefore - _environment.ustb.balanceOf(_actors.exerciseAuthority)
        );

        _reportState(_environment, "A4");
        _reportCommitment(_environment, _commitmentId);
    }

    /// @dev Requires a refusal to be the specific Standby backing-capacity rejection.
    ///
    ///      A failed Hook callback is wrapped by the pinned `Hooks` library rather than bubbled raw, so the
    ///      expectation names the wrapper, the Hook, the callback, and the Standby reason inside it.
    function _requireStandbyBackingRejection(
        StandbyHook _hook,
        bytes memory _reason,
        uint256 _prospectiveCapacity,
        uint256 _obligation
    ) internal pure {
        bytes memory expected = abi.encodeWithSelector(
            CustomRevert.WrappedError.selector,
            address(_hook),
            IHooks.beforeSwap.selector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientProspectiveBacking.selector, _prospectiveCapacity, _obligation
            ),
            abi.encodePacked(Hooks.HookCallFailed.selector)
        );

        if (keccak256(_reason) != keccak256(expected)) revert DemoActions__UnexpectedRejectionReason(_reason);
    }

    /// @dev Builds the canonical ordinary protected exact-output swap of a given quantity.
    ///
    ///      Both the pool and the protected direction are read from the Hook's own activated service basis
    ///      rather than reconstructed here, so the proposal cannot describe a different service than the
    ///      one enforcement will consult.
    function _canonicalOrdinarySwap(StandbyHook _hook, uint256 _amountOut)
        internal
        view
        returns (PoolKey memory poolKey, SwapParams memory params)
    {
        StandbyHook.ProtectedExecutionService memory service = _hook.protectedExecutionService();

        poolKey = service.poolKey;

        params = SwapParams({
            zeroForOne: service.protectedZeroForOne,
            amountSpecified: int256(_amountOut),
            sqrtPriceLimitX96: _canonicalSwapPriceLimit(_hook)
        });
    }

    /// @dev The square-root price limit the canonical ordinary swap carries: the service's own protected
    ///      execution-quality boundary `P_Q`.
    ///
    ///      A request larger than the domain can serve therefore stops exactly on `tickQ` instead of
    ///      leaving the configured realization domain, which is what keeps a refusal attributable to
    ///      backing rather than to a domain violation.
    function _canonicalSwapPriceLimit(StandbyHook _hook) internal view returns (uint160 sqrtPriceLimitX96) {
        sqrtPriceLimitX96 = TickMath.getSqrtPriceAtTick(_hook.protectedExecutionService().tickQ);
    }

    /// @dev Reports the authoritative economic state of the service after a stage.
    function _reportState(StandbyEnvironment memory _environment, string memory _stage) internal view {
        console2.log("--", _stage);
        console2.log("   Supporting Capacity S:", _environment.hook.supportingCapacity());
        console2.log("   Capacity Obligation O:", _environment.hook.aggregateObligation());
    }

    /// @dev Reports the authoritative fact record of a commitment after a stage.
    function _reportCommitment(StandbyEnvironment memory _environment, uint256 _commitmentId) internal view {
        StandbyHook.Commitment memory record = _environment.hook.commitment(_commitmentId);

        console2.log("   Original Entitlement:", uint256(record.originalEntitlement));
        console2.log("   Remaining Entitlement:", uint256(record.remainingEntitlement));
        console2.log("   Beneficiary MockUSDC:", _environment.usdc.balanceOf(record.beneficiary));
    }

    /// @dev Reads the deployed address manifest from the local environment.
    function _environmentFromEnv() internal view returns (StandbyEnvironment memory environment) {
        environment = StandbyEnvironment({
            poolManager: IPoolManager(vm.envAddress("STANDBY_POOL_MANAGER")),
            ustb: MockUSTB(vm.envAddress("STANDBY_USTB")),
            usdc: MockUSDC(vm.envAddress("STANDBY_USDC")),
            registry: EligibilityRegistry(vm.envAddress("STANDBY_REGISTRY")),
            swapPerimeter: ActorAwareTestRouter(vm.envAddress("STANDBY_SWAP_PERIMETER")),
            liquidityPerimeter: ActorAwareTestRouter(vm.envAddress("STANDBY_LIQUIDITY_PERIMETER")),
            hook: StandbyHook(vm.envAddress("STANDBY_HOOK")),
            exerciseRouter: ExerciseRouter(vm.envAddress("STANDBY_EXERCISE_ROUTER"))
        });
    }

    /// @dev Reads the environment's role assignments from the local environment.
    function _actorsFromEnv() internal view returns (StandbyActors memory actors) {
        actors = StandbyActors({
            configurationAuthority: vm.envAddress("STANDBY_CONFIGURATION_AUTHORITY"),
            establishmentAuthority: vm.envAddress("STANDBY_ESTABLISHMENT_AUTHORITY"),
            registryAdmin: vm.envAddress("STANDBY_REGISTRY_ADMIN"),
            liquidityProvider: vm.envAddress("STANDBY_LIQUIDITY_PROVIDER"),
            trader: vm.envAddress("STANDBY_TRADER"),
            beneficiary: vm.envAddress("STANDBY_BENEFICIARY"),
            exerciseAuthority: vm.envAddress("STANDBY_EXERCISE_AUTHORITY")
        });
    }
}
