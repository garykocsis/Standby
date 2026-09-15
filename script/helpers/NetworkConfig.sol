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

/// @notice The official public Uniswap v4 periphery a public-network Standby realization integrates with.
/// @dev Infrastructure only, and only for public networks. The deterministic local environment has no official
///      periphery: its trusted perimeters are deployed by the environment composition itself, so no value of
///      this type exists for it. Like `NetworkConfig`, it carries no Standby economic fixture or service
///      semantics; which of these contracts a Hook trusts is decided by the Hook's own immutable bindings.
/// @param universalRouter The official Universal Router, the trusted ordinary-swap perimeter.
/// @param positionManager The official v4 PositionManager, the trusted liquidity perimeter.
/// @param permit2 The Permit2 contract both official perimeters pull payment through.
/// @param stateView The official v4 StateView lens.
/// @param quoter The official v4 Quoter.
struct PublicPeripheryConfig {
    address universalRouter;
    address positionManager;
    address permit2;
    address stateView;
    address quoter;
}
