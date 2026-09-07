// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {PoolId} from "v4-core/types/PoolId.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseCommitmentStorageTest} from "../shared/BaseCommitmentStorageTest.t.sol";
import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Fuzz evidence for the F5 Aggregate Capacity Obligation derivation (G5-A).
/// @dev Each run builds a bounded set of commitments with fuzzed remainders and validity ends, places
///      each one in a fuzzed slot of the enforcement-reference index, and compares the Hook's derived
///      aggregate against the independently composed reference over the same facts.
///
///      The slots are chosen by the fuzzer rather than filled in order, so a derivation that depended on
///      contiguity, on starting at slot zero, or on stopping at the first empty slot would be found. The
///      commitments themselves are arbitrary recorded facts: nothing admitted them, and they are evidence
///      about the derivation only.
contract AggregateObligationFuzzTest is BaseCommitmentStorageTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The largest referenced set a run builds. Below the bounded index size, so runs also exercise
    ///      partially occupied indexes.
    uint256 internal constant MAX_FUZZED_REFERENCES = 8;

    /*//////////////////////////////////////////////////////////////
                            FUZZ EVIDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the derived aggregate equals the independent reference over the same facts.
    function testFuzz_aggregateObligation_equalsIndependentReference(
        uint128[MAX_FUZZED_REFERENCES] memory _remainders,
        uint64[MAX_FUZZED_REFERENCES] memory _validUntils,
        uint8[MAX_FUZZED_REFERENCES] memory _slotSeeds,
        uint256 _countSeed,
        uint64 _timestamp
    ) public {
        vm.warp(uint256(_timestamp));

        uint256 count = bound(_countSeed, 0, MAX_FUZZED_REFERENCES);

        uint128[] memory referencedRemainders = new uint128[](count);
        uint64[] memory referencedValidUntils = new uint64[](count);

        bool[MAX_LIVE_COMMITMENTS] memory occupied;

        for (uint256 i = 0; i < count; ++i) {
            uint256 slot = _firstFreeSlotFrom(occupied, uint256(_slotSeeds[i]) % MAX_LIVE_COMMITMENTS);

            occupied[slot] = true;

            uint256 commitmentId = _record(_remainders[i], _validUntils[i]);

            harness.writeEnforcementReference(slot, commitmentId);

            referencedRemainders[i] = _remainders[i];
            referencedValidUntils[i] = _validUntils[i];
        }

        assertEq(
            harness.aggregateObligation(),
            ReferenceCalculations.referenceAggregateObligation(
                referencedRemainders, referencedValidUntils, block.timestamp
            ),
            "the derived aggregate must equal the independent reference"
        );
    }

    /// @notice Proves an unreferenced commitment never contributes, however large it is.
    /// @dev Historical records are permanent and unbounded; the enforcement scan is bounded. A commitment
    ///      outside the index must have no effect on the aggregate, or the bound would be meaningless.
    function testFuzz_aggregateObligation_ignoresUnreferencedCommitments(
        uint128 _referencedRemainder,
        uint128 _unreferencedRemainder,
        uint64 _validUntil,
        uint64 _timestamp
    ) public {
        vm.warp(uint256(_timestamp));

        uint256 referencedId = _record(_referencedRemainder, _validUntil);

        harness.writeEnforcementReference(0, referencedId);

        uint256 before = harness.aggregateObligation();

        _record(_unreferencedRemainder, _validUntil);

        assertEq(harness.aggregateObligation(), before, "an unreferenced commitment must not contribute");
    }

    /// @notice Proves the aggregate never exceeds the sum of the referenced remainders.
    /// @dev Obligation is at most the unfulfilled entitlement it comes from, so no arrangement of
    ///      references can produce more backing pressure than the commitments actually carry.
    function testFuzz_aggregateObligation_neverExceedsTheReferencedRemainders(
        uint128[MAX_FUZZED_REFERENCES] memory _remainders,
        uint64[MAX_FUZZED_REFERENCES] memory _validUntils,
        uint64 _timestamp
    ) public {
        vm.warp(uint256(_timestamp));

        uint256 totalRemainders;

        for (uint256 i = 0; i < MAX_FUZZED_REFERENCES; ++i) {
            harness.writeEnforcementReference(i, _record(_remainders[i], _validUntils[i]));

            totalRemainders += uint256(_remainders[i]);
        }

        assertLe(
            harness.aggregateObligation(), totalRemainders, "the aggregate must never exceed the referenced remainders"
        );
    }

    /// @notice Proves obligation is released for every reference once the last validity end has passed.
    /// @dev Time alone, with no transaction against any commitment, must take the aggregate to zero.
    function testFuzz_aggregateObligation_releasesEverythingAfterTheLastExpiry(
        uint128[MAX_FUZZED_REFERENCES] memory _remainders,
        uint64[MAX_FUZZED_REFERENCES] memory _validUntils
    ) public {
        uint64 lastExpiry;

        for (uint256 i = 0; i < MAX_FUZZED_REFERENCES; ++i) {
            harness.writeEnforcementReference(i, _record(_remainders[i], _validUntils[i]));

            if (_validUntils[i] > lastExpiry) lastExpiry = _validUntils[i];
        }

        vm.warp(uint256(lastExpiry));

        assertEq(harness.aggregateObligation(), 0, "every reference must be released at the last expiry");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Records one commitment with fuzzed economics and a fixed, unrelated exercise window.
    ///
    ///      The window is deliberately held constant across the fuzzed set: obligation must not depend on
    ///      it, so varying it would add no information, while fixing it makes any dependence show up as a
    ///      systematic disagreement with the reference.
    function _record(uint128 _remaining, uint64 _validUntil) internal returns (uint256 commitmentId) {
        commitmentId = harness.recordCommitment(
            StandbyHook.Commitment({
                serviceId: PoolId.wrap(bytes32(uint256(1))),
                beneficiary: makeAddr("beneficiary"),
                exercisableFrom: 1,
                exerciseAuthority: makeAddr("exerciseAuthority"),
                validUntil: _validUntil,
                originalEntitlement: _remaining,
                remainingEntitlement: _remaining
            })
        );
    }

    /// @dev Finds a free slot at or after a fuzzed starting point, wrapping around the bounded index.
    ///
    ///      A commitment may occupy only one slot, so the fuzzed slot choices have to be de-duplicated
    ///      somewhere. Resolving a collision by scanning forward keeps the arrangement scattered and
    ///      fuzzer-chosen rather than collapsing it into a contiguous prefix.
    function _firstFreeSlotFrom(bool[MAX_LIVE_COMMITMENTS] memory _occupied, uint256 _start)
        internal
        pure
        returns (uint256 slot)
    {
        for (uint256 offset = 0; offset < MAX_LIVE_COMMITMENTS; ++offset) {
            slot = (_start + offset) % MAX_LIVE_COMMITMENTS;

            if (!_occupied[slot]) return slot;
        }

        revert("no free enforcement-reference slot");
    }
}
