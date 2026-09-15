// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title InfrastructureCodeStub
/// @notice Code with no binding getters, placed at a frozen infrastructure address in unit tests.
/// @dev Test-only. It stands in for an external contract whose presence, not behavior, is being checked, and for
///      a contract that does not expose a required binding getter.
contract InfrastructureCodeStub {}

/// @title UniversalRouterBindingStub
/// @notice The binding surface of a Universal Router, with configurable counterparts, for preflight unit tests.
/// @dev Test-only, and never Standby economic evidence. Its values are immutables so that its runtime code carries
///      them when etched at the frozen router address.
contract UniversalRouterBindingStub {
    address public immutable poolManager;
    address public immutable V4_POSITION_MANAGER;
    bool internal immutable i_exposesActorSurface;

    constructor(address _poolManager, address _positionManager, bool _exposesActorSurface) {
        poolManager = _poolManager;
        V4_POSITION_MANAGER = _positionManager;
        i_exposesActorSurface = _exposesActorSurface;
    }

    function msgSender() external view returns (address) {
        require(i_exposesActorSurface);
        return address(0);
    }
}

/// @title PositionManagerBindingStub
/// @notice The binding surface of a v4 PositionManager, with configurable counterparts, for preflight unit tests.
/// @dev Test-only, and never Standby economic evidence.
contract PositionManagerBindingStub {
    address public immutable poolManager;
    address public immutable permit2;
    bool internal immutable i_exposesActorSurface;

    constructor(address _poolManager, address _permit2, bool _exposesActorSurface) {
        poolManager = _poolManager;
        permit2 = _permit2;
        i_exposesActorSurface = _exposesActorSurface;
    }

    function msgSender() external view returns (address) {
        require(i_exposesActorSurface);
        return address(0);
    }
}
