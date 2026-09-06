// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Exposes the internal F4 commitment-storage and bounded-reference mechanics for isolated
///         unit and fuzz verification.
/// @dev The mechanics under test are internal by design: F4 owns the storage primitives that commitment
///      admission and fulfillment will later drive, and it deliberately introduces no production path
///      that reaches them. Without this exposure the primitives could not be verified at all before the
///      slices that consume them exist, which would invert the verification-gated dependency rule.
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
}
