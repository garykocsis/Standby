// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {IEligibilityRegistry} from "../../src/interfaces/IEligibilityRegistry.sol";

import {BaseStandbyServiceTest} from "../shared/BaseStandbyServiceTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Fuzz evidence for the F3 service-geometry admission rules (G3-C 7..11).
/// @dev The canonical fixture proves one point of the geometry domain. These tests explore the domain
///      itself: arbitrary tick spacings, arbitrary aligned direction-relative boundaries anywhere in the
///      usable Uniswap tick range, and arbitrary current prices inside and outside the resulting closed
///      service domain.
///
///      Every run builds a real pool through `PoolManager.initialize` and exercises the production
///      activation path, so the current price the rules are judged against is always authoritative
///      PoolManager state. Runs use a fee distinct from the canonical fixture fee so each fuzzed pool is
///      a genuinely new pool rather than a re-initialization of the canonical one.
contract StandbyServiceGeometryFuzzTest is BaseStandbyServiceTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The tick spacing used by the tests that do not fuzz the spacing itself.
    int24 internal constant FUZZ_TICK_SPACING = 10;

    /*//////////////////////////////////////////////////////////////
                        ACCEPTED SERVICE GEOMETRY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves any aligned direction-relative domain containing the current price activates.
    /// @dev Both protected directions are explored, and the current price is free to land strictly
    ///      inside the domain or exactly on either boundary, because the domain is closed.
    function testFuzz_activation_acceptsAnyAlignedDomainContainingTheCurrentPrice(
        uint256 _spacingSeed,
        int256 _lowerSeed,
        int256 _upperSeed,
        int256 _priceSeed,
        bool _protectedZeroForOne
    ) public {
        (int24 tickSpacing, int24 lowerTick, int24 upperTick) =
            _boundAlignedDomain(_spacingSeed, _lowerSeed, _upperSeed);

        int24 initialTick = _boundInitialTickInside(_priceSeed, lowerTick, upperTick);

        (int24 tickQ, int24 tickO) = _protectedZeroForOne ? (lowerTick, upperTick) : (upperTick, lowerTick);

        PoolKey memory key = _fuzzPoolKey(tickSpacing);
        _initializePoolAtTick(key, initialTick);

        vm.prank(configurationAuthority);
        hook.configureAndActivate(
            key,
            _protectedZeroForOne,
            tickQ,
            tickO,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        StandbyHook.ProtectedExecutionService memory service = hook.protectedExecutionService();

        assertTrue(service.configured, "a contained aligned domain must activate");
        assertEq(service.tickQ, tickQ, "tickQ fidelity");
        assertEq(service.tickO, tickO, "tickO fidelity");
        assertEq(service.protectedZeroForOne, _protectedZeroForOne, "direction fidelity");
        assertEq(service.poolKey.tickSpacing, tickSpacing, "tick spacing fidelity");
    }

    /*//////////////////////////////////////////////////////////////
                        REJECTED SERVICE GEOMETRY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves boundaries ordered against the protected direction are always rejected.
    /// @dev The same numeric pair is valid for one direction and invalid for the other, which is what
    ///      makes `tickQ` and `tickO` direction-relative rather than numerically low and high.
    function testFuzz_activation_rejectsBoundariesOrderedAgainstTheProtectedDirection(
        uint256 _spacingSeed,
        int256 _lowerSeed,
        int256 _upperSeed,
        int256 _priceSeed,
        bool _protectedZeroForOne
    ) public {
        (int24 tickSpacing, int24 lowerTick, int24 upperTick) =
            _boundAlignedDomain(_spacingSeed, _lowerSeed, _upperSeed);

        int24 initialTick = _boundInitialTickInside(_priceSeed, lowerTick, upperTick);

        (int24 tickQ, int24 tickO) = _protectedZeroForOne ? (upperTick, lowerTick) : (lowerTick, upperTick);

        PoolKey memory key = _fuzzPoolKey(tickSpacing);
        _initializePoolAtTick(key, initialTick);

        vm.prank(configurationAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidServiceDomainOrder.selector, _protectedZeroForOne, tickQ, tickO
            )
        );
        hook.configureAndActivate(
            key,
            _protectedZeroForOne,
            tickQ,
            tickO,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves a boundary that is not aligned to the pool tick spacing is always rejected.
    function testFuzz_activation_rejectsBoundariesMisalignedToTheTickSpacing(
        uint256 _spacingSeed,
        int256 _lowerSeed,
        int256 _upperSeed,
        uint256 _offsetSeed,
        bool _perturbTickQ
    ) public {
        (int24 tickSpacing, int24 lowerTick, int24 upperTick) =
            _boundAlignedDomain(bound(_spacingSeed, 2, 200), _lowerSeed, _upperSeed);

        int24 offset = int24(int256(bound(_offsetSeed, 1, uint256(int256(tickSpacing)) - 1)));

        int24 tickQ = _perturbTickQ ? lowerTick + offset : lowerTick;
        int24 tickO = _perturbTickQ ? upperTick : upperTick - offset;

        int24 misalignedTick = _perturbTickQ ? tickQ : tickO;

        PoolKey memory key = _fuzzPoolKey(tickSpacing);
        _initializePoolAtTick(key, lowerTick);

        vm.prank(configurationAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(StandbyHook.StandbyHook__MisalignedServiceTick.selector, misalignedTick, tickSpacing)
        );
        hook.configureAndActivate(
            key, true, tickQ, tickO, IEligibilityRegistry(address(registry)), exerciseRouter, establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves a boundary outside the valid Uniswap tick range is always rejected.
    function testFuzz_activation_rejectsBoundariesOutsideTheValidTickRange(int256 _magnitudeSeed, bool _negative)
        public
    {
        int256 magnitude = bound(_magnitudeSeed, int256(TickMath.MAX_TICK) + 1, int256(type(int24).max));
        int24 invalidTick = int24(_negative ? -magnitude : magnitude);

        PoolKey memory key = _fuzzPoolKey(FUZZ_TICK_SPACING);
        _initializePoolAtTick(key, 0);

        vm.prank(configurationAuthority);
        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidServiceTick.selector, invalidTick));
        hook.configureAndActivate(
            key,
            true,
            _negative ? invalidTick : int24(0),
            _negative ? int24(0) : invalidTick,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves an authoritative current price outside the closed service domain is rejected.
    function testFuzz_activation_rejectsCurrentPriceOutsideTheServiceDomain(
        uint256 _spacingSeed,
        int256 _lowerSeed,
        int256 _upperSeed,
        int256 _priceSeed,
        bool _above
    ) public {
        (int24 tickSpacing, int24 lowerTick, int24 upperTick) =
            _boundAlignedDomainWithOutsideRoom(_spacingSeed, _lowerSeed, _upperSeed);

        int24 initialTick = _boundInitialTickOutside(_priceSeed, lowerTick, upperTick, _above);

        PoolKey memory key = _fuzzPoolKey(tickSpacing);
        _initializePoolAtTick(key, initialTick);

        vm.prank(configurationAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CurrentPriceOutsideServiceDomain.selector,
                TickMath.getSqrtPriceAtTick(initialTick),
                TickMath.getSqrtPriceAtTick(lowerTick),
                TickMath.getSqrtPriceAtTick(upperTick)
            )
        );
        hook.configureAndActivate(
            key,
            true,
            lowerTick,
            upperTick,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a fuzzed pool over the fixture currencies, bound to the production Hook, at a fee
    ///      distinct from the canonical fixture fee so every fuzzed pool is genuinely new.
    function _fuzzPoolKey(int24 _tickSpacing) internal view returns (PoolKey memory key) {
        key = _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, _tickSpacing);
    }

    /// @dev Bounds a tick spacing and a pair of spacing-aligned ticks inside the usable tick range.
    function _boundAlignedDomain(uint256 _spacingSeed, int256 _lowerSeed, int256 _upperSeed)
        internal
        pure
        returns (int24 tickSpacing, int24 lowerTick, int24 upperTick)
    {
        tickSpacing = int24(int256(bound(_spacingSeed, 1, 200)));

        int256 maxIndex = int256(TickMath.MAX_TICK / tickSpacing);

        int256 lowerIndex = bound(_lowerSeed, -maxIndex, maxIndex - 1);
        int256 upperIndex = bound(_upperSeed, lowerIndex + 1, maxIndex);

        lowerTick = int24(lowerIndex * int256(tickSpacing));
        upperTick = int24(upperIndex * int256(tickSpacing));
    }

    /// @dev Bounds an initializable current tick inside the closed domain, boundaries included.
    ///      `MAX_TICK` itself is excluded because its square-root price is not an initializable price.
    function _boundInitialTickInside(int256 _priceSeed, int24 _lowerTick, int24 _upperTick)
        internal
        pure
        returns (int24 initialTick)
    {
        int256 upperBound =
            int256(_upperTick) < int256(TickMath.MAX_TICK) ? int256(_upperTick) : int256(TickMath.MAX_TICK) - 1;

        initialTick = int24(bound(_priceSeed, int256(_lowerTick), upperBound));
    }

    /// @dev Bounds an aligned domain that always leaves at least one initializable tick on each side,
    ///      so a price strictly outside the domain exists in both directions.
    function _boundAlignedDomainWithOutsideRoom(uint256 _spacingSeed, int256 _lowerSeed, int256 _upperSeed)
        internal
        pure
        returns (int24 tickSpacing, int24 lowerTick, int24 upperTick)
    {
        tickSpacing = int24(int256(bound(_spacingSeed, 1, 200)));

        int256 maxIndex = int256(TickMath.MAX_TICK / tickSpacing);

        int256 lowerIndex = bound(_lowerSeed, -maxIndex + 1, maxIndex - 3);
        int256 upperIndex = bound(_upperSeed, lowerIndex + 1, maxIndex - 2);

        lowerTick = int24(lowerIndex * int256(tickSpacing));
        upperTick = int24(upperIndex * int256(tickSpacing));
    }

    /// @dev Bounds an initializable current tick strictly outside the closed domain.
    function _boundInitialTickOutside(int256 _priceSeed, int24 _lowerTick, int24 _upperTick, bool _above)
        internal
        pure
        returns (int24 initialTick)
    {
        if (_above) {
            initialTick = int24(bound(_priceSeed, int256(_upperTick) + 1, int256(TickMath.MAX_TICK) - 1));
        } else {
            initialTick = int24(bound(_priceSeed, int256(TickMath.MIN_TICK), int256(_lowerTick) - 1));
        }
    }
}
