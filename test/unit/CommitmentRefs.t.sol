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

/// @notice Isolated evidence for the bounded structural scan mechanics of `CommitmentRefs`.
/// @dev The library operates on a `uint256[MAX_LIVE_COMMITMENTS] storage` index and knows nothing about
///      commitments, so it is exercised here against a bare index of that exact type. This is the
///      production library, running its production code, over storage of the production shape; only the
///      owner of the storage differs.
///
///      What is proved here is structural and nothing more: where an identity sits, where the first empty
///      slot is, and that the sentinel is never mistaken for an occupant. Whether an occupied slot may be
///      taken over is an economic question the library must never answer, and no test here implies one.
contract CommitmentRefsTest is Test {
    using CommitmentRefs for uint256[MAX_LIVE_COMMITMENTS];

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256[MAX_LIVE_COMMITMENTS] internal refs;

    /*//////////////////////////////////////////////////////////////
                             UNIT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the index is exactly sixteen slots wide.
    function test_boundedIndex_hasExactlySixteenSlots() public pure {
        assertEq(MAX_LIVE_COMMITMENTS, 16, "the frozen bound is sixteen");

        uint256[MAX_LIVE_COMMITMENTS] memory snapshot;

        assertEq(snapshot.length, 16, "the index type must carry the bound");
    }

    /// @notice Proves an empty index reports the lowest slot as empty and holds no identity.
    function test_emptyIndex_reportsSlotZeroAsTheFirstEmptySlot() public view {
        (bool found, uint256 slot) = refs.firstEmptySlot();

        assertTrue(found, "an empty index always has an empty slot");
        assertEq(slot, 0, "the lowest empty slot is reported");

        (bool occupied,) = refs.slotOf(1);

        assertFalse(occupied, "an empty index references nothing");
    }

    /// @notice Proves the sentinel is never reported as occupying a slot.
    /// @dev Searching for `0` must mean "not referenced", not "the first empty slot holds commitment
    ///      zero". Without this distinction an empty slot and a reference to the reserved identity would
    ///      be the same observation.
    function test_slotOf_neverFindsTheSentinel() public {
        (bool foundInEmptyIndex,) = refs.slotOf(0);

        assertFalse(foundInEmptyIndex, "the sentinel is not an occupant of an empty index");

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            refs[slot] = slot + 1;
        }

        (bool foundInFullIndex,) = refs.slotOf(0);

        assertFalse(foundInFullIndex, "the sentinel is not an occupant of a full index");
    }

    /// @notice Proves an identity is located at exactly the slot holding it.
    function test_slotOf_locatesAnIdentityAtItsOwnSlot() public {
        refs[7] = 99;

        (bool found, uint256 slot) = refs.slotOf(99);

        assertTrue(found, "the identity must be found");
        assertEq(slot, 7, "the identity must be found at its own slot");

        (bool otherFound,) = refs.slotOf(98);

        assertFalse(otherFound, "a neighbouring value is not the same identity");
    }

    /// @notice Proves the first empty slot is the lowest empty one, including gaps left by clearing.
    function test_firstEmptySlot_reportsTheLowestEmptySlot() public {
        refs[0] = 1;
        refs[1] = 2;
        refs[2] = 3;

        (bool found, uint256 slot) = refs.firstEmptySlot();

        assertTrue(found, "an empty slot remains");
        assertEq(slot, 3, "the lowest empty slot is reported");

        refs[1] = 0;

        (, uint256 lowerSlot) = refs.firstEmptySlot();

        assertEq(lowerSlot, 1, "the reported slot follows the index, not the write order");
    }

    /// @notice Proves a fully occupied index reports no empty slot.
    /// @dev A full index is a structural statement about slots. It says nothing about whether the
    ///      referenced commitments are live, and the library offers no way to ask.
    function test_fullIndex_reportsNoEmptySlot() public {
        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            refs[slot] = slot + 1;
        }

        (bool found,) = refs.firstEmptySlot();

        assertFalse(found, "a full index has no empty slot");

        (bool lastFound, uint256 lastSlot) = refs.slotOf(MAX_LIVE_COMMITMENTS);

        assertTrue(lastFound, "the final slot is still scanned");
        assertEq(lastSlot, MAX_LIVE_COMMITMENTS - 1, "the scan covers the whole bound");
    }
}
