// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {BaseActorAwareStandbyTest} from "../shared/BaseActorAwareStandbyTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Behavioral fuzz evidence for ordinary O3 liquidity enforcement.
/// @dev Every run drives a real authoritative transition attempt through the trusted liquidity perimeter,
///      the real pinned `PoolManager`, and the production `StandbyHook`. No harness is involved.
///
///      The topology expectation is restated here from the frozen closed-domain rule rather than obtained
///      from the production classifier, so a run agrees with production only when production is right. An
///      oracle that asked the implementation what it thought would prove nothing.
contract O3LiquidityFuzzTest is BaseActorAwareStandbyTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The tick window explored, wide enough to cover positions inside, across, and outside the domain.
    int24 internal constant MIN_FUZZED_TICK = -600;
    int24 internal constant MAX_FUZZED_TICK = 600;

    /// @dev Upper bound on fuzzed position size, comfortably fundable by every fixture actor.
    uint128 internal constant MAX_FUZZED_LIQUIDITY = 1_000_000_000_000;

    /*//////////////////////////////////////////////////////////////
                          ADDITION PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice A liquidity addition becomes authoritative exactly when the actor is eligible and the
    ///         position introduces no initialized boundary strictly inside the service domain.
    /// @dev Both refusals are proven to be the specific ones, in the specific precedence the enforcement
    ///      sequence defines, so a run cannot pass because the transition failed for some unrelated reason.
    function testFuzz_liquidityAddition_isAdmittedExactlyWhenEligibleAndTopologyValid(
        bool _eligible,
        int24 _lowerSeed,
        int24 _upperSeed,
        uint128 _liquiditySeed
    ) public {
        (int24 tickLower, int24 tickUpper) = _boundedRange(_lowerSeed, _upperSeed);

        address actor = _eligible ? exitingProvider : ineligibleProvider;

        ModifyLiquidityParams memory params =
            _liquidityParams(tickLower, tickUpper, int256(uint256(_boundedLiquidity(_liquiditySeed))));

        (, int24 currentTick, uint128 liquidityBefore) = _servicePoolState();

        if (!_eligible) {
            _expectHookRejection(
                IHooks.beforeAddLiquidity.selector,
                abi.encodeWithSelector(StandbyHook.StandbyHook__LiquidityProviderNotEligible.selector, actor)
            );
            _modifyLiquidityAs(actor, params);
        } else if (_introducesInteriorBoundary(tickLower, tickUpper)) {
            _expectHookRejection(
                IHooks.beforeAddLiquidity.selector,
                abi.encodeWithSelector(
                    StandbyHook.StandbyHook__ProhibitedInteriorLiquidityBoundary.selector, tickLower, tickUpper
                )
            );
            _modifyLiquidityAs(actor, params);
        } else {
            _modifyLiquidityAs(actor, params);
        }

        (,, uint128 liquidityAfter) = _servicePoolState();

        bool admitted = _eligible && !_introducesInteriorBoundary(tickLower, tickUpper);
        bool active = currentTick >= tickLower && currentTick < tickUpper;

        uint256 expectedLiquidity = admitted && active
            ? uint256(liquidityBefore) + uint256(uint256(params.liquidityDelta))
            : uint256(liquidityBefore);

        assertEq(uint256(liquidityAfter), expectedLiquidity, "active liquidity must follow admission and activity");
        assertEq(hook.aggregateObligation(), 0, "no authentic obligation can exist");
    }

    /*//////////////////////////////////////////////////////////////
                           REMOVAL PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice A safe removal executes whatever the provider's current liquidity-action eligibility is, and
    ///         leaves exactly the state the production prospective-removal derivation predicted.
    /// @dev Eligibility is revoked on half the runs, after the position was contributed and before it is
    ///      withdrawn. Nothing about the outcome may depend on that: withdrawal is not a permissioned act,
    ///      and administration must not be able to trap contributed capital.
    function testFuzz_liquidityRemoval_isIndependentOfCurrentEligibility(
        bool _revokeBeforeExit,
        int24 _lowerSeed,
        int24 _upperSeed,
        uint128 _liquiditySeed,
        uint256 _removedFraction
    ) public {
        (int24 tickLower, int24 tickUpper) = _boundedDomainSpanningRange(_lowerSeed, _upperSeed);

        uint128 contributed = _boundedLiquidity(_liquiditySeed);

        _modifyLiquidityAs(exitingProvider, _liquidityParams(tickLower, tickUpper, int256(uint256(contributed))));

        if (_revokeBeforeExit) _setLiquidityEligibility(exitingProvider, false);

        uint128 removed = uint128(bound(_removedFraction, 1, contributed));

        ModifyLiquidityParams memory removal = _liquidityParams(tickLower, tickUpper, -int256(uint256(removed)));

        uint256 predictedCapacity = hook.prospectiveSupportingCapacityAfterLiquidityRemoval(removal);

        (,, uint128 liquidityBefore) = _servicePoolState();

        _modifyLiquidityAs(exitingProvider, removal);

        (,, uint128 liquidityAfter) = _servicePoolState();

        assertEq(
            uint256(liquidityAfter),
            uint256(liquidityBefore) - uint256(removed),
            "the removal must reach authoritative PoolManager state"
        );
        assertEq(hook.supportingCapacity(), predictedCapacity, "post-state capacity must equal the prediction");
        assertEq(hook.aggregateObligation(), 0, "no authentic obligation can exist");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Restates the frozen closed-domain topology rule independently of the production classifier.
    function _introducesInteriorBoundary(int24 _tickLower, int24 _tickUpper) internal pure returns (bool introduces) {
        int24 domainLower = StandbyFixtureConfig.TICK_Q;
        int24 domainUpper = StandbyFixtureConfig.TICK_O;

        introduces = (_tickLower > domainLower && _tickLower < domainUpper)
            || (_tickUpper > domainLower && _tickUpper < domainUpper);
    }

    /// @dev Bounds a fuzzed tick pair to an ordered, tick-spacing-aligned range in the explored window.
    function _boundedRange(int24 _lowerSeed, int24 _upperSeed)
        internal
        pure
        returns (int24 tickLower, int24 tickUpper)
    {
        tickLower = _alignTick(
            int24(bound(int256(_lowerSeed), MIN_FUZZED_TICK, MAX_FUZZED_TICK - StandbyFixtureConfig.TICK_SPACING))
        );
        tickUpper =
            _alignTick(int24(bound(int256(_upperSeed), tickLower + StandbyFixtureConfig.TICK_SPACING, MAX_FUZZED_TICK)));

        if (tickUpper <= tickLower) tickUpper = tickLower + StandbyFixtureConfig.TICK_SPACING;
    }

    /// @dev Bounds a fuzzed tick pair to a topology-valid range that spans the whole service domain.
    ///
    ///      Both endpoints are kept outside the open service interval, so every run in the removal property
    ///      is a position the enforcement path admits and that is active at the canonical price. The
    ///      question under test there is what removal does, not whether the position could exist.
    function _boundedDomainSpanningRange(int24 _lowerSeed, int24 _upperSeed)
        internal
        pure
        returns (int24 tickLower, int24 tickUpper)
    {
        tickLower = _alignTick(int24(bound(int256(_lowerSeed), MIN_FUZZED_TICK, StandbyFixtureConfig.TICK_Q)));
        tickUpper = _alignTick(int24(bound(int256(_upperSeed), StandbyFixtureConfig.TICK_O, MAX_FUZZED_TICK)));
    }

    /// @dev Rounds a tick down onto the canonical tick spacing, as Uniswap's own tick compression does.
    ///
    ///      Solidity truncates division toward zero, so a negative tick needs the extra step to round down
    ///      rather than up. The result stays inside the explored window because the window's own bounds are
    ///      tick-spacing multiples.
    function _alignTick(int24 _tick) internal pure returns (int24 aligned) {
        int24 spacing = StandbyFixtureConfig.TICK_SPACING;

        int24 quotient = _tick / spacing;

        if (_tick < 0 && quotient * spacing != _tick) --quotient;

        aligned = quotient * spacing;
    }

    /// @dev Bounds a fuzzed position size to a fundable, nonzero amount.
    function _boundedLiquidity(uint128 _liquiditySeed) internal pure returns (uint128 liquidity) {
        liquidity = uint128(_bound(uint256(_liquiditySeed), 1, MAX_FUZZED_LIQUIDITY));
    }
}
