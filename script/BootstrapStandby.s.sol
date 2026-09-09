// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {EligibilityRegistry} from "../src/EligibilityRegistry.sol";
import {ExerciseRouter} from "../src/ExerciseRouter.sol";
import {StandbyHook} from "../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../src/demo/ActorAwareTestRouter.sol";
import {IEligibilityRegistry} from "../src/interfaces/IEligibilityRegistry.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockUSTB} from "../src/mocks/MockUSTB.sol";

import {StandbyEnvironment, StandbyActors} from "./helpers/StandbyEnvironment.sol";
import {StandbyFixtureConfig} from "./helpers/StandbyFixtureConfig.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title BootstrapStandby
/// @notice Brings an already-deployed Standby environment to the canonical pre-A1 state.
/// @dev Bootstrap deploys nothing. It takes a complete deployed manifest and the accounts that hold the
///      environment's distinct roles, and reaches the canonical starting state the way any operator would
///      have to: it initializes the pool through the real PoolManager, activates the Protected Execution
///      Service through the Hook's own one-shot production transition as the configuration authority,
///      seeds the mutable eligibility predicates through the registry's own administrator, funds and
///      approves the actors, and adds the canonical controlled liquidity through the trusted liquidity
///      perimeter as an eligible provider — which means through the Hook's production `beforeAddLiquidity`
///      enforcement path.
///
///      Nothing here is privileged. No Supporting Capacity, Capacity Obligation, entitlement, commitment,
///      bounded reference, or pool value is written directly, and there is no path by which this script
///      could write one: every step is an ordinary external call that the deployed contracts are free to
///      refuse. It ends with a commitment-free service, which is a consequence of admitting no commitment
///      rather than an assumption.
///
///      The order is forced by the protocol rather than chosen. Activation requires an initialized pool
///      holding zero liquidity, so the canonical position can only be added after the service exists; and
///      the provider must already be eligible when it is added, because the Hook decides that on the
///      production liquidity path.
///
///      Each step is broadcast from the account that is actually authorized to perform it. Under
///      `forge test` the broadcast cheatcode sets the sender of the call, and under a broadcasting script
///      against the deterministic local environment each step is a real transaction from that actor, so
///      one implementation serves acceptance evidence and operational use without either becoming a second
///      version of the other. This function owns its broadcasts and must not be called from inside an open
///      one.
///
///      The closing checks are fixture fidelity checks, not protocol rules. They compare the state real
///      transitions actually produced against the frozen canonical fixture expectations, so a bootstrap
///      that silently reached some other state fails loudly here instead of quietly becoming the baseline
///      a later demonstration is measured from.
contract BootstrapStandby is Script {
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The raw quantity of each currency the bootstrap funds an actor with.
    /// @dev Round over-provision, and provisioning only: it is far larger than the canonical position,
    ///      swap, and exercise require, so no canonical outcome can turn on it. The canonical controlled
    ///      position alone needs roughly 99,850 units of each currency.
    uint256 public constant CANONICAL_ACTOR_FUNDING = 1_000_000_000_000;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the bootstrapped pool did not come to rest at the canonical initial tick.
    /// @param expected The canonical initial tick.
    /// @param actual The authoritative tick the PoolManager reports.
    error BootstrapStandby__InitialTickMismatch(int24 expected, int24 actual);

    /// @notice Thrown when the bootstrapped pool does not hold exactly the canonical active liquidity.
    /// @param expected The canonical active liquidity.
    /// @param actual The authoritative active liquidity the PoolManager reports.
    error BootstrapStandby__ActiveLiquidityMismatch(uint128 expected, uint128 actual);

    /// @notice Thrown when the bootstrapped service does not derive the canonical Supporting Capacity.
    /// @param expected The canonical expected initial Supporting Capacity.
    /// @param actual The Supporting Capacity the Hook authoritatively derives.
    error BootstrapStandby__SupportingCapacityMismatch(uint256 expected, uint256 actual);

    /// @notice Thrown when the bootstrapped service does not begin free of Capacity Obligation.
    /// @param obligation The Aggregate Capacity Obligation the Hook authoritatively derives.
    error BootstrapStandby__CapacityObligationNotZero(uint256 obligation);

    /// @notice Thrown when a commitment identity has already been consumed at the end of bootstrap.
    /// @param nextCommitmentId The identity the next admission would receive.
    error BootstrapStandby__CommitmentAlreadyEstablished(uint256 nextCommitmentId);

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Canonical script entrypoint: bootstraps an environment named by the local environment.
    /// @dev The manifest and the actors are inputs rather than decisions, so the operational wrapper only
    ///      reads them and calls the same function acceptance evidence calls.
    /// @return poolKey The canonical Hook-bound PoolKey the service was activated over.
    /// @return serviceId The identity of the activated Protected Execution Service.
    function run() external returns (PoolKey memory poolKey, PoolId serviceId) {
        StandbyEnvironment memory environment = _environmentFromEnv();
        StandbyActors memory actors = _actorsFromEnv();

        (poolKey, serviceId) = bootstrapStandby(environment, actors);

        console2.log("Standby service pool fee:", uint256(poolKey.fee));
        console2.log("Standby Supporting Capacity:", environment.hook.supportingCapacity());
        console2.log("Standby Capacity Obligation:", environment.hook.aggregateObligation());
        console2.logBytes32(PoolId.unwrap(serviceId));
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Brings a deployed environment to the canonical commitment-free pre-A1 state.
    /// @param _environment The complete deployed address manifest.
    /// @param _actors The accounts holding the environment's distinct roles.
    /// @return poolKey The canonical Hook-bound PoolKey the service was activated over.
    /// @return serviceId The identity of the activated Protected Execution Service.
    function bootstrapStandby(StandbyEnvironment memory _environment, StandbyActors memory _actors)
        public
        returns (PoolKey memory poolKey, PoolId serviceId)
    {
        poolKey = canonicalPoolKey(_environment);

        _initializeCanonicalPool(_environment, poolKey);

        serviceId = _activateCanonicalService(_environment, _actors, poolKey);

        _seedCanonicalEligibility(_environment, _actors);
        _fundAndApproveCanonicalActors(_environment, _actors);
        _addCanonicalLiquidity(_environment, _actors, poolKey);

        _requireCanonicalBootstrapState(_environment, serviceId);
    }

    /// @notice Builds the canonical Hook-bound PoolKey of a deployed environment.
    /// @dev The currency ordering is a property of the deterministic fixture deployment rather than an
    ///      assumption made here, and the fee and tick spacing are the frozen canonical fixture values.
    /// @param _environment The deployed address manifest.
    /// @return key The canonical PoolKey.
    function canonicalPoolKey(StandbyEnvironment memory _environment) public pure returns (PoolKey memory key) {
        key = PoolKey({
            currency0: Currency.wrap(address(_environment.ustb)),
            currency1: Currency.wrap(address(_environment.usdc)),
            fee: StandbyFixtureConfig.LP_FEE,
            tickSpacing: StandbyFixtureConfig.TICK_SPACING,
            hooks: IHooks(address(_environment.hook))
        });
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Initializes the canonical pool at the exact square-root price of the canonical initial tick.
    ///
    ///      Permissionless, and deliberately performed by no particular authority: initializing a pool is
    ///      a Uniswap operation that establishes no Standby fact.
    function _initializeCanonicalPool(StandbyEnvironment memory _environment, PoolKey memory _poolKey) internal {
        vm.startBroadcast();

        _environment.poolManager.initialize(_poolKey, TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.INITIAL_TICK));

        vm.stopBroadcast();
    }

    /// @dev Activates the canonical Protected Execution Service through the Hook's production transition.
    ///
    ///      The configuration authority is the only account that can do this, and the Hook decides that
    ///      itself. Everything the activation fixes — the service pool, the protected direction, the
    ///      service domain, the registry, the ExerciseRouter, and the establishment authority — is fixed
    ///      permanently and in one transaction.
    function _activateCanonicalService(
        StandbyEnvironment memory _environment,
        StandbyActors memory _actors,
        PoolKey memory _poolKey
    ) internal returns (PoolId serviceId) {
        vm.startBroadcast(_actors.configurationAuthority);

        serviceId = _environment.hook.configureAndActivate(
            _poolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(_environment.registry)),
            address(_environment.exerciseRouter),
            _actors.establishmentAuthority
        );

        vm.stopBroadcast();
    }

    /// @dev Grants the three mutable eligibility predicates the canonical sequence needs.
    ///
    ///      Through the registry's own administrator, one predicate per role: the Beneficiary may receive
    ///      protected service, the trader may swap, and the liquidity provider may provide liquidity. No
    ///      account is granted a predicate its part in the canonical sequence does not require, so an
    ///      authorization that succeeds cannot be succeeding on an unrelated grant.
    function _seedCanonicalEligibility(StandbyEnvironment memory _environment, StandbyActors memory _actors) internal {
        EligibilityRegistry registry = _environment.registry;

        vm.startBroadcast(_actors.registryAdmin);

        registry.setBeneficiaryEligibility(_actors.beneficiary, true);
        registry.setTraderEligibility(_actors.trader, true);
        registry.setLiquidityEligibility(_actors.liquidityProvider, true);

        vm.stopBroadcast();
    }

    /// @dev Funds the acting accounts and grants the approvals their perimeters need.
    ///
    ///      Two deliberate asymmetries. The exerciser is funded in the input currency only and approves
    ///      only the ExerciseRouter: an exerciser holding no protected output cannot be the source of
    ///      anything the Beneficiary later receives. And the Beneficiary is funded with nothing at all, so
    ///      its protected-output balance starts at zero and every unit it ends with came from the exercise.
    function _fundAndApproveCanonicalActors(StandbyEnvironment memory _environment, StandbyActors memory _actors)
        internal
    {
        vm.startBroadcast();

        _environment.ustb.mint(_actors.liquidityProvider, CANONICAL_ACTOR_FUNDING);
        _environment.usdc.mint(_actors.liquidityProvider, CANONICAL_ACTOR_FUNDING);

        _environment.ustb.mint(_actors.trader, CANONICAL_ACTOR_FUNDING);
        _environment.usdc.mint(_actors.trader, CANONICAL_ACTOR_FUNDING);

        _environment.ustb.mint(_actors.exerciseAuthority, CANONICAL_ACTOR_FUNDING);

        vm.stopBroadcast();

        vm.startBroadcast(_actors.liquidityProvider);
        _environment.ustb.approve(address(_environment.liquidityPerimeter), type(uint256).max);
        _environment.usdc.approve(address(_environment.liquidityPerimeter), type(uint256).max);
        vm.stopBroadcast();

        vm.startBroadcast(_actors.trader);
        _environment.ustb.approve(address(_environment.swapPerimeter), type(uint256).max);
        _environment.usdc.approve(address(_environment.swapPerimeter), type(uint256).max);
        vm.stopBroadcast();

        vm.startBroadcast(_actors.exerciseAuthority);
        _environment.ustb.approve(address(_environment.exerciseRouter), type(uint256).max);
        vm.stopBroadcast();
    }

    /// @dev Adds the canonical controlled position through the trusted liquidity perimeter.
    ///
    ///      The provider is the originating actor, so the addition passes through the Hook's production
    ///      liquidity enforcement: an ineligible provider, an untrusted perimeter, or a position boundary
    ///      inside the service domain would all be refused here rather than quietly admitted by a script.
    ///
    ///      The position spans the complete service domain with both endpoints outside it, which is what
    ///      keeps the canonical sequence inside one constant active-liquidity interval.
    function _addCanonicalLiquidity(
        StandbyEnvironment memory _environment,
        StandbyActors memory _actors,
        PoolKey memory _poolKey
    ) internal {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: StandbyFixtureConfig.LP_TICK_LOWER,
            tickUpper: StandbyFixtureConfig.LP_TICK_UPPER,
            liquidityDelta: int256(uint256(StandbyFixtureConfig.CANONICAL_LIQUIDITY)),
            salt: bytes32(0)
        });

        vm.startBroadcast(_actors.liquidityProvider);

        _environment.liquidityPerimeter.modifyLiquidity(_poolKey, params, bytes(""));

        vm.stopBroadcast();
    }

    /// @dev Requires the bootstrapped system to stand exactly at the canonical pre-A1 state.
    ///
    ///      Two authoritative sources, checked separately: the PoolManager for the realized pool state,
    ///      and the Hook for the economic quantities it derives from that state. The commitment-free
    ///      condition is checked on the identity counter rather than on the derived obligation, because an
    ///      obligation of zero is also what an expired or exhausted commitment would produce.
    function _requireCanonicalBootstrapState(StandbyEnvironment memory _environment, PoolId _serviceId) internal view {
        (, int24 tick,,) = _environment.poolManager.getSlot0(_serviceId);

        if (tick != StandbyFixtureConfig.INITIAL_TICK) {
            revert BootstrapStandby__InitialTickMismatch(StandbyFixtureConfig.INITIAL_TICK, tick);
        }

        uint128 liquidity = _environment.poolManager.getLiquidity(_serviceId);

        if (liquidity != StandbyFixtureConfig.CANONICAL_LIQUIDITY) {
            revert BootstrapStandby__ActiveLiquidityMismatch(StandbyFixtureConfig.CANONICAL_LIQUIDITY, liquidity);
        }

        uint256 capacity = _environment.hook.supportingCapacity();

        if (capacity != StandbyFixtureConfig.EXPECTED_INITIAL_S) {
            revert BootstrapStandby__SupportingCapacityMismatch(StandbyFixtureConfig.EXPECTED_INITIAL_S, capacity);
        }

        uint256 obligation = _environment.hook.aggregateObligation();

        if (obligation != 0) revert BootstrapStandby__CapacityObligationNotZero(obligation);

        uint256 nextCommitmentId = _environment.hook.nextCommitmentId();

        if (nextCommitmentId != 1) revert BootstrapStandby__CommitmentAlreadyEstablished(nextCommitmentId);
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
