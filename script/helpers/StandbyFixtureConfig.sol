// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                             LIBRARIES
//////////////////////////////////////////////////////////////*/

/// @title StandbyFixtureConfig
/// @notice The frozen numerical values of the canonical deterministic Standby demonstration fixture.
/// @dev These are fixture / test / demo constants only. They define one reproducible demonstration
///      configuration; they are not general Standby protocol requirements and they are not production
///      economic state.
///
///      In particular `EXPECTED_INITIAL_S` is an expected output of the canonical fixture's
///      authoritative integer derivation. It must never become authoritative production economic state,
///      a production derivation, or an input to one. Production Supporting Capacity is derived from
///      authoritative Uniswap v4 state by a later implementation slice, and this constant exists only so
///      an independent verification oracle has a frozen expected value to be checked against.
///
///      No production contract may read this library.
library StandbyFixtureConfig {
    /*//////////////////////////////////////////////////////////////
                          CURRENCY IDENTITY
    //////////////////////////////////////////////////////////////*/

    /// @dev The decimal precision of both canonical fixture currencies.
    uint8 internal constant CURRENCY_DECIMALS = 6;

    /// @dev The canonical protected direction of the fixture: MockUSTB (currency0) -> MockUSDC
    ///      (currency1). This is a fixture fact. Standby must not assume zeroForOne is always protected.
    bool internal constant PROTECTED_DIRECTION_ZERO_FOR_ONE = true;

    /*//////////////////////////////////////////////////////////////
                            POOL TOPOLOGY
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical initial pool tick: raw-decimal parity between the two fixture currencies.
    int24 internal constant INITIAL_TICK = 0;

    /// @dev The protected execution-quality boundary in the protected direction.
    int24 internal constant TICK_Q = -240;

    /// @dev The opposite realization-domain boundary.
    int24 internal constant TICK_O = 240;

    /// @dev The lower boundary of the canonical LP position, outside the service domain.
    int24 internal constant LP_TICK_LOWER = -300;

    /// @dev The upper boundary of the canonical LP position, outside the service domain.
    int24 internal constant LP_TICK_UPPER = 300;

    /// @dev The canonical pool tick spacing.
    int24 internal constant TICK_SPACING = 10;

    /// @dev The canonical static LP fee, in pips: 500 pips / 0.05%.
    uint24 internal constant LP_FEE = 500;

    /// @dev The canonical active liquidity spanning the complete service domain.
    uint128 internal constant CANONICAL_LIQUIDITY = 6_707_079_990_254;

    /*//////////////////////////////////////////////////////////////
                       EXPECTED FIXTURE ECONOMICS
    //////////////////////////////////////////////////////////////*/

    /// @dev The expected initial Supporting Capacity of the canonical fixture, in raw MockUSDC units:
    ///      80,000.000000 MockUSDC. Expected verification value only — never production truth.
    uint256 internal constant EXPECTED_INITIAL_S = 80_000_000_000;

    /// @dev The canonical commitment entitlement q: 50,000.000000 MockUSDC.
    uint256 internal constant CANONICAL_COMMITMENT_Q = 50_000_000_000;

    /// @dev The canonical backing-compatible ordinary protected swap output: 15,000.000000 MockUSDC.
    uint256 internal constant COMPATIBLE_ORDINARY_SWAP_OUTPUT = 15_000_000_000;

    /// @dev The canonical backing-destructive protected swap attempt: 20,000.000000 MockUSDC.
    uint256 internal constant DESTRUCTIVE_SWAP_OUTPUT_ATTEMPT = 20_000_000_000;
}
