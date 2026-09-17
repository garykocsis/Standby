// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Script} from "forge-std/Script.sol";

import {PoolManager} from "v4-core/PoolManager.sol";

import {IImmutableState} from "v4-periphery/src/interfaces/IImmutableState.sol";
import {IMsgSender} from "v4-periphery/src/interfaces/IMsgSender.sol";

import {NetworkConfig, PublicPeripheryConfig} from "./NetworkConfig.sol";
import {IPublicPeripheryBindings} from "./PublicPeriphery.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title HelperConfig
/// @notice Resolves the Uniswap v4 infrastructure Standby deploys against on the active chain.
/// @dev Chain/infrastructure selection only. This contract must not resolve, hold, or imply any
///      Standby economic fixture or service configuration.
///
///      Two environments are supported. The deterministic local environment deploys a real pinned PoolManager.
///      Base Sepolia resolves the frozen official Uniswap v4 deployment, and only after validating that the
///      addresses hold code and are bound to one another as one mutually compatible stack — so a stale,
///      historical, or mismatched deployment is refused here rather than silently trusted by a Hook.
contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain id of the deterministic local Foundry/Anvil environment.
    uint256 public constant ANVIL_CHAIN_ID = 31_337;

    /// @notice Chain id of Base Sepolia, the supplementary public-testnet environment.
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84_532;

    /// @notice The official Base Sepolia Uniswap v4 PoolManager.
    address public constant BASE_SEPOLIA_POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;

    /// @notice The official Base Sepolia Universal Router bound to that PoolManager.
    address public constant BASE_SEPOLIA_UNIVERSAL_ROUTER = 0x492E6456D9528771018DeB9E87ef7750EF184104;

    /// @notice The official Base Sepolia v4 PositionManager bound to that PoolManager.
    address public constant BASE_SEPOLIA_POSITION_MANAGER = 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80;

    /// @notice The canonical Permit2 deployment.
    address public constant BASE_SEPOLIA_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /// @notice The official Base Sepolia v4 StateView.
    address public constant BASE_SEPOLIA_STATE_VIEW = 0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4;

    /// @notice The official Base Sepolia v4 Quoter.
    address public constant BASE_SEPOLIA_V4_QUOTER = 0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when no validated Uniswap v4 infrastructure is configured for the active chain.
    /// @param chainId The unsupported chain id.
    error HelperConfig__UnsupportedNetwork(uint256 chainId);

    /// @notice Thrown when a required infrastructure address holds no code.
    /// @param component The address expected to hold a deployed contract.
    error HelperConfig__MissingInfrastructureCode(address component);

    /// @notice Thrown when an infrastructure contract is not bound to the expected counterpart.
    /// @param component The contract whose binding was read.
    /// @param binding The selector of the binding getter.
    /// @param expected The counterpart the frozen topology requires.
    /// @param actual The counterpart actually reported, or zero when the binding could not be read.
    error HelperConfig__InfrastructureBindingMismatch(
        address component, bytes4 binding, address expected, address actual
    );

    /// @notice Thrown when a periphery contract does not expose the authenticated-originator surface.
    /// @param periphery The periphery contract lacking a readable `msgSender()`.
    error HelperConfig__MissingActorAttributionSurface(address periphery);

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Resolves the Uniswap v4 infrastructure configuration for the active chain.
    /// @dev On the deterministic local environment a real PoolManager is deployed. On Base Sepolia the frozen
    ///      official PoolManager is returned after the whole external stack has been validated. Every other
    ///      chain is rejected rather than guessed.
    /// @return config The resolved infrastructure configuration.
    function getNetworkConfig() public returns (NetworkConfig memory config) {
        if (block.chainid == ANVIL_CHAIN_ID) {
            config = _deployLocalInfrastructure();
        } else if (block.chainid == BASE_SEPOLIA_CHAIN_ID) {
            validateBaseSepoliaInfrastructure();

            config = NetworkConfig({chainId: block.chainid, poolManager: BASE_SEPOLIA_POOL_MANAGER});
        } else {
            revert HelperConfig__UnsupportedNetwork(block.chainid);
        }
    }

    /// @notice Resolves the official public Uniswap v4 periphery for the active chain.
    /// @dev Only public networks have official periphery. The deterministic local environment is rejected: its
    ///      perimeters are composed by the environment itself and must never be mistaken for this.
    /// @return periphery The validated official periphery.
    function getPublicPeripheryConfig() public view returns (PublicPeripheryConfig memory periphery) {
        validateBaseSepoliaInfrastructure();

        periphery = PublicPeripheryConfig({
            universalRouter: BASE_SEPOLIA_UNIVERSAL_ROUTER,
            positionManager: BASE_SEPOLIA_POSITION_MANAGER,
            permit2: BASE_SEPOLIA_PERMIT2,
            stateView: BASE_SEPOLIA_STATE_VIEW,
            quoter: BASE_SEPOLIA_V4_QUOTER
        });
    }

    /// @notice Validates the frozen Base Sepolia Uniswap v4 topology against the live chain.
    /// @dev Preflight only; it establishes no Standby fact. It requires the chain to be Base Sepolia, every
    ///      frozen address to hold code, the Universal Router and PositionManager to be bound to the frozen
    ///      PoolManager, the Universal Router to be bound to the frozen PositionManager, the PositionManager to
    ///      pull payment through the frozen Permit2, and both trusted perimeters to expose a readable
    ///      `msgSender()`. A historical router bound to another PoolManager fails the first binding check.
    function validateBaseSepoliaInfrastructure() public view {
        if (block.chainid != BASE_SEPOLIA_CHAIN_ID) revert HelperConfig__UnsupportedNetwork(block.chainid);

        _requireCode(BASE_SEPOLIA_POOL_MANAGER);
        _requireCode(BASE_SEPOLIA_UNIVERSAL_ROUTER);
        _requireCode(BASE_SEPOLIA_POSITION_MANAGER);
        _requireCode(BASE_SEPOLIA_PERMIT2);
        _requireCode(BASE_SEPOLIA_STATE_VIEW);
        _requireCode(BASE_SEPOLIA_V4_QUOTER);

        _requireBinding(BASE_SEPOLIA_UNIVERSAL_ROUTER, IImmutableState.poolManager.selector, BASE_SEPOLIA_POOL_MANAGER);
        _requireBinding(
            BASE_SEPOLIA_UNIVERSAL_ROUTER,
            IPublicPeripheryBindings.V4_POSITION_MANAGER.selector,
            BASE_SEPOLIA_POSITION_MANAGER
        );
        _requireBinding(BASE_SEPOLIA_POSITION_MANAGER, IImmutableState.poolManager.selector, BASE_SEPOLIA_POOL_MANAGER);
        _requireBinding(BASE_SEPOLIA_POSITION_MANAGER, IPublicPeripheryBindings.permit2.selector, BASE_SEPOLIA_PERMIT2);

        _requireActorAttributionSurface(BASE_SEPOLIA_UNIVERSAL_ROUTER);
        _requireActorAttributionSurface(BASE_SEPOLIA_POSITION_MANAGER);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Deploys the real pinned Uniswap v4 PoolManager for the deterministic local environment.
    ///      The PoolManager is the real production contract, not a Standby-owned mock.
    function _deployLocalInfrastructure() internal returns (NetworkConfig memory config) {
        vm.startBroadcast();
        PoolManager poolManager = new PoolManager(msg.sender);
        vm.stopBroadcast();

        config = NetworkConfig({chainId: block.chainid, poolManager: address(poolManager)});
    }

    /// @dev Requires an infrastructure address to hold deployed code.
    function _requireCode(address _component) internal view {
        if (_component.code.length == 0) revert HelperConfig__MissingInfrastructureCode(_component);
    }

    /// @dev Requires an address-valued binding getter to report exactly the expected counterpart.
    ///
    ///      The getter is called with a static call and a returned value is accepted only when it is exactly
    ///      one ABI word, so a missing getter is reported as a mismatch against zero rather than as an opaque
    ///      revert.
    function _requireBinding(address _component, bytes4 _binding, address _expected) internal view {
        (bool success, bytes memory data) = _component.staticcall(abi.encodeWithSelector(_binding));

        address actual = success && data.length == 32 ? abi.decode(data, (address)) : address(0);

        if (actual != _expected) {
            revert HelperConfig__InfrastructureBindingMismatch(_component, _binding, _expected, actual);
        }
    }

    /// @dev Requires a periphery contract to answer `msgSender()` with one ABI word.
    ///
    ///      Outside a routed action the official periphery answers zero, which is the surface existing without
    ///      an originator. Whether it reports the authenticated originator during a routed action is proven by
    ///      the Hook admitting real routed actions, not by this preflight.
    function _requireActorAttributionSurface(address _periphery) internal view {
        (bool success, bytes memory data) = _periphery.staticcall(abi.encodeWithSelector(IMsgSender.msgSender.selector));

        if (!success || data.length != 32) revert HelperConfig__MissingActorAttributionSurface(_periphery);
    }
}
