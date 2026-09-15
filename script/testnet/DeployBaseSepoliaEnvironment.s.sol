// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";
import {ExerciseRouter} from "../../src/ExerciseRouter.sol";

import {StandbyHookDeployment} from "../DeployStandbyHook.s.sol";
import {DeterministicFixtureDeployer} from "../helpers/DeterministicFixtureDeployer.sol";
import {NetworkConfig, PublicPeripheryConfig} from "../helpers/NetworkConfig.sol";
import {StandbyActors, StandbyEnvironment} from "../helpers/StandbyEnvironment.sol";

import {BaseSepoliaScript} from "./BaseSepoliaScript.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title DeployBaseSepoliaEnvironment
/// @notice Supplementary post-submission (F9T) composition of a Standby environment on Base Sepolia.
/// @dev Composition only, and the public-network counterpart of `DeployDemoEnvironment`. It configures no
///      service, seeds no eligibility, funds no account, adds no liquidity, and establishes no commitment.
///
///      It owns no deployment logic that exists elsewhere. The fixture currencies come from the deterministic
///      ordered fixture deployer, so `MockUSTB` is `currency0` and `MockUSDC` is `currency1` by construction. The
///      Hook comes from the canonical procedure this script inherits — the pinned `HookMiner`, the salted
///      creation routed through the deterministic CREATE2 factory under broadcast, and the canonical permission,
///      PoolManager, and trust-binding validation.
///
///      The one difference from the local composition is which perimeters the Hook trusts. No
///      `ActorAwareTestRouter` is deployed: the Hook binds the official Universal Router and PositionManager,
///      resolved and validated by `HelperConfig`. The order is otherwise the same dependency-forced one — the
///      perimeters exist before the Hook binds them, and the ExerciseRouter follows the Hook it resolves its
///      PoolManager from.
contract DeployBaseSepoliaEnvironment is StandbyHookDeployment, BaseSepoliaScript {
    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Script entrypoint: validates Base Sepolia infrastructure and composes the environment.
    /// @return environment The deployed address manifest; its demo-perimeter fields are empty.
    /// @return periphery The validated official periphery the Hook was bound to.
    function run() external returns (StandbyEnvironment memory environment, PublicPeripheryConfig memory periphery) {
        StandbyActors memory actors = _baseSepoliaActorsFromEnv();

        NetworkConfig memory config;
        (config, periphery) = _resolveBaseSepoliaInfrastructure();

        environment = deployBaseSepoliaEnvironment(
            IPoolManager(config.poolManager), periphery, actors.configurationAuthority, actors.registryAdmin
        );

        console2.log("Standby chain id:       ", config.chainId);
        console2.log("Standby PoolManager:    ", config.poolManager);
        console2.log("Standby UniversalRouter:", periphery.universalRouter);
        console2.log("Standby PositionManager:", periphery.positionManager);
        console2.log("Standby Permit2:        ", periphery.permit2);
        console2.log("Standby MockUSTB:       ", address(environment.ustb));
        console2.log("Standby MockUSDC:       ", address(environment.usdc));
        console2.log("Standby registry:       ", address(environment.registry));
        console2.log("Standby Hook:           ", address(environment.hook));
        console2.log("Standby ExerciseRouter: ", address(environment.exerciseRouter));
        console2.log("Role configurationAuthority:", actors.configurationAuthority);
        console2.log("Role establishmentAuthority:", actors.establishmentAuthority);
        console2.log("Role registryAdmin:         ", actors.registryAdmin);
        console2.log("Role liquidityProvider:     ", actors.liquidityProvider);
        console2.log("Role trader:                ", actors.trader);
        console2.log("Role beneficiary:           ", actors.beneficiary);
        console2.log("Role exerciseAuthority:     ", actors.exerciseAuthority);
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Composes the Standby-owned contracts against the official Base Sepolia v4 stack.
    /// @dev Owns its broadcast and must not be called from inside an open one, for the same reason as the local
    ///      composition: the salted Hook creation is routed through the deterministic CREATE2 factory only while
    ///      a broadcast is open, and the Hook address is mined against that factory.
    /// @param _poolManager The validated official PoolManager.
    /// @param _periphery The validated official periphery.
    /// @param _configurationAuthority The only account authorized to activate the Hook's service.
    /// @param _registryAdmin The EligibilityRegistry administrator.
    /// @return environment The deployed address manifest; its demo-perimeter fields are empty.
    function deployBaseSepoliaEnvironment(
        IPoolManager _poolManager,
        PublicPeripheryConfig memory _periphery,
        address _configurationAuthority,
        address _registryAdmin
    ) public returns (StandbyEnvironment memory environment) {
        environment.poolManager = _poolManager;

        vm.startBroadcast();

        DeterministicFixtureDeployer fixtureDeployer = new DeterministicFixtureDeployer();
        (environment.ustb, environment.usdc,) = fixtureDeployer.deployOrderedFixtureCurrencies();

        environment.registry = new EligibilityRegistry(_registryAdmin);

        (environment.hook,) = deployStandbyHook(
            _poolManager,
            CREATE2_FACTORY,
            _configurationAuthority,
            _periphery.universalRouter,
            _periphery.positionManager
        );

        environment.exerciseRouter = new ExerciseRouter(environment.hook);

        vm.stopBroadcast();
    }
}
