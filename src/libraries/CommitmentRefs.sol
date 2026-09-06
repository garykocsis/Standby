// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                             CONSTANTS
//////////////////////////////////////////////////////////////*/

// The size of the bounded enforcement-reference index, and the single definition of the bound.
//
// It is declared at file level rather than inside the library because Solidity accepts only a file-level
// constant as an array length here, and the index type must be written identically by the library that
// scans it and the Hook that owns it.
//
// This is a bounded-gas realization constant. It is not a lifetime limit on how many commitments a
// service may have: historical records are permanent and unbounded, and slots are reused.
uint256 constant MAX_LIVE_COMMITMENTS = 16;

// The empty-slot sentinel. `0` is never a valid commitment identity, so an empty slot and an occupied
// slot can never be confused.
uint256 constant EMPTY_REFERENCE = 0;

/*//////////////////////////////////////////////////////////////
                            LIBRARIES
//////////////////////////////////////////////////////////////*/

/// @title CommitmentRefs
/// @notice Bounded structural mechanics for the fixed-size Standby enforcement-reference index.
/// @dev This library is deliberately non-economic. It knows that a slot holds either the empty sentinel
///      `0` or some opaque nonzero identifier, and nothing else. It does not know what a commitment is,
///      whether one is valid, exercisable, binding, fulfilled, expired, or reclaimable, and it must never
///      learn: the authoritative economic interpretation of the referenced commitments is owned by the
///      derivation slice, and reference membership is never evidence of any economic classification.
///
///      The index exists for one reason: it makes the candidate universe that later derivation must scan
///      finite. Historical commitment records are permanent and may grow without bound; the set of
///      references that enforcement has to walk does not.
library CommitmentRefs {
    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the slot currently referencing `_commitmentId`, scanning the whole bounded index.
    ///
    ///      The sentinel is excluded explicitly rather than incidentally: searching for `0` must report
    ///      "not referenced" rather than reporting the first empty slot as an occurrence of commitment
    ///      zero. Callers use this both to look a reference up and to reject a duplicate before writing.
    /// @param _refs The bounded enforcement-reference index.
    /// @param _commitmentId The identity to look for.
    /// @return found Whether the identity occupies a slot.
    /// @return slot The occupied slot when `found`, otherwise zero and meaningless.
    function slotOf(uint256[MAX_LIVE_COMMITMENTS] storage _refs, uint256 _commitmentId)
        internal
        view
        returns (bool found, uint256 slot)
    {
        if (_commitmentId == EMPTY_REFERENCE) return (false, 0);

        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            if (_refs[i] == _commitmentId) return (true, i);
        }
    }

    /// @dev Returns the lowest empty slot of the bounded index, if one exists.
    ///
    ///      Emptiness is purely structural. A full index means every slot currently holds a reference; it
    ///      does not mean those referenced commitments are live, binding, or unreclaimable. Deciding
    ///      whether an occupied slot may be taken over is an economic judgement this library never makes.
    /// @param _refs The bounded enforcement-reference index.
    /// @return found Whether an empty slot exists.
    /// @return slot The lowest empty slot when `found`, otherwise zero and meaningless.
    function firstEmptySlot(uint256[MAX_LIVE_COMMITMENTS] storage _refs)
        internal
        view
        returns (bool found, uint256 slot)
    {
        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            if (_refs[i] == EMPTY_REFERENCE) return (true, i);
        }
    }
}
