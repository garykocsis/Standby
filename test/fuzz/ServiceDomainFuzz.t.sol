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

/// @notice Fuzz evidence for the F5 service-domain geometry and topology classification (G5-A).
/// @dev Boundary ticks are bounded only by the pinned Uniswap tick range, because that is the whole space
///      a configured boundary can occupy. Prices are generated across the full representable square-root
///      range rather than only inside candidate domains, so the classification is exercised on both
///      sides of every boundary as well as within it.
contract ServiceDomainFuzzTest is Test {
    /*//////////////////////////////////////////////////////////////
                            FUZZ EVIDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves containment equals the independent reference for any boundaries and any price.
    function testFuzz_containment_equalsIndependentReference(int24 _tickASeed, int24 _tickBSeed, uint256 _priceSeed)
        public
        pure
    {
        (int24 tickQ, int24 tickO) = _distinctBoundaries(_tickASeed, _tickBSeed);

        uint160 sqrtPriceX96 = _anyRepresentablePrice(_priceSeed);

        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) = ServiceDomain.sqrtBounds(tickQ, tickO);

        assertEq(
            ServiceDomain.containsPrice(sqrtPriceX96, sqrtLowerX96, sqrtUpperX96),
            ReferenceCalculations.referenceDomainContainsPrice(sqrtPriceX96, tickQ, tickO),
            "containment must equal the independent reference"
        );
    }

    /// @notice Proves interior-boundary classification equals the independent reference.
    function testFuzz_interiorBoundary_equalsIndependentReference(
        int24 _tickASeed,
        int24 _tickBSeed,
        int24 _lowerSeed,
        int24 _upperSeed
    ) public pure {
        (int24 tickQ, int24 tickO) = _distinctBoundaries(_tickASeed, _tickBSeed);

        int24 tickLower = int24(bound(int256(_lowerSeed), TickMath.MIN_TICK, TickMath.MAX_TICK));
        int24 tickUpper = int24(bound(int256(_upperSeed), int256(tickLower), TickMath.MAX_TICK));

        assertEq(
            ServiceDomain.introducesInteriorBoundary(tickLower, tickUpper, tickQ, tickO),
            ReferenceCalculations.referenceIntroducesInteriorBoundary(tickLower, tickUpper, tickQ, tickO),
            "interior classification must equal the independent reference"
        );
    }

    /// @notice Proves traversal demand equals the independent reference for any domain and spacing.
    /// @dev Spacing and both boundaries are fuzzed across the whole usable tick range, so the flooring
    ///      behaviour that separates negative from positive regions is exercised on both sides of parity
    ///      and at every word alignment.
    function testFuzz_traversalDemand_equalsIndependentReference(
        int24 _tickASeed,
        int24 _tickBSeed,
        uint256 _spacingSeed
    ) public pure {
        (int24 tickQ, int24 tickO) = _distinctBoundaries(_tickASeed, _tickBSeed);

        int24 tickSpacing = int24(int256(bound(_spacingSeed, 1, 200)));

        assertEq(
            ServiceDomain.prospectiveTraversalDemand(tickQ, tickO, tickSpacing),
            ReferenceCalculations.referenceProspectiveTraversalDemand(tickQ, tickO, tickSpacing),
            "traversal demand must equal the independent reference"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          STRUCTURAL PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves traversal demand never depends on which boundary is `P_Q`.
    /// @dev Ordinary swaps run in both directions on any service, so demand is a fact about the numeric
    ///      domain. A classifier that consulted the protected direction would answer differently for the
    ///      same geometry depending on how it was labelled.
    function testFuzz_traversalDemand_isIndependentOfBoundaryRoles(
        int24 _tickASeed,
        int24 _tickBSeed,
        uint256 _spacingSeed
    ) public pure {
        (int24 tickQ, int24 tickO) = _distinctBoundaries(_tickASeed, _tickBSeed);

        int24 tickSpacing = int24(int256(bound(_spacingSeed, 1, 200)));

        assertEq(
            ServiceDomain.prospectiveTraversalDemand(tickQ, tickO, tickSpacing),
            ServiceDomain.prospectiveTraversalDemand(tickO, tickQ, tickSpacing),
            "swapping the boundary roles must not change traversal demand"
        );
    }

    /// @notice Proves traversal demand never decreases when the domain widens.
    /// @dev Monotonicity is what makes an admitted domain safe to reason about: no supported domain can
    ///      be contained in an accepted one and still demand more steps than it.
    function testFuzz_traversalDemand_isMonotoneInDomainWidth(
        int24 _tickASeed,
        int24 _tickBSeed,
        int24 _widerSeed,
        uint256 _spacingSeed
    ) public pure {
        (int24 tickQ, int24 tickO) = _distinctBoundaries(_tickASeed, _tickBSeed);

        int24 tickSpacing = int24(int256(bound(_spacingSeed, 1, 200)));

        (int24 lowerTick, int24 upperTick) = ServiceDomain.numericBounds(tickQ, tickO);

        int24 widerUpper = int24(bound(int256(_widerSeed), int256(upperTick), TickMath.MAX_TICK));

        assertLe(
            ServiceDomain.prospectiveTraversalDemand(lowerTick, upperTick, tickSpacing),
            ServiceDomain.prospectiveTraversalDemand(lowerTick, widerUpper, tickSpacing),
            "widening a domain must never reduce its traversal demand"
        );
    }

    /// @notice Proves every domain demands at least one step, and a minimal one demands at most two.
    /// @dev The lower bound rules out a classifier that could report zero and admit a domain it cannot
    ///      traverse at all. The upper bound on the narrowest possible domain rules out one that inflates
    ///      demand with width-independent overhead: a single tick of width can straddle at most one word
    ///      edge, so at most one extra step can ever be owed for it.
    function testFuzz_traversalDemand_isBoundedForAMinimalDomain(int24 _tickSeed, uint256 _spacingSeed) public pure {
        int24 tickSpacing = int24(int256(bound(_spacingSeed, 1, 200)));

        int24 lowerTick = int24(bound(int256(_tickSeed), TickMath.MIN_TICK, TickMath.MAX_TICK - 1));

        uint256 demand = ServiceDomain.prospectiveTraversalDemand(lowerTick, lowerTick + 1, tickSpacing);

        assertGe(demand, 1, "every domain demands at least one step");
        assertLe(demand, 2, "a one-tick domain can straddle at most one word edge");
    }

    /// @notice Proves the domain is closed at both ends, for any boundary pair.
    function testFuzz_containment_includesBothBoundaries(int24 _tickASeed, int24 _tickBSeed) public pure {
        (int24 tickQ, int24 tickO) = _distinctBoundaries(_tickASeed, _tickBSeed);

        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) = ServiceDomain.sqrtBounds(tickQ, tickO);

        assertTrue(ServiceDomain.containsPrice(sqrtLowerX96, sqrtLowerX96, sqrtUpperX96), "the lower bound is inside");
        assertTrue(ServiceDomain.containsPrice(sqrtUpperX96, sqrtLowerX96, sqrtUpperX96), "the upper bound is inside");
    }

    /// @notice Proves exactly one direction accepts a given ordered boundary pair.
    /// @dev The two protected directions impose opposite orderings, so a pair that is consistent for one
    ///      must be inconsistent for the other. A predicate that accepted both would have stopped
    ///      distinguishing which boundary is `P_Q`.
    function testFuzz_directionConsistency_acceptsExactlyOneDirection(int24 _tickASeed, int24 _tickBSeed) public pure {
        (int24 tickQ, int24 tickO) = _distinctBoundaries(_tickASeed, _tickBSeed);

        assertNotEq(
            ServiceDomain.isDirectionConsistent(true, tickQ, tickO),
            ServiceDomain.isDirectionConsistent(false, tickQ, tickO),
            "a distinct ordered pair must suit exactly one protected direction"
        );
    }

    /// @notice Proves the numeric bounds are order-independent and correctly ordered.
    function testFuzz_numericBounds_areOrderIndependent(int24 _tickASeed, int24 _tickBSeed) public pure {
        (int24 tickQ, int24 tickO) = _distinctBoundaries(_tickASeed, _tickBSeed);

        (int24 lowerForward, int24 upperForward) = ServiceDomain.numericBounds(tickQ, tickO);
        (int24 lowerReversed, int24 upperReversed) = ServiceDomain.numericBounds(tickO, tickQ);

        assertEq(lowerForward, lowerReversed, "the lower bound must not depend on argument order");
        assertEq(upperForward, upperReversed, "the upper bound must not depend on argument order");
        assertLt(lowerForward, upperForward, "the bounds must be strictly ordered for distinct boundaries");
    }

    /// @notice Proves a position enclosing the whole domain never introduces an interior boundary.
    function testFuzz_interiorBoundary_permitsAnyEnclosingPosition(
        int24 _tickASeed,
        int24 _tickBSeed,
        int24 _marginSeed
    ) public pure {
        (int24 tickQ, int24 tickO) = _distinctBoundaries(_tickASeed, _tickBSeed);

        (int24 lowerTick, int24 upperTick) = ServiceDomain.numericBounds(tickQ, tickO);

        int24 margin = int24(bound(int256(_marginSeed), 0, 10_000));

        int24 tickLower = lowerTick - margin < TickMath.MIN_TICK ? TickMath.MIN_TICK : lowerTick - margin;
        int24 tickUpper = upperTick + margin > TickMath.MAX_TICK ? TickMath.MAX_TICK : upperTick + margin;

        assertFalse(
            ServiceDomain.introducesInteriorBoundary(tickLower, tickUpper, tickQ, tickO),
            "an enclosing position must never introduce an interior boundary"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Generates two distinct valid boundary ticks.
    ///
    ///      Distinctness is required because a degenerate single-tick domain is rejected at configuration
    ///      and has no geometry to classify.
    function _distinctBoundaries(int24 _tickASeed, int24 _tickBSeed) internal pure returns (int24 tickQ, int24 tickO) {
        tickQ = int24(bound(int256(_tickASeed), TickMath.MIN_TICK, TickMath.MAX_TICK));
        tickO = int24(bound(int256(_tickBSeed), TickMath.MIN_TICK, TickMath.MAX_TICK));

        if (tickQ == tickO) {
            tickO = tickQ == TickMath.MAX_TICK ? tickQ - 1 : tickQ + 1;
        }
    }

    /// @dev Generates any square-root price Uniswap can represent.
    function _anyRepresentablePrice(uint256 _priceSeed) internal pure returns (uint160 sqrtPriceX96) {
        sqrtPriceX96 = uint160(bound(_priceSeed, uint256(TickMath.MIN_SQRT_PRICE), uint256(TickMath.MAX_SQRT_PRICE)));
    }
}
