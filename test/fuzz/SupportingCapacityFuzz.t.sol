// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {TickMath} from "v4-core/libraries/TickMath.sol";

import {ServiceDomain} from "../../src/libraries/ServiceDomain.sol";
import {StandbyMath} from "../../src/libraries/StandbyMath.sol";

import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Fuzz evidence for the F5 Supporting Capacity kernel (G5-A).
/// @dev The generated inputs describe *valid* derivation bases, because capacity is only defined over
///      one. A price beyond `P_Q`, or boundaries ordered against the protected direction, is a rejected
///      basis rather than a capacity of some value, and the unit suite covers those rejections
///      explicitly. Here the generator produces a direction-consistent boundary pair, a price inside the
///      closed domain, and a liquidity, and the assertion is equivalence with the independent oracle.
///
///      Two generation choices are worth stating. Domain widths reach far beyond anything the canonical
///      fixture uses, up to a quarter of the whole tick range, because the exact integer answer must not
///      depend on the domain being narrow. Liquidity reaches `2^100`, which is far above any realistic
///      pool and well inside the range where the intermediate products stress full-precision
///      multiplication.
contract SupportingCapacityFuzzTest is Test {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The widest service domain the generator produces, in ticks.
    int24 internal constant MAX_DOMAIN_WIDTH = 400_000;

    /// @dev The largest liquidity the generator produces.
    uint128 internal constant MAX_LIQUIDITY = uint128(1) << 100;

    /*//////////////////////////////////////////////////////////////
                            FUZZ EVIDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves downward-protected capacity equals the independent reference across the domain.
    function testFuzz_zeroForOne_capacityEqualsIndependentReference(
        int24 _tickQSeed,
        int24 _widthSeed,
        uint256 _priceSeed,
        uint128 _liquiditySeed
    ) public pure {
        (int24 tickQ, int24 tickO) = _downwardProtectedDomain(_tickQSeed, _widthSeed);

        uint160 sqrtPriceX96 = _priceInDomain(tickQ, tickO, _priceSeed);
        uint128 liquidity = uint128(bound(uint256(_liquiditySeed), 0, MAX_LIQUIDITY));

        assertEq(
            StandbyMath.supportingCapacity(true, sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickQ), liquidity),
            ReferenceCalculations.referenceSupportingCapacity(true, sqrtPriceX96, tickQ, liquidity),
            "downward-protected capacity must equal the independent reference"
        );
    }

    /// @notice Proves upward-protected capacity equals the independent reference across the domain.
    function testFuzz_oneForZero_capacityEqualsIndependentReference(
        int24 _tickQSeed,
        int24 _widthSeed,
        uint256 _priceSeed,
        uint128 _liquiditySeed
    ) public pure {
        (int24 tickQ, int24 tickO) = _upwardProtectedDomain(_tickQSeed, _widthSeed);

        uint160 sqrtPriceX96 = _priceInDomain(tickQ, tickO, _priceSeed);
        uint128 liquidity = uint128(bound(uint256(_liquiditySeed), 0, MAX_LIQUIDITY));

        assertEq(
            StandbyMath.supportingCapacity(false, sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickQ), liquidity),
            ReferenceCalculations.referenceSupportingCapacity(false, sqrtPriceX96, tickQ, liquidity),
            "upward-protected capacity must equal the independent reference"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          STRUCTURAL PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves capacity vanishes exactly at `P_Q`, whatever the liquidity.
    /// @dev Exhaustion is a property of the price reaching the boundary, not of the pool running out of
    ///      anything. However deep the liquidity, there is no protected output left to execute toward a
    ///      boundary the price already sits on.
    function testFuzz_capacity_isZeroAtPQForAnyLiquidity(
        int24 _tickQSeed,
        int24 _widthSeed,
        uint128 _liquiditySeed,
        bool _protectedZeroForOne
    ) public pure {
        (int24 tickQ,) = _protectedZeroForOne
            ? _downwardProtectedDomain(_tickQSeed, _widthSeed)
            : _upwardProtectedDomain(_tickQSeed, _widthSeed);

        uint160 sqrtQX96 = TickMath.getSqrtPriceAtTick(tickQ);
        uint128 liquidity = uint128(bound(uint256(_liquiditySeed), 0, MAX_LIQUIDITY));

        assertEq(
            StandbyMath.supportingCapacity(_protectedZeroForOne, sqrtQX96, sqrtQX96, liquidity),
            0,
            "capacity must be exactly zero at P_Q"
        );
    }

    /// @notice Proves zero liquidity never manufactures capacity anywhere in the domain.
    function testFuzz_capacity_isZeroWithoutLiquidity(
        int24 _tickQSeed,
        int24 _widthSeed,
        uint256 _priceSeed,
        bool _protectedZeroForOne
    ) public pure {
        (int24 tickQ, int24 tickO) = _protectedZeroForOne
            ? _downwardProtectedDomain(_tickQSeed, _widthSeed)
            : _upwardProtectedDomain(_tickQSeed, _widthSeed);

        uint160 sqrtPriceX96 = _priceInDomain(tickQ, tickO, _priceSeed);

        assertEq(
            StandbyMath.supportingCapacity(_protectedZeroForOne, sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickQ), 0),
            0,
            "no liquidity means no capacity"
        );
    }

    /// @notice Proves capacity never decreases when liquidity increases.
    /// @dev Deeper liquidity can only make more protected output executable to the same boundary. A
    ///      derivation in which it did not would be measuring something other than executable capacity.
    function testFuzz_capacity_isMonotoneInLiquidity(
        int24 _tickQSeed,
        int24 _widthSeed,
        uint256 _priceSeed,
        uint128 _liquiditySeed,
        uint128 _extraSeed,
        bool _protectedZeroForOne
    ) public pure {
        (int24 tickQ, int24 tickO) = _protectedZeroForOne
            ? _downwardProtectedDomain(_tickQSeed, _widthSeed)
            : _upwardProtectedDomain(_tickQSeed, _widthSeed);

        uint160 sqrtPriceX96 = _priceInDomain(tickQ, tickO, _priceSeed);
        uint160 sqrtQX96 = TickMath.getSqrtPriceAtTick(tickQ);

        uint128 liquidity = uint128(bound(uint256(_liquiditySeed), 0, MAX_LIQUIDITY));
        uint128 deeper = uint128(bound(uint256(_extraSeed), uint256(liquidity), MAX_LIQUIDITY));

        assertLe(
            StandbyMath.supportingCapacity(_protectedZeroForOne, sqrtPriceX96, sqrtQX96, liquidity),
            StandbyMath.supportingCapacity(_protectedZeroForOne, sqrtPriceX96, sqrtQX96, deeper),
            "deeper liquidity must not reduce capacity"
        );
    }

    /// @notice Proves the generated bases are the valid ones the derivation is defined over.
    /// @dev A generator that drifted outside the closed domain, or produced a direction-inconsistent
    ///      boundary pair, would be exploring rejected bases while appearing to prove equivalence over
    ///      valid ones. This checks the generator itself.
    function testFuzz_generatedBases_areDirectionConsistentAndInsideTheDomain(
        int24 _tickQSeed,
        int24 _widthSeed,
        uint256 _priceSeed,
        bool _protectedZeroForOne
    ) public pure {
        (int24 tickQ, int24 tickO) = _protectedZeroForOne
            ? _downwardProtectedDomain(_tickQSeed, _widthSeed)
            : _upwardProtectedDomain(_tickQSeed, _widthSeed);

        assertTrue(
            ServiceDomain.isDirectionConsistent(_protectedZeroForOne, tickQ, tickO),
            "the generated boundaries must be direction-consistent"
        );

        uint160 sqrtPriceX96 = _priceInDomain(tickQ, tickO, _priceSeed);

        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) = ServiceDomain.sqrtBounds(tickQ, tickO);

        assertTrue(
            ServiceDomain.containsPrice(sqrtPriceX96, sqrtLowerX96, sqrtUpperX96),
            "the generated price must lie inside the closed domain"
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Generates a direction-consistent domain for a protected `zeroForOne` service.
    function _downwardProtectedDomain(int24 _tickQSeed, int24 _widthSeed)
        internal
        pure
        returns (int24 tickQ, int24 tickO)
    {
        tickQ = int24(bound(int256(_tickQSeed), TickMath.MIN_TICK, TickMath.MAX_TICK - 1));

        int24 maxWidth = TickMath.MAX_TICK - tickQ;
        int24 width =
            int24(bound(int256(_widthSeed), 1, int256(maxWidth < MAX_DOMAIN_WIDTH ? maxWidth : MAX_DOMAIN_WIDTH)));

        tickO = tickQ + width;
    }

    /// @dev Generates a direction-consistent domain for a protected `oneForZero` service.
    function _upwardProtectedDomain(int24 _tickQSeed, int24 _widthSeed)
        internal
        pure
        returns (int24 tickQ, int24 tickO)
    {
        tickQ = int24(bound(int256(_tickQSeed), TickMath.MIN_TICK + 1, TickMath.MAX_TICK));

        int24 maxWidth = tickQ - TickMath.MIN_TICK;
        int24 width =
            int24(bound(int256(_widthSeed), 1, int256(maxWidth < MAX_DOMAIN_WIDTH ? maxWidth : MAX_DOMAIN_WIDTH)));

        tickO = tickQ - width;
    }

    /// @dev Generates a square-root price inside the closed domain, in price space rather than tick space.
    ///
    ///      Generating the price directly in square-root space matters: a price generated from a tick
    ///      would only ever land on tick boundaries, and the rounding behavior worth exploring lives
    ///      between them.
    function _priceInDomain(int24 _tickQ, int24 _tickO, uint256 _priceSeed)
        internal
        pure
        returns (uint160 sqrtPriceX96)
    {
        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) = ServiceDomain.sqrtBounds(_tickQ, _tickO);

        sqrtPriceX96 = uint160(bound(_priceSeed, uint256(sqrtLowerX96), uint256(sqrtUpperX96)));
    }
}
