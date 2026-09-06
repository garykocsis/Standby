// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {CommitmentRefs, MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Parameterized evidence that the bounded scan mechanics hold for every index occupancy.
/// @dev The unit tests pin the mechanics at chosen shapes; this file walks the whole space of them. An
///      occupancy mask drives which of the sixteen slots are filled, so all `2 ** 16` arrangements —
///      empty, full, and every gap pattern in between — are reachable, and each fuzzed slot position is
///      checked against an independently computed expectation rather than against the library itself.
contract CommitmentRefsFuzzTest is Test {
    using CommitmentRefs for uint256[MAX_LIVE_COMMITMENTS];

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256[MAX_LIVE_COMMITMENTS] internal refs;

    /*//////////////////////////////////////////////////////////////
                             FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Any nonzero identity written to any slot is found at exactly that slot, and an identity that
    ///      was never written is never found.
    function testFuzz_slotOf_locatesAnyIdentityAtItsOwnSlot(uint8 _rawSlot, uint256 _identity, uint256 _absentIdentity)
        public
    {
        uint256 slot = bound(uint256(_rawSlot), 0, MAX_LIVE_COMMITMENTS - 1);

        vm.assume(_identity != 0);
        vm.assume(_absentIdentity != _identity);

        refs[slot] = _identity;

        (bool found, uint256 foundSlot) = refs.slotOf(_identity);

        assertTrue(found, "a written identity must be found");
        assertEq(foundSlot, slot, "it must be found at the slot it was written to");

        (bool absentFound,) = refs.slotOf(_absentIdentity);

        assertFalse(absentFound, "an identity that was never written must not be found");
    }

    /// @dev The sentinel is never an occupant, at any occupancy, including a completely empty index.
    function testFuzz_slotOf_neverFindsTheSentinel(uint16 _occupancy) public {
        _applyOccupancy(_occupancy);

        (bool found, uint256 slot) = refs.slotOf(0);

        assertFalse(found, "the sentinel is never an occupant");
        assertEq(slot, 0, "no slot is reported for the sentinel");
    }

    /// @dev The reported empty slot is the lowest empty slot, and a full index reports none. The
    ///      expectation is computed from the occupancy mask directly rather than from the library.
    function testFuzz_firstEmptySlot_reportsTheLowestEmptySlot(uint16 _occupancy) public {
        _applyOccupancy(_occupancy);

        (bool found, uint256 slot) = refs.firstEmptySlot();

        if (_occupancy == type(uint16).max) {
            assertFalse(found, "a full index has no empty slot");
            return;
        }

        assertTrue(found, "a non-full index has an empty slot");
        assertEq(refs[slot], 0, "the reported slot must actually be empty");

        for (uint256 lower = 0; lower < slot; ++lower) {
            assertTrue(refs[lower] != 0, "no lower slot may be empty");
        }
    }

    /// @dev Every occupied slot is locatable by its identity and every empty slot holds the sentinel, so
    ///      the two observations partition the index with no overlap and no gap.
    function testFuzz_boundedIndex_partitionsIntoOccupiedAndEmptySlots(uint16 _occupancy) public {
        _applyOccupancy(_occupancy);

        uint256 occupiedCount;

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            if ((_occupancy >> slot) & 1 == 1) {
                ++occupiedCount;

                (bool found, uint256 foundSlot) = refs.slotOf(_identityFor(slot));

                assertTrue(found, "an occupied slot must be locatable");
                assertEq(foundSlot, slot, "it must be located at its own slot");
            } else {
                assertEq(refs[slot], 0, "an unoccupied slot must hold the sentinel");
            }
        }

        assertTrue(occupiedCount <= MAX_LIVE_COMMITMENTS, "occupancy can never exceed the bound");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Fills the index according to an occupancy mask: bit `i` set means slot `i` is occupied.
    function _applyOccupancy(uint16 _occupancy) internal {
        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            refs[slot] = (_occupancy >> slot) & 1 == 1 ? _identityFor(slot) : 0;
        }
    }

    /// @dev A distinct nonzero identity per slot, so a scan cannot pass by finding the wrong occupant.
    function _identityFor(uint256 _slot) internal pure returns (uint256 identity) {
        identity = _slot + 1;
    }
}
