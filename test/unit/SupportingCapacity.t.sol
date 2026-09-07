// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {TickMath} from "v4-core/libraries/TickMath.sol";

import {StandbyMath} from "../../src/libraries/StandbyMath.sol";

import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice An external caller for the pure capacity kernel, so its rejections can be asserted.
/// @dev `vm.expectRevert` observes external calls, and the kernel is an internal library function. This
///      wrapper adds nothing and decides nothing; it exists purely to give the call a boundary.
contract StandbyMathCaller {
    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calls the production Supporting Capacity kernel.
    /// @param _protectedZeroForOne The protected swap direction.
    /// @param _sqrtPriceX96 The square-root price to measure.
    /// @param _sqrtQX96 The square-root price of the capacity-exhaustion boundary.
    /// @param _liquidity The active liquidity to measure.
    /// @return capacity The Supporting Capacity.
    function supportingCapacity(bool _protectedZeroForOne, uint160 _sqrtPriceX96, uint160 _sqrtQX96, uint128 _liquidity)
        external
        pure
        returns (uint256 capacity)
    {
        capacity = StandbyMath.supportingCapacity(_protectedZeroForOne, _sqrtPriceX96, _sqrtQX96, _liquidity);
    }
}

/// @notice Unit evidence for the F5 Supporting Capacity kernel (G5-A, G5-F).
/// @dev This file covers the derivation itself: what the exact integer answer is for a given price,
///      boundary, direction, and liquidity, and what happens at and beyond the edges of its valid basis.
///      The composition around it — that the price comes from Slot0 rather than from the tick, that the
///      Hook's read resolves through this same kernel, and that the canonical fixture actually produces
///      80,000 MockUSDC — needs authoritative pool state and lives in the derivation integration suites.
///
///      Both protected directions are covered symmetrically throughout. `tickQ` is the capacity
///      exhaustion boundary in the protected direction, so it sits below the price for a protected
///      `zeroForOne` service and above it for a protected `oneForZero` one, and the protected output is
///      currency1 in the first case and currency0 in the second.
contract SupportingCapacityTest is Test {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    int24 internal constant TICK_Q_DOWN = -240;
    int24 internal constant TICK_O_DOWN = 240;

    int24 internal constant TICK_Q_UP = 240;
    int24 internal constant TICK_O_UP = -240;

    int24 internal constant INTERIOR_TICK = 0;

    uint128 internal constant LIQUIDITY = 6_707_079_990_254;

    StandbyMathCaller internal caller;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the external wrapper used to assert the kernel's rejections.
    function setUp() public {
        caller = new StandbyMathCaller();
    }

    /*//////////////////////////////////////////////////////////////
                     NORMATIVE EQUIVALENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves interior `zeroForOne` capacity equals the independent reference derivation.
    function test_zeroForOne_interiorCapacityEqualsIndependentReference() public pure {
        int24[5] memory probeTicks = [int24(-200), int24(-100), int24(0), int24(100), int24(200)];

        for (uint256 i = 0; i < probeTicks.length; ++i) {
            uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(probeTicks[i]);

            assertEq(
                StandbyMath.supportingCapacity(true, sqrtPriceX96, _sqrtAt(TICK_Q_DOWN), LIQUIDITY),
                ReferenceCalculations.referenceSupportingCapacity(true, sqrtPriceX96, TICK_Q_DOWN, LIQUIDITY),
                "downward-protected capacity must equal the independent reference"
            );
        }
    }

    /// @notice Proves interior `oneForZero` capacity equals the independent reference derivation.
    /// @dev The mirror case uses a different Uniswap primitive and a different argument order, so this is
    ///      not a restatement of the previous test: an implementation that used the currency1 amount for
    ///      both directions would pass one and fail this one.
    function test_oneForZero_interiorCapacityEqualsIndependentReference() public pure {
        int24[5] memory probeTicks = [int24(-200), int24(-100), int24(0), int24(100), int24(200)];

        for (uint256 i = 0; i < probeTicks.length; ++i) {
            uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(probeTicks[i]);

            assertEq(
                StandbyMath.supportingCapacity(false, sqrtPriceX96, _sqrtAt(TICK_Q_UP), LIQUIDITY),
                ReferenceCalculations.referenceSupportingCapacity(false, sqrtPriceX96, TICK_Q_UP, LIQUIDITY),
                "upward-protected capacity must equal the independent reference"
            );
        }
    }

    /// @notice Proves the two directions genuinely measure different currencies.
    /// @dev The probe is deliberately away from price parity. At a price of exactly 1 with boundaries the
    ///      same log-distance away, the currency0 and currency1 amounts coincide — the curve is symmetric
    ///      there — so parity is the one place this property cannot be observed. Away from it the two
    ///      answers separate, which is what shows the direction branch selects a currency rather than
    ///      merely a sign.
    function test_directions_measureDifferentProtectedOutputs() public pure {
        int24 probeTick = 1_000;

        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(probeTick);

        uint256 downward =
            StandbyMath.supportingCapacity(true, sqrtPriceX96, _sqrtAt(probeTick + TICK_Q_DOWN), LIQUIDITY);
        uint256 upward = StandbyMath.supportingCapacity(false, sqrtPriceX96, _sqrtAt(probeTick + TICK_Q_UP), LIQUIDITY);

        assertGt(downward, 0, "downward-protected capacity must be positive in the interior");
        assertGt(upward, 0, "upward-protected capacity must be positive in the interior");
        assertNotEq(downward, upward, "the two directions must measure different currencies");
    }

    /// @notice Records the parity coincidence explicitly, so it cannot be mistaken for a bug later.
    /// @dev At a price of exactly 1 with `P_Q` the same log-distance away in either direction, the two
    ///      protected-output amounts are equal. That is a property of the constant-product curve at
    ///      parity, not evidence that the derivation ignores direction — the preceding test shows it does
    ///      not.
    function test_directions_coincideOnlyAtPriceParity() public pure {
        uint160 sqrtPriceX96 = _sqrtAt(INTERIOR_TICK);

        assertEq(
            StandbyMath.supportingCapacity(true, sqrtPriceX96, _sqrtAt(TICK_Q_DOWN), LIQUIDITY),
            StandbyMath.supportingCapacity(false, sqrtPriceX96, _sqrtAt(TICK_Q_UP), LIQUIDITY),
            "the symmetric parity case is expected to coincide"
        );
    }

    /*//////////////////////////////////////////////////////////////
                           BOUNDARY BEHAVIOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves capacity falls monotonically as the price approaches `P_Q` from either direction.
    /// @dev Capacity is distance to the exhaustion boundary measured in protected output. Approaching the
    ///      boundary must consume it, and reaching it must exhaust it exactly.
    function test_capacity_decreasesMonotonicallyTowardPQ() public pure {
        int24[5] memory descending = [int24(240), int24(120), int24(0), int24(-120), int24(-240)];

        uint256 previousDownward = type(uint256).max;
        uint256 previousUpward;

        for (uint256 i = 0; i < descending.length; ++i) {
            uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(descending[i]);

            uint256 downward = StandbyMath.supportingCapacity(true, sqrtPriceX96, _sqrtAt(TICK_Q_DOWN), LIQUIDITY);
            uint256 upward = StandbyMath.supportingCapacity(false, sqrtPriceX96, _sqrtAt(TICK_Q_UP), LIQUIDITY);

            assertLt(downward, previousDownward, "downward-protected capacity must fall as price falls to P_Q");

            if (i > 0) assertGt(upward, previousUpward, "upward-protected capacity must rise as price falls from P_Q");

            previousDownward = downward;
            previousUpward = upward;
        }
    }

    /// @notice Proves capacity is exactly zero at `P_Q` in both directions.
    /// @dev This is an ordinary valid state, not an error. Whether backing still holds there is a
    ///      separate comparison against Aggregate Capacity Obligation.
    function test_capacity_isExactlyZeroAtPQ() public pure {
        assertEq(
            StandbyMath.supportingCapacity(true, _sqrtAt(TICK_Q_DOWN), _sqrtAt(TICK_Q_DOWN), LIQUIDITY),
            0,
            "downward-protected capacity is exhausted at P_Q"
        );
        assertEq(
            StandbyMath.supportingCapacity(false, _sqrtAt(TICK_Q_UP), _sqrtAt(TICK_Q_UP), LIQUIDITY),
            0,
            "upward-protected capacity is exhausted at P_Q"
        );
    }

    /// @notice Proves `P_O` is an accepted domain state carrying positive capacity.
    /// @dev `P_O` is the opposite realization-domain boundary, not a capacity boundary. Rejecting it, or
    ///      treating it as exhaustion, would confuse the two.
    function test_capacity_isPositiveAtPO() public pure {
        assertGt(
            StandbyMath.supportingCapacity(true, _sqrtAt(TICK_O_DOWN), _sqrtAt(TICK_Q_DOWN), LIQUIDITY),
            0,
            "downward-protected capacity is at its maximum at P_O"
        );
        assertGt(
            StandbyMath.supportingCapacity(false, _sqrtAt(TICK_O_UP), _sqrtAt(TICK_Q_UP), LIQUIDITY),
            0,
            "upward-protected capacity is at its maximum at P_O"
        );
    }

    /// @notice Proves zero liquidity never manufactures capacity, anywhere in the domain.
    function test_capacity_isZeroWithoutLiquidity() public pure {
        int24[3] memory probeTicks = [int24(-240), int24(0), int24(240)];

        for (uint256 i = 0; i < probeTicks.length; ++i) {
            uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(probeTicks[i]);

            assertEq(
                StandbyMath.supportingCapacity(true, sqrtPriceX96, _sqrtAt(TICK_Q_DOWN), 0),
                0,
                "no liquidity means no downward-protected capacity"
            );
            assertEq(
                StandbyMath.supportingCapacity(false, sqrtPriceX96, _sqrtAt(TICK_Q_UP), 0),
                0,
                "no liquidity means no upward-protected capacity"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                               ROUNDING
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves capacity is never rounded up, and that the choice is load-bearing.
    /// @dev A round-up convention would report one more unit of protected output than the pool can
    ///      actually deliver, which is precisely the overstatement backing must never make. The case
    ///      chosen here is one where the exact quotient is not an integer, so the two conventions
    ///      genuinely differ.
    function test_capacity_roundsDownWhereTheConventionsDiffer() public pure {
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(37);

        uint256 production = StandbyMath.supportingCapacity(true, sqrtPriceX96, _sqrtAt(TICK_Q_DOWN), LIQUIDITY);
        uint256 roundedDown = ReferenceCalculations.protectedCapacityZeroForOne(sqrtPriceX96, TICK_Q_DOWN, LIQUIDITY);
        uint256 roundedUp =
            ReferenceCalculations.protectedCapacityZeroForOneRoundedUp(sqrtPriceX96, TICK_Q_DOWN, LIQUIDITY);

        assertEq(roundedUp, roundedDown + 1, "the chosen case must actually distinguish the conventions");
        assertEq(production, roundedDown, "production must report the conservative amount");
    }

    /// @notice Proves the conservative convention holds across a range of prices.
    function test_capacity_neverExceedsTheRoundedUpAmount() public pure {
        for (int24 tick = -240; tick <= 240; tick += 17) {
            uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(tick);

            uint256 production = StandbyMath.supportingCapacity(true, sqrtPriceX96, _sqrtAt(TICK_Q_DOWN), LIQUIDITY);
            uint256 roundedUp =
                ReferenceCalculations.protectedCapacityZeroForOneRoundedUp(sqrtPriceX96, TICK_Q_DOWN, LIQUIDITY);

            assertLe(production, roundedUp, "capacity must never exceed the round-up amount");
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INVALID DERIVATION BASIS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a price beyond `P_Q` is refused rather than reported as capacity.
    /// @dev A downward-protected price below `P_Q` has passed the exhaustion boundary. That is not a
    ///      valid state with zero capacity — it is a state for which no authoritative Standby capacity
    ///      exists, and the two must not be confused.
    function test_capacity_refusesAPriceBeyondPQ() public {
        uint160 sqrtBelowQX96 = _sqrtAt(TICK_Q_DOWN) - 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyMath.StandbyMath__PriceBeyondCapacityBoundary.selector, true, sqrtBelowQX96, _sqrtAt(TICK_Q_DOWN)
            )
        );
        caller.supportingCapacity(true, sqrtBelowQX96, _sqrtAt(TICK_Q_DOWN), LIQUIDITY);

        uint160 sqrtAboveQX96 = _sqrtAt(TICK_Q_UP) + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyMath.StandbyMath__PriceBeyondCapacityBoundary.selector, false, sqrtAboveQX96, _sqrtAt(TICK_Q_UP)
            )
        );
        caller.supportingCapacity(false, sqrtAboveQX96, _sqrtAt(TICK_Q_UP), LIQUIDITY);
    }

    /// @notice Proves an invalid geometry is not rescued by swapping the price and the boundary.
    /// @dev The underlying Uniswap primitives sort their arguments, so a derivation that simply passed
    ///      them in whichever order avoided a revert would return a large, entirely fictitious capacity
    ///      for a state that has already left the protected side of the boundary. This shows the number
    ///      that reversal would have produced, and that production refuses instead of producing it.
    function test_capacity_doesNotManufactureCapacityFromReversedGeometry() public {
        uint160 sqrtBeyondQX96 = TickMath.getSqrtPriceAtTick(TICK_Q_DOWN - 120);

        uint256 fictitious =
            ReferenceCalculations.protectedCapacityZeroForOne(_sqrtAt(TICK_Q_DOWN), TICK_Q_DOWN - 120, LIQUIDITY);

        assertGt(fictitious, 0, "reversing the arguments would have produced a positive amount");

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyMath.StandbyMath__PriceBeyondCapacityBoundary.selector,
                true,
                sqrtBeyondQX96,
                _sqrtAt(TICK_Q_DOWN)
            )
        );
        caller.supportingCapacity(true, sqrtBeyondQX96, _sqrtAt(TICK_Q_DOWN), LIQUIDITY);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev The pinned square-root price of a tick.
    function _sqrtAt(int24 _tick) internal pure returns (uint160 sqrtPriceX96) {
        sqrtPriceX96 = TickMath.getSqrtPriceAtTick(_tick);
    }
}
