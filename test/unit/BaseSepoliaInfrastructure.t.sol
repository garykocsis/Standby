// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {HelperConfig} from "../../script/helpers/HelperConfig.s.sol";
import {NetworkConfig, PublicPeripheryConfig} from "../../script/helpers/NetworkConfig.sol";
import {BaseSepoliaScript} from "../../script/testnet/BaseSepoliaScript.sol";
import {StandbyActors} from "../../script/helpers/StandbyEnvironment.sol";

import {
    InfrastructureCodeStub,
    PositionManagerBindingStub,
    UniversalRouterBindingStub
} from "../harness/PublicPeripheryStubs.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title BaseSepoliaRolesHarness
/// @notice Concrete instance of the abstract F9T script context, exposing its public role derivation.
contract BaseSepoliaRolesHarness is BaseSepoliaScript {}

/// @title BaseSepoliaInfrastructureTest
/// @notice Unit evidence for the supplementary F9T Base Sepolia infrastructure resolution and preflight.
/// @dev The frozen topology is stated here as independent literals rather than read back from `HelperConfig`, so a
///      wrong constant cannot pass by agreeing with itself. External contracts are represented by stubs etched at
///      the frozen addresses; they carry binding getters only and are configuration-preflight evidence, never
///      Standby economic evidence. Whether the real deployed stack satisfies the preflight is established against
///      Base Sepolia itself, not here.
contract BaseSepoliaInfrastructureTest is Test {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant BASE_SEPOLIA = 84_532;

    address internal constant POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    address internal constant UNIVERSAL_ROUTER = 0x492E6456D9528771018DeB9E87ef7750EF184104;
    address internal constant POSITION_MANAGER = 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80;
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant STATE_VIEW = 0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4;
    address internal constant QUOTER = 0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa;

    /// @dev The historical Base Sepolia Universal Router's actual bindings, which must be refused.
    address internal constant HISTORICAL_POOL_MANAGER = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
    address internal constant HISTORICAL_POSITION_MANAGER = 0xcDbe7b1ed817eF0005ECe6a3e576fbAE2EA5EAFE;

    bytes4 internal constant POOL_MANAGER_GETTER = bytes4(keccak256("poolManager()"));
    bytes4 internal constant V4_POSITION_MANAGER_GETTER = bytes4(keccak256("V4_POSITION_MANAGER()"));
    bytes4 internal constant PERMIT2_GETTER = bytes4(keccak256("permit2()"));

    HelperConfig internal helperConfig;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        helperConfig = new HelperConfig();

        vm.chainId(BASE_SEPOLIA);

        _etchCompatibleTopology();
    }

    /*//////////////////////////////////////////////////////////////
                          RESOLUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice A compatible frozen topology resolves to the frozen Base Sepolia PoolManager.
    function test_baseSepolia_resolvesFrozenPoolManager() public {
        NetworkConfig memory config = helperConfig.getNetworkConfig();

        assertEq(config.chainId, BASE_SEPOLIA, "config must describe Base Sepolia");
        assertEq(config.poolManager, POOL_MANAGER, "config must resolve the frozen PoolManager");
    }

    /// @notice A compatible frozen topology resolves exactly the frozen official periphery.
    function test_baseSepolia_resolvesFrozenPublicPeriphery() public view {
        PublicPeripheryConfig memory periphery = helperConfig.getPublicPeripheryConfig();

        assertEq(periphery.universalRouter, UNIVERSAL_ROUTER, "frozen Universal Router");
        assertEq(periphery.positionManager, POSITION_MANAGER, "frozen PositionManager");
        assertEq(periphery.permit2, PERMIT2, "frozen Permit2");
        assertEq(periphery.stateView, STATE_VIEW, "frozen StateView");
        assertEq(periphery.quoter, QUOTER, "frozen V4 Quoter");
    }

    /// @notice The official periphery is never resolved for the deterministic local environment.
    function test_publicPeriphery_isRejectedOnLocalEnvironment() public {
        vm.chainId(31_337);

        vm.expectRevert(abi.encodeWithSelector(HelperConfig.HelperConfig__UnsupportedNetwork.selector, uint256(31_337)));
        helperConfig.getPublicPeripheryConfig();
    }

    /// @notice A chain with no validated topology is rejected by both resolvers.
    function test_baseSepolia_otherPublicChainIsRejected() public {
        vm.chainId(8453);

        vm.expectRevert(abi.encodeWithSelector(HelperConfig.HelperConfig__UnsupportedNetwork.selector, uint256(8453)));
        helperConfig.getNetworkConfig();

        vm.expectRevert(abi.encodeWithSelector(HelperConfig.HelperConfig__UnsupportedNetwork.selector, uint256(8453)));
        helperConfig.getPublicPeripheryConfig();
    }

    /*//////////////////////////////////////////////////////////////
                        BYTECODE PRESENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Every frozen infrastructure address is required to hold code.
    function test_baseSepolia_rejectsMissingInfrastructureCode() public {
        address[6] memory components = [POOL_MANAGER, UNIVERSAL_ROUTER, POSITION_MANAGER, PERMIT2, STATE_VIEW, QUOTER];

        for (uint256 i = 0; i < components.length; ++i) {
            bytes memory code = components[i].code;

            vm.etch(components[i], bytes(""));

            vm.expectRevert(
                abi.encodeWithSelector(HelperConfig.HelperConfig__MissingInfrastructureCode.selector, components[i])
            );
            helperConfig.getNetworkConfig();

            vm.etch(components[i], code);
        }
    }

    /*//////////////////////////////////////////////////////////////
                         BINDING COMPATIBILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice A router bound to the historical Base Sepolia stack is refused at its PoolManager binding.
    function test_baseSepolia_rejectsHistoricalUniversalRouterBinding() public {
        _etchRouter(HISTORICAL_POOL_MANAGER, HISTORICAL_POSITION_MANAGER, true);

        _expectBindingMismatch(UNIVERSAL_ROUTER, POOL_MANAGER_GETTER, POOL_MANAGER, HISTORICAL_POOL_MANAGER);
        helperConfig.getNetworkConfig();
    }

    /// @notice A router bound to the frozen PoolManager but another PositionManager is refused.
    function test_baseSepolia_rejectsUniversalRouterPositionManagerMismatch() public {
        _etchRouter(POOL_MANAGER, HISTORICAL_POSITION_MANAGER, true);

        _expectBindingMismatch(
            UNIVERSAL_ROUTER, V4_POSITION_MANAGER_GETTER, POSITION_MANAGER, HISTORICAL_POSITION_MANAGER
        );
        helperConfig.getPublicPeripheryConfig();
    }

    /// @notice A PositionManager bound to another PoolManager is refused.
    function test_baseSepolia_rejectsPositionManagerPoolManagerMismatch() public {
        _etchPositionManager(HISTORICAL_POOL_MANAGER, PERMIT2, true);

        _expectBindingMismatch(POSITION_MANAGER, POOL_MANAGER_GETTER, POOL_MANAGER, HISTORICAL_POOL_MANAGER);
        helperConfig.getNetworkConfig();
    }

    /// @notice A PositionManager pulling payment through another Permit2 is refused.
    function test_baseSepolia_rejectsPositionManagerPermit2Mismatch() public {
        address otherPermit2 = makeAddr("otherPermit2");

        _etchPositionManager(POOL_MANAGER, otherPermit2, true);

        _expectBindingMismatch(POSITION_MANAGER, PERMIT2_GETTER, PERMIT2, otherPermit2);
        helperConfig.getNetworkConfig();
    }

    /// @notice A router that does not expose its binding at all is refused rather than trusted.
    function test_baseSepolia_rejectsUnreadableUniversalRouterBinding() public {
        vm.etch(UNIVERSAL_ROUTER, address(new InfrastructureCodeStub()).code);

        _expectBindingMismatch(UNIVERSAL_ROUTER, POOL_MANAGER_GETTER, POOL_MANAGER, address(0));
        helperConfig.getNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                       ACTOR ATTRIBUTION SURFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice A router without a readable `msgSender()` surface is refused.
    function test_baseSepolia_rejectsUniversalRouterWithoutActorSurface() public {
        _etchRouter(POOL_MANAGER, POSITION_MANAGER, false);

        vm.expectRevert(
            abi.encodeWithSelector(HelperConfig.HelperConfig__MissingActorAttributionSurface.selector, UNIVERSAL_ROUTER)
        );
        helperConfig.getNetworkConfig();
    }

    /// @notice A PositionManager without a readable `msgSender()` surface is refused.
    function test_baseSepolia_rejectsPositionManagerWithoutActorSurface() public {
        _etchPositionManager(POOL_MANAGER, PERMIT2, false);

        vm.expectRevert(
            abi.encodeWithSelector(HelperConfig.HelperConfig__MissingActorAttributionSurface.selector, POSITION_MANAGER)
        );
        helperConfig.getNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                           ROLE ACCOUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role derivation is deterministic and gives seven distinct accounts, none of them the root account.
    function test_roleDerivation_isDeterministicAndKeepsRolesDistinct() public {
        BaseSepoliaRolesHarness roles = new BaseSepoliaRolesHarness();
        uint256 rootKey = uint256(keccak256("standby.test.rootKey"));

        StandbyActors memory actors = roles.baseSepoliaActors(rootKey);
        StandbyActors memory again = roles.baseSepoliaActors(rootKey);

        address[8] memory accounts = [
            actors.configurationAuthority,
            actors.establishmentAuthority,
            actors.registryAdmin,
            actors.liquidityProvider,
            actors.trader,
            actors.beneficiary,
            actors.exerciseAuthority,
            vm.addr(rootKey)
        ];

        for (uint256 i = 0; i < accounts.length; ++i) {
            assertTrue(accounts[i] != address(0), "role account must be nonzero");

            for (uint256 j = i + 1; j < accounts.length; ++j) {
                assertTrue(accounts[i] != accounts[j], "role accounts must be distinct from each other and the root");
            }
        }

        assertEq(keccak256(abi.encode(actors)), keccak256(abi.encode(again)), "derivation must be deterministic");
        assertEq(actors.trader, vm.addr(roles.deriveRoleKey(rootKey, "trader")), "role account must be its derived key");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _etchCompatibleTopology() internal {
        bytes memory code = address(new InfrastructureCodeStub()).code;

        vm.etch(POOL_MANAGER, code);
        vm.etch(PERMIT2, code);
        vm.etch(STATE_VIEW, code);
        vm.etch(QUOTER, code);

        _etchRouter(POOL_MANAGER, POSITION_MANAGER, true);
        _etchPositionManager(POOL_MANAGER, PERMIT2, true);
    }

    function _etchRouter(address _poolManager, address _positionManager, bool _actorSurface) internal {
        vm.etch(
            UNIVERSAL_ROUTER,
            address(new UniversalRouterBindingStub(_poolManager, _positionManager, _actorSurface)).code
        );
    }

    function _etchPositionManager(address _poolManager, address _permit2, bool _actorSurface) internal {
        vm.etch(POSITION_MANAGER, address(new PositionManagerBindingStub(_poolManager, _permit2, _actorSurface)).code);
    }

    function _expectBindingMismatch(address _component, bytes4 _binding, address _expected, address _actual) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                HelperConfig.HelperConfig__InfrastructureBindingMismatch.selector,
                _component,
                _binding,
                _expected,
                _actual
            )
        );
    }
}
