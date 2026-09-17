// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {console2} from "forge-std/console2.sol";

import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";

import {MockFixtureCurrency} from "../../src/mocks/MockFixtureCurrency.sol";

import {BootstrapStandby} from "../BootstrapStandby.s.sol";
import {NetworkConfig, PublicPeripheryConfig} from "../helpers/NetworkConfig.sol";
import {IPermit2Allowance, PositionManagerCalldata} from "../helpers/PublicPeriphery.sol";
import {StandbyActors, StandbyEnvironment} from "../helpers/StandbyEnvironment.sol";
import {StandbyFixtureConfig} from "../helpers/StandbyFixtureConfig.sol";

import {BaseSepoliaScript} from "./BaseSepoliaScript.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title BootstrapBaseSepolia
/// @notice Supplementary post-submission (F9T) bootstrap of a Base Sepolia Standby environment to the
///         canonical commitment-free pre-A1 state, through the official public periphery.
/// @dev The canonical bootstrap, reused rather than restated. Pool initialization, the one-shot service
///      activation, eligibility seeding, and the closing fixture-fidelity checks are the inherited
///      `BootstrapStandby` procedures, called with the same arguments and in the same protocol-forced order.
///
///      Only the periphery-specific steps differ, because the perimeters differ. Payment to the official
///      Universal Router and PositionManager is pulled through Permit2, so the trader and liquidity provider
///      approve Permit2 and grant each perimeter a Permit2 allowance instead of approving a demo perimeter
///      directly. The canonical position is minted through the official PositionManager, whose authenticated
///      `msgSender()` is the provider — so the addition still passes through the Hook's production liquidity
///      enforcement. The exerciser keeps the accepted ExerciseRouter payment path: a plain ERC20 allowance.
///
///      Run with `--sig "bootstrapBaseSepolia()"`. The inherited `run()` is the local-environment entrypoint and
///      does not apply here.
contract BootstrapBaseSepolia is BootstrapStandby, BaseSepoliaScript {
    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Script entrypoint: bootstraps the deployed Base Sepolia environment named by the environment.
    /// @return poolKey The canonical Hook-bound PoolKey the service was activated over.
    /// @return serviceId The identity of the activated Protected Execution Service.
    function bootstrapBaseSepolia() external returns (PoolKey memory poolKey, PoolId serviceId) {
        (NetworkConfig memory config, PublicPeripheryConfig memory periphery) = _resolveBaseSepoliaInfrastructure();

        StandbyEnvironment memory environment = _baseSepoliaEnvironmentFromEnv(config);
        StandbyActors memory actors = _rememberBaseSepoliaActors();

        (poolKey, serviceId) = bootstrapWithPublicPeriphery(environment, periphery, actors);

        console2.log("Standby Supporting Capacity:", environment.hook.supportingCapacity());
        console2.log("Standby Capacity Obligation:", environment.hook.aggregateObligation());
        console2.log("Standby next commitment id:", environment.hook.nextCommitmentId());
        console2.logBytes32(PoolId.unwrap(serviceId));
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Brings a deployed Base Sepolia environment to the canonical commitment-free pre-A1 state.
    /// @dev Owns its broadcasts and must not be called from inside an open one.
    /// @param _environment The deployed address manifest.
    /// @param _periphery The validated official periphery.
    /// @param _actors The accounts holding the environment's distinct roles.
    /// @return poolKey The canonical Hook-bound PoolKey the service was activated over.
    /// @return serviceId The identity of the activated Protected Execution Service.
    function bootstrapWithPublicPeriphery(
        StandbyEnvironment memory _environment,
        PublicPeripheryConfig memory _periphery,
        StandbyActors memory _actors
    ) public returns (PoolKey memory poolKey, PoolId serviceId) {
        _requirePublicTopologyBindings(_environment, _periphery);

        _fundRoleGas(_actors);

        poolKey = canonicalPoolKey(_environment);

        _initializeCanonicalPool(_environment, poolKey);

        serviceId = _activateCanonicalService(_environment, _actors, poolKey);

        _seedCanonicalEligibility(_environment, _actors);
        _fundAndApproveThroughPermit2(_environment, _periphery, _actors);
        _addCanonicalLiquidityThroughPositionManager(_periphery, _actors, poolKey);

        _requireCanonicalBootstrapState(_environment, serviceId);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Funds the acting accounts exactly as the canonical bootstrap does, and grants public-periphery
    ///      approvals.
    ///
    ///      The same deliberate asymmetries hold: the exerciser holds only the input currency and approves only
    ///      the ExerciseRouter, and the Beneficiary is funded with nothing. The trader approves only the input
    ///      currency of the protected direction, which is all an ordinary exact-output swap in it pulls.
    function _fundAndApproveThroughPermit2(
        StandbyEnvironment memory _environment,
        PublicPeripheryConfig memory _periphery,
        StandbyActors memory _actors
    ) internal {
        vm.startBroadcast();

        _environment.ustb.mint(_actors.liquidityProvider, CANONICAL_ACTOR_FUNDING);
        _environment.usdc.mint(_actors.liquidityProvider, CANONICAL_ACTOR_FUNDING);

        _environment.ustb.mint(_actors.trader, CANONICAL_ACTOR_FUNDING);
        _environment.usdc.mint(_actors.trader, CANONICAL_ACTOR_FUNDING);

        _environment.ustb.mint(_actors.exerciseAuthority, CANONICAL_ACTOR_FUNDING);

        vm.stopBroadcast();

        _approveThroughPermit2(_actors.liquidityProvider, _environment.ustb, _periphery.positionManager, _periphery);
        _approveThroughPermit2(_actors.liquidityProvider, _environment.usdc, _periphery.positionManager, _periphery);

        _approveThroughPermit2(_actors.trader, _environment.ustb, _periphery.universalRouter, _periphery);

        vm.startBroadcast(_actors.exerciseAuthority);
        _environment.ustb.approve(address(_environment.exerciseRouter), type(uint256).max);
        vm.stopBroadcast();
    }

    /// @dev Grants one official perimeter an unlimited, non-expiring Permit2 allowance over one currency.
    function _approveThroughPermit2(
        address _owner,
        MockFixtureCurrency _currency,
        address _spender,
        PublicPeripheryConfig memory _periphery
    ) internal {
        vm.startBroadcast(_owner);

        _currency.approve(_periphery.permit2, type(uint256).max);
        IPermit2Allowance(_periphery.permit2).approve(address(_currency), _spender, type(uint160).max, type(uint48).max);

        vm.stopBroadcast();
    }

    /// @dev Mints the canonical controlled position through the official PositionManager as the provider.
    ///
    ///      The position is the canonical one: the canonical range, exactly the canonical liquidity, and the
    ///      provider's own funding as its payment bound. It spans the complete service domain with both endpoints
    ///      outside it.
    function _addCanonicalLiquidityThroughPositionManager(
        PublicPeripheryConfig memory _periphery,
        StandbyActors memory _actors,
        PoolKey memory _poolKey
    ) internal {
        bytes memory unlockData = PositionManagerCalldata.mintPosition(
            _poolKey,
            StandbyFixtureConfig.LP_TICK_LOWER,
            StandbyFixtureConfig.LP_TICK_UPPER,
            StandbyFixtureConfig.CANONICAL_LIQUIDITY,
            uint128(CANONICAL_ACTOR_FUNDING),
            uint128(CANONICAL_ACTOR_FUNDING),
            _actors.liquidityProvider
        );

        uint256 deadline = block.timestamp + PERIPHERY_DEADLINE_WINDOW;

        vm.startBroadcast(_actors.liquidityProvider);

        IPositionManager(_periphery.positionManager).modifyLiquidities(unlockData, deadline);

        vm.stopBroadcast();
    }
}
