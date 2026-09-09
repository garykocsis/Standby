// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {EligibilityRegistry} from "../src/EligibilityRegistry.sol";
import {ExerciseRouter} from "../src/ExerciseRouter.sol";
import {ActorAwareTestRouter} from "../src/demo/ActorAwareTestRouter.sol";

import {StandbyHookDeployment} from "./DeployStandbyHook.s.sol";
import {DeterministicFixtureDeployer} from "./helpers/DeterministicFixtureDeployer.sol";
import {HelperConfig} from "./helpers/HelperConfig.s.sol";
import {NetworkConfig} from "./helpers/NetworkConfig.sol";
import {StandbyEnvironment} from "./helpers/StandbyEnvironment.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title DeployDemoEnvironment
/// @notice The canonical deterministic composition of a complete Standby environment.
/// @dev Composition only. This script decides which contracts exist and in what order they are created;
///      it configures no Protected Execution Service, seeds no eligibility, funds no account, adds no
///      liquidity, and establishes no commitment. Everything economic about the resulting system is
///      established afterwards, by `BootstrapStandby`, through production transitions.
///
///      It owns no deployment logic that already exists elsewhere. The Hook is deployed by the canonical
///      procedure this script inherits, which keeps permission mining, salted deployment, and deployment
///      validation in exactly one place — and inheriting it rather than calling a deployed instance of it
///      is what lets the composition work on a real chain at all, since a contract carrying the Hook's
///      creation code is far above the deployed-contract size limit. The fixture currencies are deployed
///      by the deterministic ordered fixture deployer, so `MockUSTB` is `currency0` and `MockUSDC` is
///      `currency1` by construction rather than by deployment luck.
///
///      The order is dependency-forced rather than stylistic. Both trusted perimeters must exist before
///      the Hook, because the Hook binds them immutably at construction and its address is mined over
///      those constructor arguments. The Hook must exist before the ExerciseRouter, because the router
///      resolves its PoolManager from the Hook. And the ExerciseRouter must exist before bootstrap,
///      because the service's one-shot activation fixes the router address permanently.
///
///      The composition is a callable function so that the deterministic construction path used by
///      acceptance evidence and the one used operationally are the same implementation. `run()` supplies
///      environment-specific inputs and reports the manifest; it adds no construction semantics.
contract DeployDemoEnvironment is StandbyHookDeployment {
    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Canonical script entrypoint: resolves infrastructure and composes the environment.
    /// @dev The two roles this composition cannot resolve are supplied through the environment. Neither
    ///      is defaulted: a Hook deployed against a guessed configuration authority is permanently
    ///      unconfigurable, and a registry deployed against a guessed administrator is permanently
    ///      unadministrable. The remaining roles are bootstrap inputs rather than deployment inputs and
    ///      are supplied to `BootstrapStandby`.
    ///
    /// @return environment The complete deployed address manifest.
    /// @return config The resolved infrastructure configuration the environment was deployed against.
    function run() external returns (StandbyEnvironment memory environment, NetworkConfig memory config) {
        address configurationAuthority = vm.envAddress("STANDBY_CONFIGURATION_AUTHORITY");
        address registryAdmin = vm.envAddress("STANDBY_REGISTRY_ADMIN");

        (environment, config) = resolveAndDeployEnvironment(configurationAuthority, registryAdmin);

        console2.log("Standby chain id:       ", config.chainId);
        console2.log("Standby PoolManager:    ", config.poolManager);
        console2.log("Standby MockUSTB:       ", address(environment.ustb));
        console2.log("Standby MockUSDC:       ", address(environment.usdc));
        console2.log("Standby registry:       ", address(environment.registry));
        console2.log("Standby swap perimeter: ", address(environment.swapPerimeter));
        console2.log("Standby LP perimeter:   ", address(environment.liquidityPerimeter));
        console2.log("Standby Hook:           ", address(environment.hook));
        console2.log("Standby ExerciseRouter: ", address(environment.exerciseRouter));
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Resolves the active chain's Uniswap v4 infrastructure and composes the environment on it.
    /// @dev The resolution step is the same one every Standby deployment uses, so the environment can
    ///      only ever be composed around a validated PoolManager for the active chain.
    ///
    ///      The resolver is created from its compiled artifact rather than with `new`. That is a size
    ///      constraint, not a preference: creating it inline would carry the whole local-infrastructure
    ///      creation code inside this script as well as the Hook's, which together exceed the init-code
    ///      limit and would make this script undeployable in any context. The artifact is the same
    ///      compiled `HelperConfig`, so the resolution it performs is unchanged.
    /// @param _configurationAuthority The only account authorized to activate the Hook's service.
    /// @param _registryAdmin The EligibilityRegistry administrator.
    /// @return environment The complete deployed address manifest.
    /// @return config The resolved infrastructure configuration.
    function resolveAndDeployEnvironment(address _configurationAuthority, address _registryAdmin)
        public
        returns (StandbyEnvironment memory environment, NetworkConfig memory config)
    {
        HelperConfig helperConfig = HelperConfig(vm.deployCode("HelperConfig.s.sol:HelperConfig"));
        config = helperConfig.getNetworkConfig();

        environment = deployEnvironment(IPoolManager(config.poolManager), _configurationAuthority, _registryAdmin);
    }

    /// @notice Composes a complete Standby environment against an already-resolved PoolManager.
    /// @dev The two perimeters are two separately deployed instances of the same `ActorAwareTestRouter`
    ///      bytecode. Identical code, distinct trust roles: a perimeter trusted for ordinary swaps
    ///      authorizes nothing in the liquidity family and the reverse, and that separation is a property
    ///      of the Hook's immutable bindings rather than of two implementations invented to differ.
    ///
    ///      This function owns its broadcast, in the same way infrastructure resolution owns its own, so
    ///      it must not be called from inside an open broadcast. Owning it is also what makes the Hook's
    ///      address deterministic across contexts: while a broadcast is open, a salted creation performed
    ///      by this script is routed through the deterministic CREATE2 factory — under `forge test`
    ///      exactly as under `forge script` — so the factory is the account the Hook address is mined
    ///      against either way, and the acceptance path and the operational path deploy identically.
    /// @param _poolManager The real Uniswap v4 PoolManager to deploy against.
    /// @param _configurationAuthority The only account authorized to activate the Hook's service.
    /// @param _registryAdmin The EligibilityRegistry administrator.
    /// @return environment The complete deployed address manifest.
    function deployEnvironment(IPoolManager _poolManager, address _configurationAuthority, address _registryAdmin)
        public
        returns (StandbyEnvironment memory environment)
    {
        environment.poolManager = _poolManager;

        vm.startBroadcast();

        DeterministicFixtureDeployer fixtureDeployer = new DeterministicFixtureDeployer();
        (environment.ustb, environment.usdc,) = fixtureDeployer.deployOrderedFixtureCurrencies();

        environment.registry = new EligibilityRegistry(_registryAdmin);

        environment.swapPerimeter = new ActorAwareTestRouter(_poolManager);
        environment.liquidityPerimeter = new ActorAwareTestRouter(_poolManager);

        (environment.hook,) = deployStandbyHook(
            _poolManager,
            CREATE2_FACTORY,
            _configurationAuthority,
            address(environment.swapPerimeter),
            address(environment.liquidityPerimeter)
        );

        environment.exerciseRouter = new ExerciseRouter(environment.hook);

        vm.stopBroadcast();
    }
}
