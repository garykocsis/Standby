// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                        TYPE DECLARATIONS
//////////////////////////////////////////////////////////////*/

/// @notice Infrastructure configuration required to deploy Standby onto a target network.
/// @dev Infrastructure only. This type must never carry Standby economic fixture or service
///      semantics (currencies, service boundaries, capacity, commitments, eligibility,
///      protected direction). Those belong to later implementation slices.
/// @param chainId The chain the resolved infrastructure belongs to.
/// @param poolManager The authoritative Uniswap v4 PoolManager for that chain.
struct NetworkConfig {
    uint256 chainId;
    address poolManager;
}
