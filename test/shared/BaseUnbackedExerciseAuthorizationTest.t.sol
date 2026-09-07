// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {StandbyHookHarness} from "../harness/StandbyHookHarness.sol";
import {BaseExerciseAuthorizationTest} from "./BaseExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared harness fixture for the F8A behavior that no production-reachable state can exhibit.
/// @dev Two F8A requirements are about what authorization does when its preconditions are *not* met, and
///      the reachable system cannot produce either situation. That is a property of the protocol working,
///      not a gap in it, and it is exactly the case harness isolation exists for.
///
///      The first is insufficient prospective exercise backing. Inside the canonical single-interval
///      geometry an exact-output exercise of `q` leaves `S - q`, and a complete successful exercise leaves
///      `O - q`, so `S' >= O - q` reduces to `S >= O` — the invariant O1 and O3 already maintain on every
///      authoritative transition. No sequence of production transitions can therefore reach a state in
///      which the F8A backing comparison fails, and the requirement is nonetheless a requirement.
///
///      The second is the in-flight authorization guard. Every external read production authorization
///      performs before writing its result is a static call, so no production caller can be executing while
///      the authorization slot is held in flight.
///
///      This fixture is the ordinary F8A fixture with one substitution: the Hook the service is activated
///      on is a `StandbyHookHarness` instead of the production Hook. Everything else is unchanged and
///      authentic — the real PoolManager, the real pool, the production activation, the canonical liquidity
///      through the production liquidity path, the real registry, the real ExerciseRouter, and commitments
///      created only by the production O1 transition. The harness contributes exactly two abilities the
///      production surface lacks: writing a commitment's Remaining Entitlement directly, and holding the
///      authorization slot open across a call.
///
///      What that buys is unbacked state, reached by inflating an authentic commitment's Remaining
///      Entitlement past what the pool can support. It is not an admitted commitment term and was never
///      backed by anything, so it is valid evidence about the backing comparison and about nothing else. No
///      integration, invariant, periphery, or acceptance claim may rest on it.
abstract contract BaseUnbackedExerciseAuthorizationTest is BaseExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The same Hook as `hook`, typed so the harness-only mechanics are reachable.
    StandbyHookHarness internal serviceHarness;

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mines and deploys the harness Hook at an address encoding the required permission bits.
    ///
    ///      The same mask the canonical deployment procedure mines against, so the harness is a real
    ///      Uniswap v4 Hook whose address the PoolManager accepts, not an address-unconstrained stand-in.
    function _deployServiceHook() internal override returns (StandbyHook deployed) {
        bytes memory constructorArgs =
            abi.encode(poolManager, configurationAuthority, address(swapPerimeter), address(liquidityPerimeter));

        (, bytes32 salt) = HookMiner.find(
            address(this),
            hookDeployer.REQUIRED_HOOK_PERMISSION_MASK(),
            type(StandbyHookHarness).creationCode,
            constructorArgs
        );

        serviceHarness = new StandbyHookHarness{salt: salt}(
            poolManager, configurationAuthority, address(swapPerimeter), address(liquidityPerimeter)
        );

        deployed = serviceHarness;
    }

    /// @dev Rewrites an authentic commitment's Remaining Entitlement to a value admission would refuse.
    ///
    ///      The commitment itself was admitted by the production transition and every other fact about it
    ///      is authentic; only this remainder is harness-written, and it is written precisely because
    ///      admission would never have permitted it. Whether the result is backed is the test's own claim to
    ///      state, not this helper's to assume.
    function _writeRemainingEntitlement(uint256 _commitmentId, uint128 _remainingEntitlement) internal {
        serviceHarness.writeRemainingEntitlement(_commitmentId, _remainingEntitlement);
    }
}
