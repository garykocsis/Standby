// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {StandbyMath} from "../../src/libraries/StandbyMath.sol";

import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Fuzz evidence for the F5 per-commitment derivations (G5-A).
/// @dev The inputs are deliberately unconstrained. Commitment temporal terms and Remaining Entitlement
///      are `uint64` and `uint128` facts, and every combination of them — including ones an authentic
///      admission would never produce, such as a window that opens after validity ends — has a
///      well-defined derived meaning. Constraining the inputs to plausible commitments would hide exactly
///      the boundary regions worth exploring, and the derivations here consult nothing else, so nothing
///      about an unreachable combination can make the comparison meaningless.
///
///      Every case is checked against the independently composed oracle rather than against a restatement
///      of the production branch structure.
contract CommitmentDerivationFuzzTest is Test {
    /*//////////////////////////////////////////////////////////////
                            FUZZ EVIDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves validity equals the independent reference for every term and time.
    function testFuzz_validity_equalsIndependentReference(uint64 _validUntil, uint256 _timestamp) public pure {
        assertEq(
            StandbyMath.isValid(_validUntil, _timestamp),
            ReferenceCalculations.referenceValid(_validUntil, _timestamp),
            "validity must equal the independent reference"
        );
    }

    /// @notice Proves temporal exercise qualification equals the independent reference.
    function testFuzz_temporalQualification_equalsIndependentReference(
        uint64 _exercisableFrom,
        uint64 _validUntil,
        uint256 _timestamp
    ) public pure {
        assertEq(
            StandbyMath.isTemporallyExerciseQualified(_exercisableFrom, _validUntil, _timestamp),
            ReferenceCalculations.referenceTemporallyExerciseQualified(_exercisableFrom, _validUntil, _timestamp),
            "temporal qualification must equal the independent reference"
        );
    }

    /// @notice Proves permanent non-binding classification equals the independent reference.
    function testFuzz_permanentNonBinding_equalsIndependentReference(
        uint128 _remainingEntitlement,
        uint64 _validUntil,
        uint256 _timestamp
    ) public pure {
        assertEq(
            StandbyMath.isPermanentlyNonBinding(_remainingEntitlement, _validUntil, _timestamp),
            ReferenceCalculations.referencePermanentlyNonBinding(_remainingEntitlement, _validUntil, _timestamp),
            "permanent non-binding must equal the independent reference"
        );
    }

    /// @notice Proves Capacity Obligation equals the independent reference.
    function testFuzz_commitmentObligation_equalsIndependentReference(
        uint128 _remainingEntitlement,
        uint64 _validUntil,
        uint256 _timestamp
    ) public pure {
        assertEq(
            StandbyMath.commitmentObligation(_remainingEntitlement, _validUntil, _timestamp),
            ReferenceCalculations.referenceCommitmentObligation(_remainingEntitlement, _validUntil, _timestamp),
            "obligation must equal the independent reference"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          STRUCTURAL PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves obligation is either the whole remainder or nothing, never a fraction of it.
    /// @dev Standby does not partially release backing. An obligation strictly between zero and the
    ///      remainder would mean some unfulfilled entitlement had stopped being backed while the rest
    ///      continued, which the state model has no way to express.
    function testFuzz_commitmentObligation_isEitherTheWholeRemainderOrZero(
        uint128 _remainingEntitlement,
        uint64 _validUntil,
        uint256 _timestamp
    ) public pure {
        uint256 obligation = StandbyMath.commitmentObligation(_remainingEntitlement, _validUntil, _timestamp);

        assertTrue(
            obligation == 0 || obligation == uint256(_remainingEntitlement),
            "obligation must be all of the remainder or none of it"
        );
    }

    /// @notice Proves positive obligation implies both validity and a positive remainder.
    /// @dev The contrapositive of the release rule: nothing that has expired or been exhausted can carry
    ///      obligation.
    function testFuzz_positiveObligation_impliesValidityAndPositiveRemainder(
        uint128 _remainingEntitlement,
        uint64 _validUntil,
        uint256 _timestamp
    ) public pure {
        if (StandbyMath.commitmentObligation(_remainingEntitlement, _validUntil, _timestamp) == 0) return;

        assertTrue(StandbyMath.isValid(_validUntil, _timestamp), "a binding commitment must be valid");
        assertGt(_remainingEntitlement, 0, "a binding commitment must have a positive remainder");
        assertFalse(
            StandbyMath.isPermanentlyNonBinding(_remainingEntitlement, _validUntil, _timestamp),
            "a binding commitment must not be permanently released"
        );
    }

    /// @notice Proves permanent release is exactly the condition under which obligation is zero.
    /// @dev The two must coincide today, and the derivation is structured so that they cannot drift
    ///      apart: obligation is defined through the release predicate rather than beside it.
    function testFuzz_permanentRelease_coincidesWithZeroObligation(
        uint128 _remainingEntitlement,
        uint64 _validUntil,
        uint256 _timestamp
    ) public pure {
        assertEq(
            StandbyMath.isPermanentlyNonBinding(_remainingEntitlement, _validUntil, _timestamp),
            StandbyMath.commitmentObligation(_remainingEntitlement, _validUntil, _timestamp) == 0,
            "release and zero obligation must coincide"
        );
    }

    /// @notice Proves release is monotone in time: once released, always released.
    /// @dev Irreversibility is what makes release a sound basis for reclaiming a bounded reference slot.
    function testFuzz_release_isMonotoneInTime(
        uint128 _remainingEntitlement,
        uint64 _validUntil,
        uint256 _timestamp,
        uint256 _elapsed
    ) public pure {
        uint256 later = _timestamp + bound(_elapsed, 0, type(uint256).max - _timestamp);

        if (!StandbyMath.isPermanentlyNonBinding(_remainingEntitlement, _validUntil, _timestamp)) return;

        assertTrue(
            StandbyMath.isPermanentlyNonBinding(_remainingEntitlement, _validUntil, later),
            "release must never be undone by the passage of time"
        );
    }

    /// @notice Proves every temporally qualified commitment is also valid.
    /// @dev Exercisability is a strictly stronger condition than validity, and the temporal half of it
    ///      must already respect that ordering.
    function testFuzz_temporalQualification_impliesValidity(
        uint64 _exercisableFrom,
        uint64 _validUntil,
        uint256 _timestamp
    ) public pure {
        if (!StandbyMath.isTemporallyExerciseQualified(_exercisableFrom, _validUntil, _timestamp)) return;

        assertTrue(StandbyMath.isValid(_validUntil, _timestamp), "a qualified commitment must be valid");
    }

    /// @notice Proves a commitment can be binding while not temporally qualified, and finds such cases.
    /// @dev The separation of binding from exercisability is the property most at risk of being quietly
    ///      collapsed. This asserts the two are not the same predicate by requiring the fuzzer to reach
    ///      the region where they disagree, and by asserting that in that region obligation is positive.
    function testFuzz_bindingAndTemporalQualification_areDistinct(
        uint128 _remainingEntitlement,
        uint64 _exercisableFrom,
        uint64 _validUntil,
        uint256 _timestamp
    ) public pure {
        vm.assume(_remainingEntitlement > 0);
        vm.assume(_validUntil > 0);
        vm.assume(_timestamp < uint256(_validUntil));
        vm.assume(_timestamp < uint256(_exercisableFrom));

        assertFalse(
            StandbyMath.isTemporallyExerciseQualified(_exercisableFrom, _validUntil, _timestamp),
            "the window has not opened in this region"
        );
        assertEq(
            StandbyMath.commitmentObligation(_remainingEntitlement, _validUntil, _timestamp),
            uint256(_remainingEntitlement),
            "a commitment before its window still imposes its full remainder"
        );
    }
}
