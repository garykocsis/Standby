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
/// @dev This library exists solely to check Standby's economics against a calculation that was derived
///      separately from the implementation under verification.
///
///      It must never be imported by production source, and it must never delegate the property it is
///      verifying to the implementation it is verifying. Concretely, the capacity oracle below performs
///      its own Q64.96 arithmetic instead of calling `SqrtPriceMath.getAmount1Delta`, which is the
///      primitive the later production Supporting Capacity derivation is expected to consume. It only
///      shares with production the pinned tick/price correspondence (`TickMath`) and full-precision
///      multiplication (`FullMath`), which are authoritative Uniswap definitions rather than Standby
///      economics.
///
///      At implementation slice F1 there is no production Supporting Capacity implementation at all, so
///      this oracle currently has nothing to defer to even accidentally.
library ReferenceCalculations {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev The Q64.96 fixed-point scale used by Uniswap square-root prices.
    uint256 internal constant Q96 = 1 << 96;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the current price already sits below the protected boundary.
    /// @dev The single-interval reference calculation is only meaningful while the price is at or above
    ///      the protected boundary; outside that range the oracle refuses to produce a number rather
    ///      than silently returning a wrong one.
    /// @param sqrtPriceX96 The authoritative current square-root price.
    /// @param sqrtBoundaryX96 The square-root price of the protected boundary.
    error ReferenceCalculations__PriceBelowProtectedBoundary(uint160 sqrtPriceX96, uint160 sqrtBoundaryX96);

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Independently derives protected capacity for a `zeroForOne` protected direction.
    /// @dev For a protected `zeroForOne` direction the protected output is currency1, and moving the
    ///      price from `_sqrtPriceX96` down to the boundary at `_tickQ` across one constant-liquidity
    ///      interval releases
    ///
    ///          amount1 = L * (sqrtP - sqrtQ) / 2^96
    ///
    ///      truncated toward zero, which is the conservative direction for a capacity claim.
    ///
    ///      This is valid only while `[tickQ, currentTick]` lies inside a single interval of constant
    ///      active liquidity. The canonical fixture guarantees that by placing every initialized
    ///      liquidity boundary strictly outside the service domain; a caller that does not guarantee it
    ///      must not use this oracle.
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
            revert ReferenceCalculations__PriceBelowProtectedBoundary(_sqrtPriceX96, sqrtBoundaryX96);
        }

        capacity = FullMath.mulDiv(uint256(_liquidity), uint256(_sqrtPriceX96 - sqrtBoundaryX96), Q96);
    }
}
