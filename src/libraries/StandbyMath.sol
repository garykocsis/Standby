// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BitMath} from "v4-core/libraries/BitMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {TickBitmap} from "v4-core/libraries/TickBitmap.sol";

/*//////////////////////////////////////////////////////////////
                             LIBRARIES
//////////////////////////////////////////////////////////////*/

/// @title StandbyMath
/// @notice The pure Standby derivation kernel: what authoritative facts mean, expressed once.
/// @dev Every function here takes facts it is handed and returns a derived meaning. The library reads no
///      PoolManager state, reads no Hook storage, scans no enforcement references, consults no
///      EligibilityRegistry, authenticates nobody, persists nothing, and authorizes no transition. The
///      Hook is the composition owner: it obtains the authoritative facts and decides what a derived
///      value implies.
///
///      The library is the single production home of these derivations. Nothing else in production may
///      re-express validity, temporal exercise qualification, permanent non-binding classification,
///      commitment obligation, or the Supporting Capacity formula. Independent duplication is required
///      only across the production/test boundary, in the verification oracle.
///
///      Where an authoritative Uniswap definition already exists it is consumed rather than restated:
///      `SqrtPriceMath` defines the output-to-boundary amounts of RR-SC-1, and `TickBitmap`/`BitMath`
///      define how v4 itself selects the next swap-step target. Restating those would create a second
///      definition of Uniswap, not an independent Standby one.
library StandbyMath {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when Supporting Capacity is requested from a price on the far side of `P_Q`.
    /// @dev A price beyond the capacity-exhaustion boundary in the protected direction is not a valid
    ///      domain state with zero capacity; it is a state for which no authoritative Standby Supporting
    ///      Capacity exists. Reversing the square-root arguments would manufacture a plausible positive
    ///      number out of an invalid basis, so the derivation refuses instead.
    /// @param protectedZeroForOne The protected swap direction of the service.
    /// @param sqrtPriceX96 The square-root price the derivation was asked about.
    /// @param sqrtQX96 The square-root price of the capacity-exhaustion boundary.
    error StandbyMath__PriceBeyondCapacityBoundary(bool protectedZeroForOne, uint160 sqrtPriceX96, uint160 sqrtQX96);

    /*//////////////////////////////////////////////////////////////
                       COMMITMENT DERIVATIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Derives temporal validity: an entitlement is valid strictly before `validUntil`.
    ///
    ///      At `t == validUntil` validity is already false. The comparison is deliberately strict.
    /// @param _validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param _timestamp The authoritative current time.
    /// @return valid Whether the entitlement is temporally valid.
    function isValid(uint64 _validUntil, uint256 _timestamp) internal pure returns (bool valid) {
        valid = _timestamp < _validUntil;
    }

    /// @dev Derives the temporal half of exercise qualification, and nothing else.
    ///
    ///      This predicate is temporal only. Beneficiary eligibility, exercise authority, caller identity,
    ///      router state, capacity sufficiency, and every other exercise condition are owned by the
    ///      exercise slice and are deliberately absent, so that nothing can mistake this for a complete
    ///      exercisability answer.
    /// @param _exercisableFrom The admitted timestamp from which exercise may become possible.
    /// @param _validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param _timestamp The authoritative current time.
    /// @return qualified Whether the current time lies in the admitted exercise window.
    function isTemporallyExerciseQualified(uint64 _exercisableFrom, uint64 _validUntil, uint256 _timestamp)
        internal
        pure
        returns (bool qualified)
    {
        qualified = _timestamp >= _exercisableFrom && _timestamp < _validUntil;
    }

    /// @dev Derives irreversible release from Capacity Obligation.
    ///
    ///      The MVP has exactly two irreversible causes: entitlement exhausted through qualifying
    ///      fulfillment, and validity ended at `validUntil`. Both are permanent, so a commitment
    ///      satisfying either can never again impose positive Capacity Obligation.
    ///
    ///      This is the shared semantic predicate behind both zero obligation and later reference
    ///      reclaimability. Temporary conditions — a window that has not opened, a Beneficiary that is
    ///      currently ineligible, a caller without exercise authority, capacity that is presently too
    ///      small — are not causes and must never be routed through here.
    /// @param _remainingEntitlement The authoritative unfulfilled remainder.
    /// @param _validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param _timestamp The authoritative current time.
    /// @return nonBinding Whether the commitment is permanently released from Capacity Obligation.
    function isPermanentlyNonBinding(uint128 _remainingEntitlement, uint64 _validUntil, uint256 _timestamp)
        internal
        pure
        returns (bool nonBinding)
    {
        nonBinding = _remainingEntitlement == 0 || _timestamp >= _validUntil;
    }

    /// @dev Derives the current Capacity Obligation of one commitment.
    ///
    ///      A permanently non-binding commitment imposes nothing; every other commitment imposes its full
    ///      Remaining Entitlement. A valid entitlement therefore imposes its obligation from the moment it
    ///      is admitted, before `exercisableFrom` and while its Beneficiary is temporarily ineligible
    ///      alike: binding is not exercisability, and temporary non-exercisability never releases backing.
    ///
    ///      Expiry produces zero obligation without touching Remaining Entitlement, so an expired
    ///      commitment keeps its historical unfulfilled remainder visible while imposing nothing.
    /// @param _remainingEntitlement The authoritative unfulfilled remainder.
    /// @param _validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param _timestamp The authoritative current time.
    /// @return obligation The Capacity Obligation, in raw units of the protected output currency.
    function commitmentObligation(uint128 _remainingEntitlement, uint64 _validUntil, uint256 _timestamp)
        internal
        pure
        returns (uint256 obligation)
    {
        obligation =
            isPermanentlyNonBinding(_remainingEntitlement, _validUntil, _timestamp) ? 0 : uint256(_remainingEntitlement);
    }

    /*//////////////////////////////////////////////////////////////
                          SUPPORTING CAPACITY
    //////////////////////////////////////////////////////////////*/

    /// @dev Derives Supporting Capacity from an exact square-root price and an active liquidity.
    ///
    ///      Supporting Capacity is the greatest representable protected-output amount executable from the
    ///      given state to the direction-relative capacity-exhaustion boundary `P_Q`, across one interval
    ///      of constant active liquidity (RR-SC-1). It is not inventory, TVL, a token balance, nominal
    ///      liquidity, or a reserved allocation, and nothing is segregated to produce it.
    ///
    ///      The protected output currency follows from the protected direction alone: currency1 for
    ///      protected `zeroForOne`, currency0 for protected `oneForZero`. Currency identity and decimal
    ///      precision are never consulted, and the result is expressed in raw units of that currency, so
    ///      it stays directly comparable with Capacity Obligation without any protocol-wide
    ///      normalization.
    ///
    ///      Rounding is always down. Overstating executable output by even one unit would let backing
    ///      pass on capacity that cannot actually be delivered.
    ///
    ///      At `P_Q` capacity is exactly zero, which is an ordinary valid domain state; whether backing
    ///      still holds there is a separate comparison against Aggregate Capacity Obligation. Zero
    ///      liquidity likewise yields zero rather than manufacturing capacity.
    /// @param _protectedZeroForOne The protected swap direction of the service.
    /// @param _sqrtPriceX96 The exact authoritative square-root price of the state being measured.
    /// @param _sqrtQX96 The square-root price of the capacity-exhaustion boundary `P_Q`.
    /// @param _liquidity The active liquidity of the state being measured.
    /// @return capacity The Supporting Capacity, in raw units of the protected output currency.
    function supportingCapacity(bool _protectedZeroForOne, uint160 _sqrtPriceX96, uint160 _sqrtQX96, uint128 _liquidity)
        internal
        pure
        returns (uint256 capacity)
    {
        if (_protectedZeroForOne) {
            if (_sqrtPriceX96 < _sqrtQX96) {
                revert StandbyMath__PriceBeyondCapacityBoundary(_protectedZeroForOne, _sqrtPriceX96, _sqrtQX96);
            }

            capacity = SqrtPriceMath.getAmount1Delta(_sqrtQX96, _sqrtPriceX96, _liquidity, false);
        } else {
            if (_sqrtPriceX96 > _sqrtQX96) {
                revert StandbyMath__PriceBeyondCapacityBoundary(_protectedZeroForOne, _sqrtPriceX96, _sqrtQX96);
            }

            capacity = SqrtPriceMath.getAmount0Delta(_sqrtPriceX96, _sqrtQX96, _liquidity, false);
        }
    }

    /*//////////////////////////////////////////////////////////////
                       PROSPECTIVE-STATE PRIMITIVES
    //////////////////////////////////////////////////////////////*/

    /// @dev Reports whether a liquidity range is active at a current tick, by the v4 convention.
    ///
    ///      Uniswap v4 counts a position toward active liquidity exactly when
    ///      `tickLower <= currentTick < tickUpper`, and this must agree with that convention exactly: an
    ///      active removal changes active liquidity and therefore Supporting Capacity, an inactive one
    ///      changes neither.
    /// @param _currentTick The authoritative current pool tick.
    /// @param _tickLower The lower endpoint of the liquidity range.
    /// @param _tickUpper The upper endpoint of the liquidity range.
    /// @return active Whether the range contributes to current active liquidity.
    function isActiveRange(int24 _currentTick, int24 _tickLower, int24 _tickUpper)
        internal
        pure
        returns (bool active)
    {
        active = _currentTick >= _tickLower && _currentTick < _tickUpper;
    }

    /// @dev Derives the active liquidity a removal would leave behind.
    ///
    ///      Removing an inactive position leaves active liquidity untouched. Removing an active one
    ///      reduces it by exactly the removed amount; the subtraction is checked, so a removal larger
    ///      than the active liquidity is refused rather than wrapping into a fabricated capacity.
    ///
    ///      The square-root price is not a parameter because a removal cannot move it.
    /// @param _liquidity The authoritative current active liquidity.
    /// @param _currentTick The authoritative current pool tick.
    /// @param _tickLower The lower endpoint of the removed range.
    /// @param _tickUpper The upper endpoint of the removed range.
    /// @param _removedLiquidity The liquidity being removed from the range.
    /// @return prospectiveLiquidity The active liquidity after the removal.
    function liquidityAfterRemoval(
        uint128 _liquidity,
        int24 _currentTick,
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _removedLiquidity
    ) internal pure returns (uint128 prospectiveLiquidity) {
        prospectiveLiquidity =
            isActiveRange(_currentTick, _tickLower, _tickUpper) ? _liquidity - _removedLiquidity : _liquidity;
    }

    /*//////////////////////////////////////////////////////////////
                        V4 SWAP-STEP TRAVERSAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Locates the tick-bitmap word a v4 swap step would consult, and the bit it starts from.
    ///
    ///      This mirrors the pinned `TickBitmap.nextInitializedTickWithinOneWord` entry conditions
    ///      exactly, including the asymmetry between the two search directions: a downward search starts
    ///      at the compressed current tick, an upward search starts at the tick after it because the
    ///      current tick's own state is irrelevant when moving up.
    ///
    ///      It is split out from the search itself because the word lives in PoolManager storage and this
    ///      library never reads PoolManager. The Hook fetches the word this identifies and hands it back.
    /// @param _tick The tick the swap step starts from.
    /// @param _tickSpacing The authoritative pool tick spacing.
    /// @param _lte Whether the search moves down (`zeroForOne`) rather than up.
    /// @return wordPos The tick-bitmap word to read.
    /// @return compressed The compressed tick the search starts from.
    /// @return bitPos The bit within the word the search starts from.
    function bitmapSearchPosition(int24 _tick, int24 _tickSpacing, bool _lte)
        internal
        pure
        returns (int16 wordPos, int24 compressed, uint8 bitPos)
    {
        unchecked {
            compressed = TickBitmap.compress(_tick, _tickSpacing);

            if (!_lte) ++compressed;

            (wordPos, bitPos) = TickBitmap.position(compressed);
        }
    }

    /// @dev Derives the next swap-step target tick from a tick-bitmap word.
    ///
    ///      This reproduces the pinned `TickBitmap.nextInitializedTickWithinOneWord` search, including
    ///      its defining behavior: when the word holds no initialized tick in the searched direction it
    ///      returns the *edge of the word*, not the current tick, and reports it uninitialized. Uniswap
    ///      therefore splits a swap at word edges even where no liquidity boundary exists, and a
    ///      prospective derivation that ignored those splits would disagree with real execution by the
    ///      rounding of every skipped step.
    ///
    ///      It is reproduced rather than called because the pinned function takes a storage mapping that
    ///      only PoolManager can provide. The unchecked arithmetic is part of the reproduction: the
    ///      pinned implementation relies on it, and matching it is the point.
    /// @param _word The tick-bitmap word identified by `bitmapSearchPosition`.
    /// @param _compressed The compressed tick the search starts from.
    /// @param _bitPos The bit within the word the search starts from.
    /// @param _tickSpacing The authoritative pool tick spacing.
    /// @param _lte Whether the search moves down (`zeroForOne`) rather than up.
    /// @return next The next candidate target tick.
    /// @return initialized Whether that tick carries an initialized liquidity boundary.
    function nextTickWithinOneWord(uint256 _word, int24 _compressed, uint8 _bitPos, int24 _tickSpacing, bool _lte)
        internal
        pure
        returns (int24 next, bool initialized)
    {
        unchecked {
            if (_lte) {
                uint256 mask = type(uint256).max >> (uint256(type(uint8).max) - _bitPos);
                uint256 masked = _word & mask;

                initialized = masked != 0;
                next = initialized
                    ? (_compressed - int24(uint24(_bitPos - BitMath.mostSignificantBit(masked)))) * _tickSpacing
                    : (_compressed - int24(uint24(_bitPos))) * _tickSpacing;
            } else {
                // All the ones at or to the left of `_bitPos`. The pinned implementation writes this as
                // `~((1 << bitPos) - 1)`, which is the same mask.
                uint256 mask = type(uint256).max << _bitPos;
                uint256 masked = _word & mask;

                initialized = masked != 0;
                next = initialized
                    ? (_compressed + int24(uint24(BitMath.leastSignificantBit(masked) - _bitPos))) * _tickSpacing
                    : (_compressed + int24(uint24(type(uint8).max - _bitPos))) * _tickSpacing;
            }
        }
    }
}
