// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseExerciseSettlementTest} from "./BaseExerciseSettlementTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared real-path fixture for F8D causal-finalization evidence.
/// @dev Built on the F8C fixture without altering it: the same real pinned `PoolManager`, the same
///      canonical `StandbyHook` deployment, the same F1 currencies, the same F2 registry under its own
///      administrator, the same production activation, the same canonical liquidity added through the
///      production `beforeAddLiquidity` path, the same production `establishCommitment` transition for
///      every commitment, and the same funded and approved exerciser. Nothing economic is seeded.
///
///      Exactly one thing differs, and it is the thing F8D is about: the configured ExerciseRouter is the
///      production `ExerciseRouter`. Every earlier exercise fixture configures a router with something
///      removed — the finalization request, the completion barrier, or the whole settlement stage — because
///      until finalization existed no production exercise could commit and the mechanics before it could
///      not otherwise be measured. Nothing is removed here. An exercise these suites request is authorized,
///      executed, settled, delivered, finalized, and committed by production code alone, which is the only
///      kind of exercise that can be evidence about durable fulfillment.
///
///      Roles stay separate throughout, as they do in every layer below: the exerciser is not the
///      Beneficiary, and neither is the router, the Hook, the establishment authority, the configuration
///      authority, a trader, a liquidity provider, or the registry administrator.
abstract contract BaseExerciseFinalizationTest is BaseExerciseSettlementTest {
    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Activates the service with the complete production ExerciseRouter.
    function _resolveExerciseRouter() internal virtual override returns (address router) {
        configuredExerciseRouter = new ExerciseRouter(hook);

        router = address(configuredExerciseRouter);
    }

    /// @dev Proves one completed exercise had exactly the fulfillment consequence it should have.
    ///
    ///      Four independent statements, and a wrong finalization would break them one at a time. The
    ///      remainder fell by exactly the exercised quantity; the admitted extent did not move at all; the
    ///      aggregate obligation released exactly what the remainder released, which is what it means for
    ///      the obligation to be derived from the remainder rather than accounted separately; and the
    ///      Beneficiary was paid exactly the quantity that was discharged, which is what makes the
    ///      fulfillment attributable to this exercise rather than to anything else that happened.
    function _assertExactFulfillment(
        SettlementState memory _before,
        address _exerciser,
        uint256 _commitmentId,
        uint256 _q
    ) internal view {
        SettlementState memory current = _settlementState(_exerciser, _commitmentId);

        assertEq(
            uint256(current.remainingEntitlement),
            uint256(_before.remainingEntitlement) - _q,
            "Remaining Entitlement must fall by exactly the exercised quantity"
        );
        assertEq(
            uint256(current.originalEntitlement),
            uint256(_before.originalEntitlement),
            "the admitted entitlement extent must never be rewritten"
        );
        assertEq(
            current.aggregateObligation,
            _before.aggregateObligation - _q,
            "the derived obligation must release exactly the fulfilled quantity"
        );
        assertEq(
            current.beneficiaryOutput - _before.beneficiaryOutput,
            _q,
            "the Beneficiary must have received exactly the quantity that was fulfilled"
        );
    }

    /// @dev Proves a transition fulfilled nothing at all.
    ///
    ///      The complement of `_assertExactFulfillment`, and the assertion every non-O2 path has to satisfy:
    ///      an ordinary swap, a direct transfer, a liquidity action, and a refused exercise all leave the
    ///      commitment exactly as they found it.
    function _assertNoFulfillment(
        SettlementState memory _before,
        address _exerciser,
        uint256 _commitmentId,
        string memory _context
    ) internal view {
        SettlementState memory current = _settlementState(_exerciser, _commitmentId);

        assertEq(uint256(current.remainingEntitlement), uint256(_before.remainingEntitlement), _context);
        assertEq(uint256(current.originalEntitlement), uint256(_before.originalEntitlement), _context);
        assertEq(current.aggregateObligation, _before.aggregateObligation, _context);
    }

    /// @dev Proves the bounded enforcement index still references a commitment, slot for slot.
    ///
    ///      Fulfillment does not clear a reference, and must not be made to: an exhausted commitment simply
    ///      contributes zero to the derived obligation, and its slot becomes reclaimable by the same
    ///      predicate that already governs reclamation.
    function _assertReferenceRetained(uint256 _commitmentId, uint256 _slot, string memory _context) internal view {
        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        assertEq(references[_slot], _commitmentId, _context);
    }

    /// @dev Reads the complete authoritative fact record of a commitment.
    function _commitmentRecord(uint256 _commitmentId) internal view returns (StandbyHook.Commitment memory record) {
        record = hook.commitment(_commitmentId);
    }
}
