// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {FullMath} from "v4-core/libraries/FullMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

/*//////////////////////////////////////////////////////////////
                             LIBRARIES
//////////////////////////////////////////////////////////////*/

/// @title ReferenceCalculations
/// @notice Independent verification oracle for Standby economic quantities.
/// @dev This library exists solely to check Standby's economics against a calculation that was composed
///      separately from the implementation under verification.
///
///      It must never be imported by production source, and it must never delegate the property it is
///      verifying to the implementation it is verifying. Concretely, nothing here calls `StandbyMath` or
///      `ServiceDomain`, and the capacity oracles perform their own Q64.96 arithmetic instead of calling
///      the `SqrtPriceMath` primitives production consumes. The commitment oracles are written from the
///      frozen conditional form of the derivations rather than from production's branch structure, so a
///      production branch that was inverted or a comparison that was made inclusive would disagree here.
///
///      What it does share with production is the pinned tick/price correspondence (`TickMath`) and
///      full-precision multiplication (`FullMath`). Those are authoritative Uniswap definitions rather
///      than Standby economics: independently reimplementing Uniswap would verify nothing about Standby
///      and would introduce a second definition of the pool itself.
///
///      Prospective-state derivations are deliberately absent. Their correct oracle is not a second
///      calculation at all — it is the state real PoolManager execution produces for the same transition,
///      which the differential tests obtain by executing it.
library ReferenceCalculations {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev The Q64.96 fixed-point scale used by Uniswap square-root prices.
    uint256 internal constant Q96 = 1 << 96;

    /// @dev The number of compressed ticks one Uniswap tick-bitmap word holds.
    int256 internal constant WORD_SIZE = 256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the price sits on the far side of the protected boundary.
    /// @dev The single-interval reference calculation is only meaningful while the price is on the
    ///      capacity-bearing side of `P_Q`; outside that range the oracle refuses to produce a number
    ///      rather than silently returning a wrong one.
    /// @param sqrtPriceX96 The authoritative current square-root price.
    /// @param sqrtBoundaryX96 The square-root price of the protected boundary.
    error ReferenceCalculations__PriceBeyondProtectedBoundary(uint160 sqrtPriceX96, uint160 sqrtBoundaryX96);

    /*//////////////////////////////////////////////////////////////
                       COMMITMENT DERIVATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Independently derives temporal validity.
    /// @dev Written as the negation of the ended condition: validity has ceased once the current time has
    ///      reached `validUntil`, so at exactly `validUntil` the entitlement is already invalid.
    /// @param _validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param _timestamp The current time.
    /// @return valid Whether the entitlement is temporally valid.
    function referenceValid(uint64 _validUntil, uint256 _timestamp) internal pure returns (bool valid) {
        valid = !(_timestamp >= uint256(_validUntil));
    }

    /// @notice Independently derives temporal exercise qualification.
    /// @dev The conjunction of "the window has opened" and "validity has not ended", each written as the
    ///      negation of its failing condition.
    /// @param _exercisableFrom The admitted timestamp from which exercise may become possible.
    /// @param _validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param _timestamp The current time.
    /// @return qualified Whether the current time lies in the admitted exercise window.
    function referenceTemporallyExerciseQualified(uint64 _exercisableFrom, uint64 _validUntil, uint256 _timestamp)
        internal
        pure
        returns (bool qualified)
    {
        bool windowOpened = !(_timestamp < uint256(_exercisableFrom));

        qualified = windowOpened && referenceValid(_validUntil, _timestamp);
    }

    /// @notice Independently derives irreversible release from Capacity Obligation.
    /// @dev The two frozen irreversible causes, written positively: nothing is left to fulfil, or validity
    ///      is over.
    /// @param _remainingEntitlement The unfulfilled remainder.
    /// @param _validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param _timestamp The current time.
    /// @return nonBinding Whether the commitment is permanently released.
    function referencePermanentlyNonBinding(uint128 _remainingEntitlement, uint64 _validUntil, uint256 _timestamp)
        internal
        pure
        returns (bool nonBinding)
    {
        bool exhausted = !(_remainingEntitlement > 0);
        bool expired = !referenceValid(_validUntil, _timestamp);

        nonBinding = exhausted || expired;
    }

    /// @notice Independently derives the Capacity Obligation of one commitment.
    /// @dev Written from the frozen equivalent form — obligation is the Remaining Entitlement exactly when
    ///      that remainder is positive and validity has not ended — rather than from the production
    ///      branch order.
    /// @param _remainingEntitlement The unfulfilled remainder.
    /// @param _validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param _timestamp The current time.
    /// @return obligation The Capacity Obligation, in raw protected-output units.
    function referenceCommitmentObligation(uint128 _remainingEntitlement, uint64 _validUntil, uint256 _timestamp)
        internal
        pure
        returns (uint256 obligation)
    {
        bool binding = _remainingEntitlement > 0 && referenceValid(_validUntil, _timestamp);

        obligation = binding ? uint256(_remainingEntitlement) : 0;
    }

    /// @notice Independently derives Aggregate Capacity Obligation over a referenced set.
    /// @dev The caller supplies the referenced commitments' facts directly, so the oracle never learns the
    ///      bounded index layout and cannot inherit an ordering assumption from it.
    /// @param _remainingEntitlements The unfulfilled remainder of each referenced commitment.
    /// @param _validUntils The validity end of each referenced commitment, positionally matched.
    /// @param _timestamp The current time.
    /// @return obligation The Aggregate Capacity Obligation.
    function referenceAggregateObligation(
        uint128[] memory _remainingEntitlements,
        uint64[] memory _validUntils,
        uint256 _timestamp
    ) internal pure returns (uint256 obligation) {
        for (uint256 i = 0; i < _remainingEntitlements.length; ++i) {
            obligation += referenceCommitmentObligation(_remainingEntitlements[i], _validUntils[i], _timestamp);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          SUPPORTING CAPACITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Independently derives Supporting Capacity for either protected direction.
    /// @dev Dispatches on the configured protected direction alone. Currency identity, currency ordering,
    ///      and decimal precision are never consulted, and the result is in raw units of whichever
    ///      currency the protected direction makes the output.
    /// @param _protectedZeroForOne The protected swap direction of the service.
    /// @param _sqrtPriceX96 The authoritative square-root price.
    /// @param _tickQ The protected execution-quality boundary tick.
    /// @param _liquidity The active liquidity.
    /// @return capacity The Supporting Capacity, in raw protected-output units.
    function referenceSupportingCapacity(
        bool _protectedZeroForOne,
        uint160 _sqrtPriceX96,
        int24 _tickQ,
        uint128 _liquidity
    ) internal pure returns (uint256 capacity) {
        capacity = _protectedZeroForOne
            ? protectedCapacityZeroForOne(_sqrtPriceX96, _tickQ, _liquidity)
            : protectedCapacityOneForZero(_sqrtPriceX96, _tickQ, _liquidity);
    }

    /// @notice Independently derives protected capacity for a `zeroForOne` protected direction.
    /// @dev For a protected `zeroForOne` direction the protected output is currency1, and moving the
    ///      price from `_sqrtPriceX96` down to the boundary at `_tickQ` across one constant-liquidity
    ///      interval releases
    ///
    ///          amount1 = L * (sqrtP - sqrtQ) / 2^96
    ///
    ///      truncated toward zero, which is the conservative direction for a capacity claim.
    ///
    ///      This is valid only while the path from the boundary to the current price lies inside a single
    ///      interval of constant active liquidity. Every fixture that uses this oracle guarantees that by
    ///      placing the initialized liquidity boundaries at or outside the service domain; a caller that
    ///      does not guarantee it must not use this oracle.
    /// @param _sqrtPriceX96 The authoritative current square-root price read from PoolManager state.
    /// @param _tickQ The protected execution-quality boundary tick.
    /// @param _liquidity The authoritative active liquidity read from PoolManager state.
    /// @return capacity The protected capacity, in raw units of currency1.
    function protectedCapacityZeroForOne(uint160 _sqrtPriceX96, int24 _tickQ, uint128 _liquidity)
        internal
        pure
        returns (uint256 capacity)
    {
        uint160 sqrtBoundaryX96 = TickMath.getSqrtPriceAtTick(_tickQ);

        if (_sqrtPriceX96 < sqrtBoundaryX96) {
            revert ReferenceCalculations__PriceBeyondProtectedBoundary(_sqrtPriceX96, sqrtBoundaryX96);
        }

        capacity = FullMath.mulDiv(uint256(_liquidity), uint256(_sqrtPriceX96 - sqrtBoundaryX96), Q96);
    }

    /// @notice Independently derives protected capacity for a `oneForZero` protected direction.
    /// @dev The mirror case. The protected output is currency0, the protected direction moves the price
    ///      up toward `tickQ`, and moving from `_sqrtPriceX96` up to that boundary across one
    ///      constant-liquidity interval releases
    ///
    ///          amount0 = L * 2^96 * (sqrtQ - sqrtP) / (sqrtQ * sqrtP)
    ///
    ///      truncated toward zero. The division is performed in the same two stages Uniswap performs it
    ///      in — divide by the larger square-root price, then by the smaller — because that staging is
    ///      part of the exact integer quantity RR-SC-1 names, not an incidental detail of it.
    /// @param _sqrtPriceX96 The authoritative current square-root price read from PoolManager state.
    /// @param _tickQ The protected execution-quality boundary tick.
    /// @param _liquidity The authoritative active liquidity read from PoolManager state.
    /// @return capacity The protected capacity, in raw units of currency0.
    function protectedCapacityOneForZero(uint160 _sqrtPriceX96, int24 _tickQ, uint128 _liquidity)
        internal
        pure
        returns (uint256 capacity)
    {
        uint160 sqrtBoundaryX96 = TickMath.getSqrtPriceAtTick(_tickQ);

        if (_sqrtPriceX96 > sqrtBoundaryX96) {
            revert ReferenceCalculations__PriceBeyondProtectedBoundary(_sqrtPriceX96, sqrtBoundaryX96);
        }

        if (_sqrtPriceX96 == 0) return 0;

        uint256 scaledLiquidity = uint256(_liquidity) * Q96;
        uint256 priceGap = uint256(sqrtBoundaryX96) - uint256(_sqrtPriceX96);

        capacity = FullMath.mulDiv(scaledLiquidity, priceGap, uint256(sqrtBoundaryX96)) / uint256(_sqrtPriceX96);
    }

    /// @notice Independently derives the round-up counterpart of a `zeroForOne` capacity.
    /// @dev Used only to demonstrate that the conservative convention is actually load-bearing: where the
    ///      two differ, production must report the smaller one.
    /// @param _sqrtPriceX96 The authoritative current square-root price.
    /// @param _tickQ The protected execution-quality boundary tick.
    /// @param _liquidity The authoritative active liquidity.
    /// @return capacity The round-up capacity, in raw units of currency1.
    function protectedCapacityZeroForOneRoundedUp(uint160 _sqrtPriceX96, int24 _tickQ, uint128 _liquidity)
        internal
        pure
        returns (uint256 capacity)
    {
        uint160 sqrtBoundaryX96 = TickMath.getSqrtPriceAtTick(_tickQ);

        if (_sqrtPriceX96 < sqrtBoundaryX96) {
            revert ReferenceCalculations__PriceBeyondProtectedBoundary(_sqrtPriceX96, sqrtBoundaryX96);
        }

        capacity = FullMath.mulDivRoundingUp(uint256(_liquidity), uint256(_sqrtPriceX96 - sqrtBoundaryX96), Q96);
    }

    /*//////////////////////////////////////////////////////////////
                        SERVICE-DOMAIN GEOMETRY
    //////////////////////////////////////////////////////////////*/

    /// @notice Independently classifies a square-root price against the closed service domain.
    /// @dev Composed from the boundary ticks rather than from precomputed bounds, and written as the
    ///      negation of the two ways a price can escape the interval.
    /// @param _sqrtPriceX96 The square-root price to classify.
    /// @param _tickQ The protected execution-quality boundary.
    /// @param _tickO The opposite realization-domain boundary.
    /// @return contained Whether the price lies inside the domain or exactly on either boundary.
    function referenceDomainContainsPrice(uint160 _sqrtPriceX96, int24 _tickQ, int24 _tickO)
        internal
        pure
        returns (bool contained)
    {
        uint160 sqrtQX96 = TickMath.getSqrtPriceAtTick(_tickQ);
        uint160 sqrtOX96 = TickMath.getSqrtPriceAtTick(_tickO);

        (uint160 low, uint160 high) = sqrtQX96 < sqrtOX96 ? (sqrtQX96, sqrtOX96) : (sqrtOX96, sqrtQX96);

        contained = !(_sqrtPriceX96 < low) && !(_sqrtPriceX96 > high);
    }

    /// @notice Independently derives the prospective traversal demand of a service domain.
    /// @dev Uniswap advances a swap one tick-bitmap word at a time whenever the word holds no initialized
    ///      tick in the searched direction, because the search returns that word's own edge. The demand a
    ///      domain implies is therefore the number of words it occupies, plus one conditional step for the
    ///      downward worst case in which the numeric top carries an initialized boundary the price starts
    ///      on: v4 spends one step crossing it without moving, and a second on the same word. A top that
    ///      compresses onto a word edge cannot cost that, because the crossing step already leaves the
    ///      word.
    ///
    ///      The independence here is in the construction, not the conclusion. Where production reaches the
    ///      word index through the pinned `TickBitmap` compression and its arithmetic shift, this reaches
    ///      it through explicit floor division written from the same v4 semantics, so an error in either
    ///      one's handling of negative ticks — the case where truncating and flooring division part
    ///      company — would show up as disagreement rather than as a shared mistake.
    /// @param _tickQ The protected execution-quality boundary.
    /// @param _tickO The opposite realization-domain boundary.
    /// @param _tickSpacing The authoritative pool tick spacing.
    /// @return demand The greatest number of swap steps a supported in-domain path can require.
    function referenceProspectiveTraversalDemand(int24 _tickQ, int24 _tickO, int24 _tickSpacing)
        internal
        pure
        returns (uint256 demand)
    {
        (int256 low, int256 high) =
            _tickQ < _tickO ? (int256(_tickQ), int256(_tickO)) : (int256(_tickO), int256(_tickQ));

        int256 lowCompressed = _floorDiv(low, int256(_tickSpacing));
        int256 highCompressed = _floorDiv(high, int256(_tickSpacing));

        int256 lowWord = _floorDiv(lowCompressed, WORD_SIZE);
        int256 highWord = _floorDiv(highCompressed, WORD_SIZE);

        demand = uint256(highWord - lowWord) + 1;

        if (highCompressed - highWord * WORD_SIZE != 0) ++demand;
    }

    /// @notice Independently classifies whether a liquidity range has an endpoint inside the domain.
    /// @dev Endpoints exactly on a configured boundary are permitted, so only the open interval counts.
    /// @param _tickLower The lower endpoint of the liquidity range.
    /// @param _tickUpper The upper endpoint of the liquidity range.
    /// @param _tickQ The protected execution-quality boundary.
    /// @param _tickO The opposite realization-domain boundary.
    /// @return introduces Whether either endpoint lies strictly inside the configured domain.
    function referenceIntroducesInteriorBoundary(int24 _tickLower, int24 _tickUpper, int24 _tickQ, int24 _tickO)
        internal
        pure
        returns (bool introduces)
    {
        (int24 low, int24 high) = _tickQ < _tickO ? (_tickQ, _tickO) : (_tickO, _tickQ);

        bool lowerInside = !(_tickLower <= low) && !(_tickLower >= high);
        bool upperInside = !(_tickUpper <= low) && !(_tickUpper >= high);

        introduces = lowerInside || upperInside;
    }

    /*//////////////////////////////////////////////////////////////
                         PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Division rounding toward negative infinity, for a positive divisor.
    ///
    ///      Solidity divides toward zero, which disagrees with the flooring Uniswap uses for both tick
    ///      compression and word indexing everywhere the numerator is negative. Writing the correction
    ///      explicitly is the point: negative tick regions are exactly where a traversal-demand
    ///      calculation is easiest to get subtly wrong.
    function _floorDiv(int256 _numerator, int256 _divisor) private pure returns (int256 quotient) {
        quotient = _numerator / _divisor;

        if (_numerator % _divisor != 0 && _numerator < 0) --quotient;
    }
}
