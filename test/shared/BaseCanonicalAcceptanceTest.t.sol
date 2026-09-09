// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {BootstrapStandby} from "../../script/BootstrapStandby.s.sol";
import {DeployDemoEnvironment} from "../../script/DeployDemoEnvironment.s.sol";
import {NetworkConfig} from "../../script/helpers/NetworkConfig.sol";
import {StandbyActors, StandbyEnvironment} from "../../script/helpers/StandbyEnvironment.sol";
import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {ReferenceCalculations} from "./ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Fresh-construction fixture for F9 canonical acceptance evidence.
/// @dev This fixture builds nothing itself. It has exactly one operation — construct a complete Standby
///      system starting from an empty chain — and it performs it by calling the same deterministic
///      deployment and bootstrap implementation an operator would run: infrastructure resolution through
///      `HelperConfig`, environment composition through `DeployDemoEnvironment`, and the canonical
///      pre-A1 state through `BootstrapStandby`. Nothing is duplicated here, nothing is shelled out to,
///      and no persisted broadcast artifact is consulted.
///
///      It is deliberately not built on the F3–F8D fixture chain. Those fixtures compose the same system
///      inline in `setUp()`, and the ones acceptance would otherwise be tempted to reuse arrive with a
///      commitment already admitted and backing already established. Acceptance has to show that the
///      production system can reach its own starting state, so the only economic facts that may exist
///      here are the ones real deployment, real configuration, and real production transitions produced.
///
///      Nothing in this file writes economic state. There is no `vm.store`, no harness, no test-only
///      setter, no pre-created commitment, and no seeded capacity, obligation, entitlement, or reference.
///
///      Construction is a callable function rather than only a `setUp()` body, because the determinism
///      claim requires a second, completely independent system to be built inside a test and compared
///      against the first.
abstract contract BaseCanonicalAcceptanceTest is Test {
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice One completely constructed Standby system, as its own construction path reported it.
    /// @param environment The deployed address manifest.
    /// @param actors The accounts holding the environment's distinct roles.
    /// @param networkConfig The infrastructure configuration the environment was deployed against.
    /// @param poolKey The canonical Hook-bound PoolKey the service was activated over.
    /// @param serviceId The identity of the activated Protected Execution Service.
    struct CanonicalSystem {
        StandbyEnvironment environment;
        StandbyActors actors;
        NetworkConfig networkConfig;
        PoolKey poolKey;
        PoolId serviceId;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A realistic starting time. Foundry starts at timestamp 1, where a commitment window that has
    ///      already opened is barely expressible; the canonical sequence exercises one, so the clock is
    ///      moved to a plausible point first. The value is a fixed constant, so the acceptance result
    ///      depends on no wall-clock reading.
    uint256 internal constant CANONICAL_TIMESTAMP = 1_800_000_000;

    /// @dev The validity duration the canonical admitted commitment carries.
    uint64 internal constant CANONICAL_VALIDITY_DURATION = 30 days;

    /// @dev The system every acceptance suite in this repository starts from: constructed fresh, in
    ///      `setUp`, through the production deployment and bootstrap path and nothing else.
    CanonicalSystem internal canonical;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructs one complete Standby system from an empty chain.
    function setUp() public virtual {
        vm.warp(CANONICAL_TIMESTAMP);

        canonical = _constructCanonicalSystem("canonical");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a complete Standby system through the canonical deterministic construction path.
    ///
    ///      Every account is namespaced, so two systems built in the same test share no role, no balance,
    ///      and no eligibility. Nothing about the second construction can therefore be inherited from the
    ///      first.
    ///
    ///      The environment script is created from its compiled artifact rather than with `new`, because
    ///      a fixture that created it inline would carry the script's whole creation code — the Hook's
    ///      included — inside its own, past the init-code limit. It is the same compiled script an
    ///      operator runs; nothing about the construction it performs changes.
    function _constructCanonicalSystem(string memory _namespace) internal returns (CanonicalSystem memory system) {
        system.actors = _canonicalActors(_namespace);

        DeployDemoEnvironment environmentDeployer =
            DeployDemoEnvironment(vm.deployCode("DeployDemoEnvironment.s.sol:DeployDemoEnvironment"));

        (system.environment, system.networkConfig) = environmentDeployer.resolveAndDeployEnvironment(
            system.actors.configurationAuthority, system.actors.registryAdmin
        );

        BootstrapStandby bootstrapper = new BootstrapStandby();

        (system.poolKey, system.serviceId) = bootstrapper.bootstrapStandby(system.environment, system.actors);
    }

    /// @dev Assigns every role of one system its own distinct account.
    function _canonicalActors(string memory _namespace) internal returns (StandbyActors memory actors) {
        actors = StandbyActors({
            configurationAuthority: makeAddr(string.concat(_namespace, ".configurationAuthority")),
            establishmentAuthority: makeAddr(string.concat(_namespace, ".establishmentAuthority")),
            registryAdmin: makeAddr(string.concat(_namespace, ".registryAdmin")),
            liquidityProvider: makeAddr(string.concat(_namespace, ".liquidityProvider")),
            trader: makeAddr(string.concat(_namespace, ".trader")),
            beneficiary: makeAddr(string.concat(_namespace, ".beneficiary")),
            exerciseAuthority: makeAddr(string.concat(_namespace, ".exerciseAuthority"))
        });
    }

    /// @dev Reads the authoritative square-root price, tick, and active liquidity of a system's pool.
    function _poolState(CanonicalSystem memory _system)
        internal
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint128 liquidity)
    {
        (sqrtPriceX96, tick,,) = _system.environment.poolManager.getSlot0(_system.serviceId);

        liquidity = _system.environment.poolManager.getLiquidity(_system.serviceId);
    }

    /// @dev Builds the canonical ordinary protected-direction exact-output swap of a given quantity.
    ///
    ///      The price limit is the protected boundary, so a request larger than the domain can serve stops
    ///      exactly on `tickQ` instead of leaving the configured realization domain. A refusal is then
    ///      attributable to backing rather than to a domain violation.
    function _protectedExactOutputSwapParams(uint256 _amountOut) internal pure returns (SwapParams memory params) {
        params = SwapParams({
            zeroForOne: StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            amountSpecified: int256(_amountOut),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q)
        });
    }

    /// @dev Independently derives a system's Supporting Capacity from authoritative PoolManager state.
    ///
    ///      A verification oracle, never protocol truth: it recomputes the quantity from the pool state
    ///      the PoolManager actually holds and never asks the Hook what it thinks that quantity is.
    function _referenceSupportingCapacity(CanonicalSystem memory _system) internal view returns (uint256 capacity) {
        (uint160 sqrtPriceX96,, uint128 liquidity) = _poolState(_system);

        capacity = ReferenceCalculations.referenceSupportingCapacity(
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE, sqrtPriceX96, StandbyFixtureConfig.TICK_Q, liquidity
        );
    }

    /// @dev Independently derives a system's Aggregate Capacity Obligation from persisted commitment facts.
    ///
    ///      Only facts cross the boundary — each referenced commitment's Remaining Entitlement and validity
    ///      end, read through the fact-only commitment surface — and the oracle re-derives every
    ///      classification itself.
    function _referenceAggregateObligation(CanonicalSystem memory _system) internal view returns (uint256 obligation) {
        StandbyHook hook = _system.environment.hook;

        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        uint256 referenced;

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            if (references[slot] != 0) ++referenced;
        }

        uint128[] memory remainingEntitlements = new uint128[](referenced);
        uint64[] memory validUntils = new uint64[](referenced);

        uint256 next;

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            if (references[slot] == 0) continue;

            StandbyHook.Commitment memory record = hook.commitment(references[slot]);

            remainingEntitlements[next] = record.remainingEntitlement;
            validUntils[next] = record.validUntil;

            ++next;
        }

        obligation =
            ReferenceCalculations.referenceAggregateObligation(remainingEntitlements, validUntils, block.timestamp);
    }

    /// @dev Proves both production economic derivations still equal their independent reconstructions.
    function _assertDerivationsMatchOracles(CanonicalSystem memory _system, string memory _context) internal view {
        assertEq(_system.environment.hook.supportingCapacity(), _referenceSupportingCapacity(_system), _context);
        assertEq(_system.environment.hook.aggregateObligation(), _referenceAggregateObligation(_system), _context);
    }

    /// @dev Counts the bounded enforcement-reference slots currently holding a reference.
    function _occupiedReferenceCount(CanonicalSystem memory _system) internal view returns (uint256 occupied) {
        uint256[MAX_LIVE_COMMITMENTS] memory references = _system.environment.hook.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            if (references[slot] != 0) ++occupied;
        }
    }

    /// @dev Expects the revert Uniswap produces when a Standby Hook callback rejects a transition.
    ///
    ///      A failed hook call is wrapped by the pinned `Hooks` library rather than bubbled raw, so the
    ///      expectation names the wrapper, the Hook, the callback, and the Standby reason inside it.
    ///      Matching only the wrapper would accept any rejection at all.
    function _expectHookRejection(CanonicalSystem memory _system, bytes4 _callbackSelector, bytes memory _reason)
        internal
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(_system.environment.hook),
                _callbackSelector,
                _reason,
                abi.encodePacked(Hooks.HookCallFailed.selector)
            )
        );
    }
}
