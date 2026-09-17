// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Script} from "forge-std/Script.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";
import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../../src/demo/ActorAwareTestRouter.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockUSTB} from "../../src/mocks/MockUSTB.sol";

import {HelperConfig} from "../helpers/HelperConfig.s.sol";
import {NetworkConfig, PublicPeripheryConfig} from "../helpers/NetworkConfig.sol";
import {StandbyActors, StandbyEnvironment} from "../helpers/StandbyEnvironment.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title BaseSepoliaScript
/// @notice Shared operational context of the supplementary Base Sepolia (F9T) Standby scripts.
/// @dev Operational plumbing only: infrastructure resolution, the deployed manifest, role accounts, and gas
///      funding. It owns no Standby economic semantics and adds no transition of its own; every economic step
///      the F9T scripts take is an inherited canonical procedure or an ordinary call through official periphery.
///
///      Role accounts. The canonical environment gives every role its own account, because collapsing two of
///      them would make a later observation ambiguous. A public deployment is supplied with one funded key, so
///      each role's key is derived deterministically from it under a fixed domain. Nothing derived is ever
///      logged or persisted: the same root key reproduces the same role accounts on every invocation, which is
///      what lets the lifecycle be run stage by stage. The derivation is operational key management, not
///      Standby authority — authority is whatever the deployed contracts bind those accounts to.
///
///      The deployed manifest uses the canonical `StandbyEnvironment` so the canonical bootstrap and action
///      procedures can be reused unchanged. Its two demo-perimeter fields are deliberately left empty: this
///      environment deploys no `ActorAwareTestRouter`, and its trusted perimeters are the official Universal
///      Router and PositionManager bound immutably inside the Hook.
///
///      These scripts read the root key from the environment. Do not run them at a verbosity that prints
///      cheatcode traces, which would display key material.
abstract contract BaseSepoliaScript is Script {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The domain separating Standby F9T role-key derivation from every other use of the root key.
    bytes32 public constant ROLE_KEY_DOMAIN = keccak256("standby.f9t.base-sepolia.role");

    /// @notice The native balance each signing role is topped up to before it acts.
    /// @dev Gas provisioning only; far above what any role's transactions cost on Base Sepolia.
    uint256 public constant ROLE_GAS_FUNDING = 0.002 ether;

    /// @notice How far past the current block an official-periphery deadline is set.
    uint256 public constant PERIPHERY_DEADLINE_WINDOW = 1 hours;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a deployed Standby contract is not bound to the expected counterpart.
    /// @param component The contract whose binding was read.
    /// @param binding The selector of the binding getter.
    /// @param expected The counterpart the public topology requires.
    /// @param actual The counterpart actually bound.
    error BaseSepoliaScript__EnvironmentBindingMismatch(
        address component, bytes4 binding, address expected, address actual
    );

    /// @notice Thrown when a role account could not be funded with gas.
    /// @param role The account being funded.
    /// @param amount The top-up attempted.
    error BaseSepoliaScript__RoleGasFundingFailed(address role, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Derives the key of one F9T role from the root deployment key.
    /// @param _rootKey The funded root deployment key.
    /// @param _role The role name.
    /// @return key The role's private key, reduced into `[1, n - 1]` by forge-std's secp256k1 group order.
    function deriveRoleKey(uint256 _rootKey, string memory _role) public pure returns (uint256 key) {
        key = uint256(keccak256(abi.encode(ROLE_KEY_DOMAIN, _rootKey, _role))) % (SECP256K1_ORDER - 1) + 1;
    }

    /// @notice Derives the account of every F9T role from the root deployment key.
    /// @param _rootKey The funded root deployment key.
    /// @return actors One distinct account per canonical role.
    function baseSepoliaActors(uint256 _rootKey) public pure returns (StandbyActors memory actors) {
        actors = StandbyActors({
            configurationAuthority: vm.addr(deriveRoleKey(_rootKey, "configurationAuthority")),
            establishmentAuthority: vm.addr(deriveRoleKey(_rootKey, "establishmentAuthority")),
            registryAdmin: vm.addr(deriveRoleKey(_rootKey, "registryAdmin")),
            liquidityProvider: vm.addr(deriveRoleKey(_rootKey, "liquidityProvider")),
            trader: vm.addr(deriveRoleKey(_rootKey, "trader")),
            beneficiary: vm.addr(deriveRoleKey(_rootKey, "beneficiary")),
            exerciseAuthority: vm.addr(deriveRoleKey(_rootKey, "exerciseAuthority"))
        });
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Derives the role accounts from the environment's root key without registering any signer.
    function _baseSepoliaActorsFromEnv() internal view returns (StandbyActors memory actors) {
        actors = baseSepoliaActors(vm.envUint("PRIVATE_KEY"));
    }

    /// @dev Derives the role accounts and registers every signing role's key with the script.
    ///
    ///      The Beneficiary never sends a transaction, so its key is not registered.
    function _rememberBaseSepoliaActors() internal returns (StandbyActors memory actors) {
        uint256 rootKey = vm.envUint("PRIVATE_KEY");

        actors = baseSepoliaActors(rootKey);

        vm.rememberKey(deriveRoleKey(rootKey, "configurationAuthority"));
        vm.rememberKey(deriveRoleKey(rootKey, "establishmentAuthority"));
        vm.rememberKey(deriveRoleKey(rootKey, "registryAdmin"));
        vm.rememberKey(deriveRoleKey(rootKey, "liquidityProvider"));
        vm.rememberKey(deriveRoleKey(rootKey, "trader"));
        vm.rememberKey(deriveRoleKey(rootKey, "exerciseAuthority"));
    }

    /// @dev Resolves and validates the Base Sepolia infrastructure through the canonical resolver.
    ///
    ///      The periphery is resolved first, so an unsupported chain is refused before anything else happens.
    ///      The resolver is created from its compiled artifact so that no script inheriting this contract carries
    ///      its creation code.
    function _resolveBaseSepoliaInfrastructure()
        internal
        returns (NetworkConfig memory config, PublicPeripheryConfig memory periphery)
    {
        HelperConfig helperConfig = HelperConfig(vm.deployCode("HelperConfig.s.sol:HelperConfig"));

        periphery = helperConfig.getPublicPeripheryConfig();
        config = helperConfig.getNetworkConfig();
    }

    /// @dev Reads the deployed Standby-owned manifest from the environment.
    ///
    ///      The PoolManager comes from validated infrastructure resolution, not from the environment.
    function _baseSepoliaEnvironmentFromEnv(NetworkConfig memory _config)
        internal
        view
        returns (StandbyEnvironment memory environment)
    {
        environment = StandbyEnvironment({
            poolManager: IPoolManager(_config.poolManager),
            ustb: MockUSTB(vm.envAddress("STANDBY_USTB")),
            usdc: MockUSDC(vm.envAddress("STANDBY_USDC")),
            registry: EligibilityRegistry(vm.envAddress("STANDBY_REGISTRY")),
            swapPerimeter: ActorAwareTestRouter(address(0)),
            liquidityPerimeter: ActorAwareTestRouter(address(0)),
            hook: StandbyHook(vm.envAddress("STANDBY_HOOK")),
            exerciseRouter: ExerciseRouter(vm.envAddress("STANDBY_EXERCISE_ROUTER"))
        });
    }

    /// @dev Requires the deployed Hook and ExerciseRouter to be bound to the validated public topology.
    function _requirePublicTopologyBindings(
        StandbyEnvironment memory _environment,
        PublicPeripheryConfig memory _periphery
    ) internal view {
        StandbyHook hook = _environment.hook;

        _requireBound(
            address(hook), hook.poolManager.selector, address(_environment.poolManager), address(hook.poolManager())
        );
        _requireBound(
            address(hook),
            hook.i_trustedUniversalRouter.selector,
            _periphery.universalRouter,
            hook.i_trustedUniversalRouter()
        );
        _requireBound(
            address(hook),
            hook.i_trustedPositionManager.selector,
            _periphery.positionManager,
            hook.i_trustedPositionManager()
        );
        _requireBound(
            address(_environment.exerciseRouter),
            _environment.exerciseRouter.i_hook.selector,
            address(hook),
            address(_environment.exerciseRouter.i_hook())
        );
    }

    /// @dev Tops every signing role up to `ROLE_GAS_FUNDING` from the default broadcaster.
    function _fundRoleGas(StandbyActors memory _actors) internal {
        address[6] memory signers = [
            _actors.configurationAuthority,
            _actors.establishmentAuthority,
            _actors.registryAdmin,
            _actors.liquidityProvider,
            _actors.trader,
            _actors.exerciseAuthority
        ];

        vm.startBroadcast();

        for (uint256 i = 0; i < signers.length; ++i) {
            uint256 balance = signers[i].balance;

            if (balance >= ROLE_GAS_FUNDING) continue;

            uint256 amount = ROLE_GAS_FUNDING - balance;

            (bool success,) = signers[i].call{value: amount}("");

            if (!success) revert BaseSepoliaScript__RoleGasFundingFailed(signers[i], amount);
        }

        vm.stopBroadcast();
    }

    /// @dev Requires one binding to equal its expected counterpart.
    function _requireBound(address _component, bytes4 _binding, address _expected, address _actual) internal pure {
        if (_actual != _expected) {
            revert BaseSepoliaScript__EnvironmentBindingMismatch(_component, _binding, _expected, _actual);
        }
    }
}
