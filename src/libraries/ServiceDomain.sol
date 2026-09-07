// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {TickBitmap} from "v4-core/libraries/TickBitmap.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

/*//////////////////////////////////////////////////////////////
                             LIBRARIES
//////////////////////////////////////////////////////////////*/

/// @title ServiceDomain
/// @notice Pure geometry and topology of the configured Standby service domain.
/// @dev This library owns one thing: what the two configured boundary ticks mean as a shape in tick and
///      square-root price space. It reads no PoolManager state, holds no commitment state, consults no
///      registry, derives no obligation, and decides no transition. A caller that learns from it that a
///      price sits outside the domain, or that a liquidity range would put an initialized boundary inside
///      it, still owns what to do about that — the Hook owns the consequence of a classification.
///
///      Two directional facts are frozen by `uniswap-v4-realization.md` RR-SC-5 and must survive every
///      use of this library. `tickQ` is the protected execution-quality boundary *in the protected
///      direction*, not a numerically low position, and `tickO` is the opposite realization-domain
///      boundary. For protected `zeroForOne` the protected direction moves the price down, so
///      `tickQ < tickO`; for protected `oneForZero` it moves the price up, so `tickQ > tickO`. Numeric
///      minimum and maximum are used only where geometric containment genuinely needs an interval, and
///      the direction-relative meanings are never collapsed into "lower" and "upper".
///
///      The domain is closed (RR-SC-6): both boundaries belong to it.
library ServiceDomain {
    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Reports whether the boundary pair is ordered as the protected direction requires.
    ///
    ///      Equality is rejected in both directions: a degenerate domain has no interior, so it could
    ///      not carry the single-active-region capacity model the realization depends on.
    /// @param _protectedZeroForOne The protected swap direction.
    /// @param _tickQ The protected execution-quality boundary.
    /// @param _tickO The opposite realization-domain boundary.
    /// @return consistent Whether the pair is direction-consistent.
    function isDirectionConsistent(bool _protectedZeroForOne, int24 _tickQ, int24 _tickO)
        internal
        pure
        returns (bool consistent)
    {
        consistent = _protectedZeroForOne ? _tickQ < _tickO : _tickQ > _tickO;
    }

    /// @dev Returns the numeric tick interval the two boundaries span, irrespective of direction.
    ///
    ///      This is the containment shape only. It deliberately says nothing about which endpoint is
    ///      `P_Q`; a caller that needs the capacity-exhaustion boundary must use `tickQ` itself.
    /// @param _tickQ The protected execution-quality boundary.
    /// @param _tickO The opposite realization-domain boundary.
    /// @return lowerTick The numerically lower boundary.
    /// @return upperTick The numerically upper boundary.
    function numericBounds(int24 _tickQ, int24 _tickO) internal pure returns (int24 lowerTick, int24 upperTick) {
        (lowerTick, upperTick) = _tickQ < _tickO ? (_tickQ, _tickO) : (_tickO, _tickQ);
    }

    /// @dev Returns the numeric square-root price interval of the configured domain.
    ///
    ///      Containment is evaluated in square-root price space rather than tick space because a current
    ///      tick equal to a boundary tick does not imply a current price at or inside that boundary's
    ///      price.
    /// @param _tickQ The protected execution-quality boundary.
    /// @param _tickO The opposite realization-domain boundary.
    /// @return sqrtLowerX96 The square-root price of the numerically lower boundary.
    /// @return sqrtUpperX96 The square-root price of the numerically upper boundary.
    function sqrtBounds(int24 _tickQ, int24 _tickO)
        internal
        pure
        returns (uint160 sqrtLowerX96, uint160 sqrtUpperX96)
    {
        (int24 lowerTick, int24 upperTick) = numericBounds(_tickQ, _tickO);

        sqrtLowerX96 = TickMath.getSqrtPriceAtTick(lowerTick);
        sqrtUpperX96 = TickMath.getSqrtPriceAtTick(upperTick);
    }

    /// @dev Reports whether a square-root price lies within the closed configured domain.
    /// @param _sqrtPriceX96 The square-root price to classify.
    /// @param _sqrtLowerX96 The square-root price of the numerically lower boundary.
    /// @param _sqrtUpperX96 The square-root price of the numerically upper boundary.
    /// @return contained Whether the price is inside the domain or exactly on either boundary.
    function containsPrice(uint160 _sqrtPriceX96, uint160 _sqrtLowerX96, uint160 _sqrtUpperX96)
        internal
        pure
        returns (bool contained)
    {
        contained = _sqrtPriceX96 >= _sqrtLowerX96 && _sqrtPriceX96 <= _sqrtUpperX96;
    }

    /// @dev Reports whether a liquidity range would place an initialized boundary strictly inside the
    ///      configured domain.
    ///
    ///      RR-SC-6 permits a position whose endpoints equal the configured boundaries or lie entirely
    ///      outside them, and excludes only an endpoint in the open interval. That is what keeps the
    ///      supported price path inside one interval of constant active liquidity, which is the topology
    ///      the Supporting Capacity and prospective-state derivations are built on.
    ///
    ///      This is a classification, not a rejection: the transition slice that owns liquidity admission
    ///      decides what follows from it.
    /// @param _tickLower The lower endpoint of the liquidity range.
    /// @param _tickUpper The upper endpoint of the liquidity range.
    /// @param _tickQ The protected execution-quality boundary.
    /// @param _tickO The opposite realization-domain boundary.
    /// @return introduces Whether either endpoint lies strictly inside the configured domain.
    function introducesInteriorBoundary(int24 _tickLower, int24 _tickUpper, int24 _tickQ, int24 _tickO)
        internal
        pure
        returns (bool introduces)
    {
        (int24 lowerTick, int24 upperTick) = numericBounds(_tickQ, _tickO);

        introduces =
            (_tickLower > lowerTick && _tickLower < upperTick) || (_tickUpper > lowerTick && _tickUpper < upperTick);
    }

    /// @dev Derives the greatest number of Uniswap v4 swap steps any supported in-domain path can require.
    ///
    ///      Absence of an initialized liquidity boundary strictly inside the domain guarantees a stable
    ///      active-liquidity region. It does not guarantee that v4 reaches the far side in one arithmetic
    ///      step, because `nextInitializedTickWithinOneWord` searches a single tick-bitmap word: when a
    ///      word holds no initialized tick in the searched direction it returns that word's own edge and
    ///      reports it uninitialized, so v4 advances one word per step whether or not any liquidity
    ///      boundary exists. Traversal demand is therefore a function of how many bitmap words the domain
    ///      spans, which depends on the boundary ticks and the pool tick spacing together.
    ///
    ///      The count is the number of words the numeric domain occupies, plus one conditional step. The
    ///      extra step is the downward traversal's worst case: if the numeric top of the domain carries an
    ///      initialized boundary — which the closed-domain topology permits, since a liquidity endpoint
    ///      may sit exactly on a configured boundary — and the price starts there, v4 spends one step
    ///      crossing that tick without moving, and then a second step on the same word. That cannot happen
    ///      when the top compresses onto a word edge, because the crossing step already leaves the word,
    ///      so the extra step is charged only when it does not.
    ///
    ///      Upward traversal is never the binding case: its search skips the starting tick, so it can
    ///      never spend the crossing step, and it visits no more words.
    ///
    ///      This is a realization-topology fact, not an economic one. It says nothing about capacity,
    ///      obligation, or backing, and the caller owns what to do with it.
    /// @param _tickQ The protected execution-quality boundary.
    /// @param _tickO The opposite realization-domain boundary.
    /// @param _tickSpacing The authoritative pool tick spacing.
    /// @return steps The greatest number of swap steps a supported in-domain path can require.
    function prospectiveTraversalDemand(int24 _tickQ, int24 _tickO, int24 _tickSpacing)
        internal
        pure
        returns (uint256 steps)
    {
        (int24 lowerTick, int24 upperTick) = numericBounds(_tickQ, _tickO);

        (int16 lowerWord,) = TickBitmap.position(TickBitmap.compress(lowerTick, _tickSpacing));
        (int16 upperWord, uint8 upperBit) = TickBitmap.position(TickBitmap.compress(upperTick, _tickSpacing));

        steps = uint256(int256(upperWord) - int256(lowerWord)) + 1;

        if (upperBit != 0) ++steps;
    }
}
