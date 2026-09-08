// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Exposes internal Standby mechanics that no production path can reach for isolated unit and
///         fuzz verification.
/// @dev The mechanics under test are internal by design: F4 owns the storage primitives that commitment
///      admission and fulfillment will later drive, and it deliberately introduces no production path
///      that reaches them. F8A adds one more of the same kind — the claim of the single O2 authorization
///      slot, which no production caller can hold open on its own. F8B adds three: writing a causal context
///      into a position production reaches only mid-swap, and driving the two O2 causal mechanics with
///      facts the real PoolManager would never produce. Without these exposures the primitives could not be
///      verified at all before the slices that consume them exist, which would invert the
///      verification-gated dependency rule.
///
///      Every function here is a bare pass-through. The harness declares no state of its own, adds no
///      check, removes no check, and re-implements nothing: the allocation, the record write, the
///      Remaining Entitlement write, the existence predicate, and the reference write are all the
///      production implementations running against production storage.
///
///      What the harness does supply is authority, and only authority. A commitment it records is not an
///      authentic Standby commitment: nothing authenticated it, nothing validated its terms, and nothing
///      established that it is backed. Harness-recorded state is valid evidence about the storage
///      primitive and about nothing else, and must never be presented as evidence for admission,
///      enforcement, integration, invariant, periphery, or acceptance behavior.
contract StandbyHookHarness is StandbyHook {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the harness with the same immutable trust basis as the production Hook.
    /// @param _poolManager The PoolManager whose callbacks this Hook answers.
    /// @param _configurationAuthority The only account authorized to activate the service.
    /// @param _trustedUniversalRouter The trusted ordinary-swap perimeter.
    /// @param _trustedPositionManager The trusted liquidity perimeter.
    constructor(
        IPoolManager _poolManager,
        address _configurationAuthority,
        address _trustedUniversalRouter,
        address _trustedPositionManager
    ) StandbyHook(_poolManager, _configurationAuthority, _trustedUniversalRouter, _trustedPositionManager) {}

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Runs the production commitment-record mechanic.
    /// @param _commitment The commitment facts to record.
    /// @return commitmentId The identity the production mechanic allocated.
    function recordCommitment(Commitment memory _commitment) external returns (uint256 commitmentId) {
        commitmentId = _recordCommitment(_commitment);
    }

    /// @notice Runs the production Remaining Entitlement write mechanic.
    /// @param _commitmentId The identity whose Remaining Entitlement is written.
    /// @param _remainingEntitlement The Remaining Entitlement after this write.
    function writeRemainingEntitlement(uint256 _commitmentId, uint128 _remainingEntitlement) external {
        _writeRemainingEntitlement(_commitmentId, _remainingEntitlement);
    }

    /// @notice Runs the production bounded enforcement-reference write mechanic.
    /// @param _slot The slot to write, within the bounded index.
    /// @param _commitmentId The existing commitment identity to reference.
    function writeEnforcementReference(uint256 _slot, uint256 _commitmentId) external {
        _writeEnforcementReference(_slot, _commitmentId);
    }

    /// @notice Runs the production commitment-existence predicate.
    /// @param _commitmentId The identity to test.
    /// @return exists Whether the identity has been allocated.
    function commitmentExists(uint256 _commitmentId) external view returns (bool exists) {
        exists = _commitmentExists(_commitmentId);
    }

    /// @notice Runs the production claim of the single O2 authorization slot.
    /// @dev Exposed because production authorization claims the slot and reaches a terminal outcome inside
    ///      one call: every external read it performs before writing its result is a static call, so no
    ///      production caller can be executing while the slot is held in flight. That is the property worth
    ///      having, and it is exactly what makes the in-flight guard unobservable from production and
    ///      unverifiable without this pass-through.
    ///
    ///      It adds no check and removes none. What it supplies is the ability to hold the claim open
    ///      across a subsequent call, which is authority and nothing else: a slot claimed here is not an
    ///      authorization, nothing was authenticated, and no predicate was evaluated.
    function beginExerciseAuthorization() external {
        _beginExerciseAuthorization();
    }

    /// @notice Writes a complete transaction-scoped causal context directly.
    /// @dev Pure authority and nothing else: it authenticates nobody, evaluates no predicate, and asserts
    ///      nothing about backing. A context written here is not an authorization — it is a starting
    ///      position, and it exists so that the causal transitions guarding execution evidence can be
    ///      addressed one at a time.
    ///
    ///      That is otherwise impossible. `EXECUTING` is reachable in production only from inside a
    ///      PoolManager swap the Hook has already accepted, which is precisely the situation in which the
    ///      evidence about to arrive cannot be malformed — the real PoolManager will not hand a Hook a
    ///      delta for a swap that did not happen. Verifying that malformed evidence is refused therefore
    ///      requires putting the context in that position without a real swap behind it.
    /// @param _context The causal context to write.
    function writeExerciseAuthorization(ExerciseAuthorizationContext memory _context) external {
        _writeExerciseAuthorization(_context);
    }

    /// @notice Runs the production O2 execution-classification mechanic.
    /// @dev A bare pass-through of the `beforeSwap` O2 branch: it adds no check, removes none, and reaches
    ///      the same production causal transition. What it supplies is the ability to present a proposed
    ///      swap without the PoolManager having proposed it.
    /// @param _sender The account presented as the PoolManager operation sender.
    /// @param _params The proposed swap.
    function beginProtectedExecution(address _sender, SwapParams calldata _params) external {
        _beginProtectedExecution(_sender, _params);
    }

    /// @notice Runs the production O2 execution-evidence mechanic.
    /// @dev A bare pass-through of the `afterSwap` O2 branch, against production causal state. The delta it
    ///      is handed is supplied rather than produced by a real swap, which is the whole point: the
    ///      production path can only ever be handed an authentic PoolManager delta, so the refusal of an
    ///      inauthentic one is verifiable only here.
    /// @param _sender The account presented as the PoolManager operation sender.
    /// @param _key The pool the evidence claims to concern.
    /// @param _params The swap the evidence claims to concern.
    /// @param _delta The balance delta presented as execution evidence.
    function recordProtectedExecution(
        address _sender,
        PoolKey calldata _key,
        SwapParams calldata _params,
        BalanceDelta _delta
    ) external {
        _recordProtectedExecution(_sender, _key, _params, _delta);
    }
}
