// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {TickMath} from "v4-core/libraries/TickMath.sol";

import {ServiceDomain} from "../../src/libraries/ServiceDomain.sol";

import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Unit evidence for the F5 service-domain geometry and topology classification (G5-A).
/// @dev The library under test is pure, so these tests call it directly rather than through a harness.
///      Every classification is checked against the independent oracle as well as against the explicit
///      geometric expectation, so a production predicate that agreed with itself but not with the frozen
///      semantics would still fail.
///
///      The direction-relative meaning of the boundaries is exercised in both directions throughout.
///      `tickQ` is the protected execution-quality boundary, which is numerically below `tickO` for a
///      protected `zeroForOne` service and numerically above it for a protected `oneForZero` one; a
///      geometry that quietly assumed the first case would pass half of this file and fail the other.
contract ServiceDomainTest is Test {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    int24 internal constant PROTECTED_DOWN_TICK_Q = -240;
    int24 internal constant PROTECTED_DOWN_TICK_O = 240;

    int24 internal constant PROTECTED_UP_TICK_Q = 600;
    int24 internal constant PROTECTED_UP_TICK_O = -120;

    /*//////////////////////////////////////////////////////////////
                        DIRECTION CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a protected `zeroForOne` service requires `tickQ` below `tickO`.
    function test_directionConsistency_requiresQBelowOForProtectedZeroForOne() public pure {
        assertTrue(
            ServiceDomain.isDirectionConsistent(true, PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O),
            "downward protection must accept tickQ below tickO"
        );
        assertFalse(
            ServiceDomain.isDirectionConsistent(true, PROTECTED_DOWN_TICK_O, PROTECTED_DOWN_TICK_Q),
            "downward protection must reject the reversed pair"
        );
    }

    /// @notice Proves a protected `oneForZero` service requires `tickQ` above `tickO`.
    /// @dev The mirror requirement. `tickQ` is not the numerically lower boundary; it is the boundary the
    ///      protected direction moves toward.
    function test_directionConsistency_requiresQAboveOForProtectedOneForZero() public pure {
        assertTrue(
            ServiceDomain.isDirectionConsistent(false, PROTECTED_UP_TICK_Q, PROTECTED_UP_TICK_O),
            "upward protection must accept tickQ above tickO"
        );
        assertFalse(
            ServiceDomain.isDirectionConsistent(false, PROTECTED_UP_TICK_O, PROTECTED_UP_TICK_Q),
            "upward protection must reject the reversed pair"
        );
    }

    /// @notice Proves a degenerate single-tick domain is rejected in both directions.
    function test_directionConsistency_rejectsEqualBoundaries() public pure {
        assertFalse(ServiceDomain.isDirectionConsistent(true, 120, 120), "a degenerate domain has no interior");
        assertFalse(ServiceDomain.isDirectionConsistent(false, 120, 120), "a degenerate domain has no interior");
    }

    /*//////////////////////////////////////////////////////////////
                             NUMERIC SHAPE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the numeric bounds are direction-independent minimum and maximum.
    function test_numericBounds_areTheMinimumAndMaximumRegardlessOfDirection() public pure {
        (int24 lowerDown, int24 upperDown) = ServiceDomain.numericBounds(PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O);

        assertEq(lowerDown, PROTECTED_DOWN_TICK_Q, "tickQ is the numeric minimum when protection is downward");
        assertEq(upperDown, PROTECTED_DOWN_TICK_O, "tickO is the numeric maximum when protection is downward");

        (int24 lowerUp, int24 upperUp) = ServiceDomain.numericBounds(PROTECTED_UP_TICK_Q, PROTECTED_UP_TICK_O);

        assertEq(lowerUp, PROTECTED_UP_TICK_O, "tickO is the numeric minimum when protection is upward");
        assertEq(upperUp, PROTECTED_UP_TICK_Q, "tickQ is the numeric maximum when protection is upward");
    }

    /// @notice Proves the square-root bounds are the pinned prices of the numeric boundary ticks.
    /// @dev The boundary prices are derived from the canonical persisted ticks (RR-SC-3) rather than
    ///      stored independently, so this fixes the correspondence the whole domain classification rests
    ///      on.
    function test_sqrtBounds_areThePinnedPricesOfTheNumericBoundaries() public pure {
        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) =
            ServiceDomain.sqrtBounds(PROTECTED_UP_TICK_Q, PROTECTED_UP_TICK_O);

        assertEq(sqrtLowerX96, TickMath.getSqrtPriceAtTick(PROTECTED_UP_TICK_O), "lower bound price must be tickO's");
        assertEq(sqrtUpperX96, TickMath.getSqrtPriceAtTick(PROTECTED_UP_TICK_Q), "upper bound price must be tickQ's");
        assertLt(sqrtLowerX96, sqrtUpperX96, "the bounds must be ordered");
    }

    /*//////////////////////////////////////////////////////////////
                              CONTAINMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the domain is closed: both boundary prices are inside it.
    function test_containsPrice_includesBothBoundaries() public pure {
        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) =
            ServiceDomain.sqrtBounds(PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O);

        assertTrue(ServiceDomain.containsPrice(sqrtLowerX96, sqrtLowerX96, sqrtUpperX96), "P_Q is inside the domain");
        assertTrue(ServiceDomain.containsPrice(sqrtUpperX96, sqrtLowerX96, sqrtUpperX96), "P_O is inside the domain");
    }

    /// @notice Proves a price one unit outside either boundary is excluded.
    /// @dev One raw Q64.96 unit is the finest distinction the representation admits, so this is the
    ///      tightest possible statement that the interval is exactly the configured one.
    function test_containsPrice_excludesOneUnitBeyondEitherBoundary() public pure {
        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) =
            ServiceDomain.sqrtBounds(PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O);

        assertFalse(
            ServiceDomain.containsPrice(sqrtLowerX96 - 1, sqrtLowerX96, sqrtUpperX96), "one unit below is outside"
        );
        assertFalse(
            ServiceDomain.containsPrice(sqrtUpperX96 + 1, sqrtLowerX96, sqrtUpperX96), "one unit above is outside"
        );
    }

    /// @notice Proves production containment equals the independent reference classification.
    function test_containsPrice_equalsIndependentReference() public pure {
        int24[5] memory probeTicks = [int24(-360), int24(-240), int24(0), int24(240), int24(360)];

        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) =
            ServiceDomain.sqrtBounds(PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O);

        for (uint256 i = 0; i < probeTicks.length; ++i) {
            uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(probeTicks[i]);

            assertEq(
                ServiceDomain.containsPrice(sqrtPriceX96, sqrtLowerX96, sqrtUpperX96),
                ReferenceCalculations.referenceDomainContainsPrice(
                    sqrtPriceX96, PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O
                ),
                "containment must equal the independent reference"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                          INTERIOR TOPOLOGY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a position enclosing the domain introduces no interior boundary.
    function test_interiorBoundary_permitsAPositionEnclosingTheDomain() public pure {
        assertFalse(
            ServiceDomain.introducesInteriorBoundary(-300, 300, PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O),
            "an enclosing position introduces no interior boundary"
        );
    }

    /// @notice Proves endpoints exactly on the configured boundaries are permitted.
    /// @dev RR-SC-6 excludes only the open interval. A position spanning the domain exactly is the
    ///      boundary case the rule deliberately allows.
    function test_interiorBoundary_permitsEndpointsExactlyOnTheBoundaries() public pure {
        assertFalse(
            ServiceDomain.introducesInteriorBoundary(
                PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O, PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O
            ),
            "a position spanning the domain exactly is permitted"
        );
    }

    /// @notice Proves a position entirely outside the domain introduces no interior boundary.
    function test_interiorBoundary_permitsAPositionEntirelyOutsideTheDomain() public pure {
        assertFalse(
            ServiceDomain.introducesInteriorBoundary(600, 900, PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O),
            "a position above the domain introduces no interior boundary"
        );
        assertFalse(
            ServiceDomain.introducesInteriorBoundary(-900, -600, PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O),
            "a position below the domain introduces no interior boundary"
        );
    }

    /// @notice Proves either endpoint strictly inside the domain is classified as introducing one.
    /// @dev This is the topology the single-active-region capacity model depends on: an initialized
    ///      boundary inside the domain would split the constant-liquidity interval the derivation assumes.
    function test_interiorBoundary_flagsEitherEndpointStrictlyInside() public pure {
        assertTrue(
            ServiceDomain.introducesInteriorBoundary(-100, 900, PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O),
            "an interior lower endpoint must be flagged"
        );
        assertTrue(
            ServiceDomain.introducesInteriorBoundary(-900, 100, PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O),
            "an interior upper endpoint must be flagged"
        );
        assertTrue(
            ServiceDomain.introducesInteriorBoundary(-100, 100, PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O),
            "a position strictly inside must be flagged"
        );
    }

    /// @notice Proves the interior classification is direction-independent.
    /// @dev The topology constraint is about the numeric interval, so reversing which boundary is `P_Q`
    ///      must not change which positions are acceptable.
    function test_interiorBoundary_isIndependentOfWhichBoundaryIsPQ() public pure {
        assertEq(
            ServiceDomain.introducesInteriorBoundary(-100, 900, PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O),
            ServiceDomain.introducesInteriorBoundary(-100, 900, PROTECTED_DOWN_TICK_O, PROTECTED_DOWN_TICK_Q),
            "swapping the boundary roles must not change the topology answer"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         TRAVERSAL DEMAND
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the canonical fixture domain demands the three steps its geometry implies.
    /// @dev At a spacing of ten the domain compresses to [-24, 24], which straddles the edge between
    ///      bitmap words -1 and 0: two words, plus the one conditional step the non-edge top allows for.
    function test_traversalDemand_matchesTheCanonicalFixtureGeometry() public pure {
        assertEq(
            ServiceDomain.prospectiveTraversalDemand(PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O, 10),
            3,
            "the canonical domain must demand three steps"
        );
    }

    /// @notice Proves demand is independent of which boundary the protected direction makes `P_Q`.
    /// @dev Ordinary swaps run in both directions on any service, so the demand a domain implies is a
    ///      fact about its numeric width in bitmap words, not about which end is protected.
    function test_traversalDemand_isIndependentOfTheProtectedDirection() public pure {
        assertEq(
            ServiceDomain.prospectiveTraversalDemand(PROTECTED_UP_TICK_Q, PROTECTED_UP_TICK_O, 60),
            ServiceDomain.prospectiveTraversalDemand(PROTECTED_UP_TICK_O, PROTECTED_UP_TICK_Q, 60),
            "swapping the boundary roles must not change traversal demand"
        );
    }

    /// @notice Proves tick spacing changes demand for the identical tick geometry.
    /// @dev A bitmap word covers 256 compressed ticks, so a finer spacing packs fewer real ticks into a
    ///      word and the same boundaries span more words. Demand is a property of geometry and spacing
    ///      together, which is why it cannot be judged from tick width alone.
    function test_traversalDemand_growsAsTickSpacingNarrows() public pure {
        uint256 coarse = ServiceDomain.prospectiveTraversalDemand(-2_560, 2_560, 10);
        uint256 fine = ServiceDomain.prospectiveTraversalDemand(-2_560, 2_560, 1);

        assertEq(coarse, 3, "at spacing ten the domain spans two words");
        assertGt(fine, coarse, "the same ticks span more words at a finer spacing");
    }

    /// @notice Proves a top boundary on a bitmap word edge costs no conditional crossing step.
    /// @dev The extra step exists for the case where the price starts on an initialized top boundary and
    ///      v4 spends one step crossing it without leaving the word. When the top compresses onto a word
    ///      edge the crossing already leaves the word, so the step cannot be spent and is not charged.
    function test_traversalDemand_chargesNoExtraStepForAWordAlignedTop() public pure {
        assertEq(ServiceDomain.prospectiveTraversalDemand(-256, 0, 1), 2, "a word-aligned top costs no extra step");
        assertEq(ServiceDomain.prospectiveTraversalDemand(-256, 1, 1), 3, "one tick past the edge costs the extra step");
    }

    /// @notice Proves the word boundary is located correctly in negative tick regions.
    /// @dev Uniswap compresses and indexes by flooring, not by truncating toward zero, so tick -1 belongs
    ///      to word -1 rather than word 0. A truncating implementation would place the whole of
    ///      [-255, -1] in word 0 and under-count every domain that reaches below parity.
    function test_traversalDemand_floorsWordIndicesInNegativeTickRegions() public pure {
        assertEq(ServiceDomain.prospectiveTraversalDemand(-1, 0, 1), 2, "tick -1 lies one word below tick 0");
        assertEq(ServiceDomain.prospectiveTraversalDemand(-256, -1, 1), 2, "word -1 spans ticks -256 to -1");
        assertEq(ServiceDomain.prospectiveTraversalDemand(-257, -1, 1), 3, "tick -257 lies in word -2");
    }

    /// @notice Proves demand is symmetric about parity for mirrored positive and negative domains.
    function test_traversalDemand_coversPositiveAndNegativeRegionsAlike() public pure {
        assertEq(
            ServiceDomain.prospectiveTraversalDemand(1_000, 3_000, 1),
            ServiceDomain.prospectiveTraversalDemand(-3_000, -1_000, 1),
            "a domain and its mirror image must span the same number of words"
        );
    }

    /// @notice Proves production traversal demand equals the independent reference across regions.
    /// @dev The probes deliberately include domains entirely above parity, entirely below it, and
    ///      straddling it, at several spacings, because flooring and truncating division agree everywhere
    ///      except below zero.
    function test_traversalDemand_equalsIndependentReference() public pure {
        int24[6] memory lowers = [int24(-3_484), int24(-256), int24(-1), int24(0), int24(1_000), int24(-887_200)];
        int24[6] memory uppers = [int24(100), int24(0), int24(0), int24(4_096), int24(3_000), int24(-880_000)];
        int24[6] memory spacings = [int24(1), int24(1), int24(1), int24(10), int24(60), int24(200)];

        for (uint256 i = 0; i < lowers.length; ++i) {
            assertEq(
                ServiceDomain.prospectiveTraversalDemand(lowers[i], uppers[i], spacings[i]),
                ReferenceCalculations.referenceProspectiveTraversalDemand(lowers[i], uppers[i], spacings[i]),
                "traversal demand must equal the independent reference"
            );
        }
    }

    /// @notice Proves production interior classification equals the independent reference.
    function test_interiorBoundary_equalsIndependentReference() public pure {
        int24[6] memory lowers = [int24(-900), int24(-300), int24(-240), int24(-100), int24(0), int24(240)];
        int24[6] memory uppers = [int24(-600), int24(300), int24(240), int24(100), int24(900), int24(600)];

        for (uint256 i = 0; i < lowers.length; ++i) {
            assertEq(
                ServiceDomain.introducesInteriorBoundary(
                    lowers[i], uppers[i], PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O
                ),
                ReferenceCalculations.referenceIntroducesInteriorBoundary(
                    lowers[i], uppers[i], PROTECTED_DOWN_TICK_Q, PROTECTED_DOWN_TICK_O
                ),
                "interior classification must equal the independent reference"
            );
        }
    }
}
