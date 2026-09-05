// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Script} from "forge-std/Script.sol";

import {PoolManager} from "v4-core/PoolManager.sol";

import {NetworkConfig} from "./NetworkConfig.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title HelperConfig
/// @notice Resolves the Uniswap v4 infrastructure Standby deploys against on the active chain.
/// @dev Chain/infrastructure selection only. This contract must not resolve, hold, or imply any
///      Standby economic fixture or service configuration.
contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain id of the deterministic local Foundry/Anvil environment.
    uint256 public constant ANVIL_CHAIN_ID = 31_337;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when no validated Uniswap v4 infrastructure is configured for the active chain.
    /// @param chainId The unsupported chain id.
    error HelperConfig__UnsupportedNetwork(uint256 chainId);

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Resolves the Uniswap v4 infrastructure configuration for the active chain.
    /// @dev On the deterministic local environment a real PoolManager is deployed. Public chains are
    ///      rejected until their deployed v4 infrastructure addresses have been validated for Standby.
    /// @return config The resolved infrastructure configuration.
    function getNetworkConfig() public returns (NetworkConfig memory config) {
        if (block.chainid != ANVIL_CHAIN_ID) revert HelperConfig__UnsupportedNetwork(block.chainid);

        config = _deployLocalInfrastructure();
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
}
