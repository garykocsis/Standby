// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";
import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../../src/demo/ActorAwareTestRouter.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockUSTB} from "../../src/mocks/MockUSTB.sol";

/*//////////////////////////////////////////////////////////////
                        TYPE DECLARATIONS
//////////////////////////////////////////////////////////////*/

/// @notice The complete address manifest of one deployed Standby environment.
/// @dev Deployment output only. This type records which contracts exist; it records no Standby economic
///      state, no service configuration, and no commitment. Every economic fact about the system these
///      addresses form is owned by the deployed contracts themselves and must be read from them.
/// @param poolManager The real Uniswap v4 PoolManager the environment was deployed against.
/// @param ustb The deterministic fixture currency deployed as `currency0`.
/// @param usdc The deterministic fixture currency deployed as `currency1`.
/// @param registry The EligibilityRegistry the service consumes.
/// @param swapPerimeter The trusted ordinary-swap perimeter the Hook was deployed against.
/// @param liquidityPerimeter The trusted liquidity perimeter the Hook was deployed against.
/// @param hook The StandbyHook deployed by the canonical deployment procedure.
/// @param exerciseRouter The O2 coordinator bound to that Hook.
struct StandbyEnvironment {
    IPoolManager poolManager;
    MockUSTB ustb;
    MockUSDC usdc;
    EligibilityRegistry registry;
    ActorAwareTestRouter swapPerimeter;
    ActorAwareTestRouter liquidityPerimeter;
    StandbyHook hook;
    ExerciseRouter exerciseRouter;
}

/// @notice The accounts one bootstrapped Standby environment assigns its distinct roles to.
/// @dev Every role is a separate account. Collapsing two of them would make a later observation
///      ambiguous — a delivery that landed with the payer, or an activation that succeeded because the
///      caller happened to hold a second authority — so the manifest keeps them apart by construction.
///
///      These are bootstrap inputs, not Standby authority. Authority is established by the deployed
///      contracts: the Hook's immutable configuration authority, the service's establishment authority,
///      the registry's administrator, and each commitment's own exercise authority.
/// @param configurationAuthority The only account authorized to activate the Hook's service.
/// @param establishmentAuthority The account the activated service admits commitments through.
/// @param registryAdmin The EligibilityRegistry administrator.
/// @param liquidityProvider The account that provides the canonical controlled liquidity.
/// @param trader The ordinary eligible trader.
/// @param beneficiary The account for whose benefit protected execution is delivered.
/// @param exerciseAuthority The account a commitment authorizes to exercise it.
struct StandbyActors {
    address configurationAuthority;
    address establishmentAuthority;
    address registryAdmin;
    address liquidityProvider;
    address trader;
    address beneficiary;
    address exerciseAuthority;
}
