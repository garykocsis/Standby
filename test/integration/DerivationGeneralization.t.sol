// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {TickMath} from "v4-core/libraries/TickMath.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {ServiceDomain} from "../../src/libraries/ServiceDomain.sol";

import {BaseDerivationTest} from "../shared/BaseDerivationTest.t.sol";
import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Fixture and decimal generalization evidence for the F5 derivation kernel (G5-A, G5-C, G5-F).
/// @dev The canonical fixture is one configuration, and a derivation that were correct only for it would
///      be a property of that fixture rather than of Standby. Every claim here is therefore made across
///      three real, independently deployed services: the canonical one, a protected `oneForZero` service
///      with eighteen- and eight-decimal currencies, and a protected `zeroForOne` service with the
///      decimals reversed, a different tick spacing, a different fee, and liquidity boundaries sitting
///      exactly on the configured service boundaries.
///
///      The decimal precisions are the point of the second and third configurations. Supporting Capacity
///      and Capacity Obligation are both raw amounts of the protected output currency, which is what makes
///      them directly comparable without any protocol-wide normalization, so production must never consult
///      `decimals()`. The sharper form of that claim — two services identical in every respect but
///      precision, deriving identical raw answers — is made by the matched-pair fixture below.
contract DerivationGeneralizationTest is BaseDerivationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The frozen expected initial Supporting Capacity of the canonical fixture, restated here
    ///      independently of the fixture configuration library: 80,000.000000 MockUSDC.
    uint256 internal constant FROZEN_CANONICAL_INITIAL_S = 80_000 * 10 ** 6;

    DeployedService internal canonical;
    DeployedService internal upwardProtected;
    DeployedService internal reversedDecimals;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Builds three real, independently configured Standby services.
    function setUp() public virtual override {
        super.setUp();

        canonical = _deployService(_canonicalConfig());
        upwardProtected = _deployService(_upwardProtectedConfig());
        reversedDecimals = _deployService(_reversedDecimalsConfig());
    }

    /*//////////////////////////////////////////////////////////////
                    CANONICAL FIXTURE ECONOMICS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the canonical fixture derives exactly 80,000 MockUSDC of Supporting Capacity.
    /// @dev The expected value is an independent economic fact about the fixture, fixed before any
    ///      production derivation existed. It is asserted against the constant, against the independent
    ///      oracle applied to the actual pool state, and against the production read — in that order, so
    ///      the production result is compared with something derived without it.
    function test_canonicalFixture_derivesEightyThousandProtectedOutputUnits() public view {
        (uint160 sqrtPriceX96,, uint128 liquidity) = _poolState(canonical);

        uint256 referenceCapacity = ReferenceCalculations.referenceSupportingCapacity(
            canonical.config.protectedZeroForOne, sqrtPriceX96, canonical.config.tickQ, liquidity
        );

        assertEq(referenceCapacity, FROZEN_CANONICAL_INITIAL_S, "the independent reference must be 80,000.000000");
        assertEq(canonical.hook.supportingCapacity(), referenceCapacity, "production must equal the reference");
    }

    /// @notice Proves the canonical service was built through the real production activation transition.
    /// @dev The capacity above is only meaningful if the service it belongs to is authoritative. This
    ///      reads the persisted service basis back and confirms it is the canonical one.
    function test_canonicalFixture_isBuiltOnAnAuthoritativeActivatedService() public view {
        StandbyHook.ProtectedExecutionService memory basis = canonical.hook.protectedExecutionService();

        assertTrue(basis.configured, "the service must be activated");
        assertEq(basis.tickQ, canonical.config.tickQ, "the persisted P_Q boundary must be canonical");
        assertEq(basis.tickO, canonical.config.tickO, "the persisted P_O boundary must be canonical");
        assertTrue(basis.protectedZeroForOne, "the canonical protected direction must be zeroForOne");
    }

    /*//////////////////////////////////////////////////////////////
                    G5-C — CONFIGURATION GENERALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves every configuration derives capacity equal to the independent reference.
    /// @dev Three services, two protected directions, three decimal pairings, three tick layouts, three
    ///      fees, and two tick spacings, all measured through the same production read.
    function test_everyConfiguration_derivesCapacityEqualToTheIndependentReference() public view {
        _assertCapacityEqualsReference(canonical, "canonical");
        _assertCapacityEqualsReference(upwardProtected, "upward-protected");
        _assertCapacityEqualsReference(reversedDecimals, "reversed-decimals");
    }

    /// @notice Proves every activated configuration lies inside the supported traversal bound.
    /// @dev Activation now refuses a domain whose prospective state could not be derived within the
    ///      bound, so an activated service is by construction one whose every supported in-domain path is
    ///      derivable. Stating it across three genuinely different configurations — different spacings,
    ///      different widths, both directions — shows the admission rule holds as a property of activated
    ///      services rather than as an accident of one fixture.
    function test_everyActivatedConfiguration_liesWithinTheSupportedTraversalBound() public view {
        _assertWithinTraversalBound(canonical, "canonical");
        _assertWithinTraversalBound(upwardProtected, "upward-protected");
        _assertWithinTraversalBound(reversedDecimals, "reversed-decimals");
    }

    /// @notice Proves the configurations really are the different ones they claim to be.
    /// @dev A generalization suite that accidentally built three copies of the same service would prove
    ///      nothing, so the differences are asserted rather than assumed.
    function test_configurations_differInDirectionDecimalsTicksAndSpacing() public view {
        assertTrue(canonical.config.protectedZeroForOne, "the canonical service is protected downward");
        assertFalse(upwardProtected.config.protectedZeroForOne, "the second service is protected upward");
        assertTrue(reversedDecimals.config.protectedZeroForOne, "the third service is protected downward");

        assertEq(canonical.currency0.decimals(), 6, "the canonical currencies are six-decimal");
        assertEq(canonical.currency1.decimals(), 6, "the canonical currencies are six-decimal");

        assertEq(upwardProtected.currency0.decimals(), 18, "the second service uses an eighteen-decimal currency0");
        assertEq(upwardProtected.currency1.decimals(), 8, "the second service uses an eight-decimal currency1");

        assertEq(reversedDecimals.currency0.decimals(), 8, "the third service reverses the precisions");
        assertEq(reversedDecimals.currency1.decimals(), 18, "the third service reverses the precisions");

        assertNotEq(canonical.config.tickSpacing, upwardProtected.config.tickSpacing, "tick spacings must differ");
        assertNotEq(canonical.config.lpFee, upwardProtected.config.lpFee, "fees must differ");
        assertNotEq(
            uint256(canonical.config.liquidity), uint256(upwardProtected.config.liquidity), "liquidity must differ"
        );
    }

    /// @notice Proves capacity is denominated in the currency the protected direction selects.
    /// @dev For a protected `oneForZero` service the protected output is currency0, so capacity must be
    ///      the currency0 amount executable to `P_Q`. Comparing against the currency1 oracle for the same
    ///      state shows the two are genuinely different quantities and that production reports the right
    ///      one.
    function test_capacity_isDenominatedInTheProtectedOutputCurrency() public view {
        (uint160 sqrtPriceX96,, uint128 liquidity) = _poolState(upwardProtected);

        uint256 protectedOutput =
            ReferenceCalculations.protectedCapacityOneForZero(sqrtPriceX96, upwardProtected.config.tickQ, liquidity);

        assertEq(upwardProtected.hook.supportingCapacity(), protectedOutput, "capacity must be the currency0 amount");

        uint256 oppositeCurrencyAmount =
            ReferenceCalculations.protectedCapacityZeroForOne(sqrtPriceX96, upwardProtected.config.tickO, liquidity);

        assertNotEq(protectedOutput, oppositeCurrencyAmount, "the two currency amounts must genuinely differ");
    }

    /*//////////////////////////////////////////////////////////////
                     AUTHORITATIVE PRICE SOURCING
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the exact Slot0 square-root price is used, not a price rebuilt from the tick.
    /// @dev After an ordinary swap the price almost never sits on a tick boundary. A derivation that
    ///      reconstructed the price from the current tick would silently round the whole basis down to
    ///      that boundary. Here the reconstructed answer is computed explicitly, shown to differ, and
    ///      production is shown to agree with the exact one.
    function test_capacity_usesTheExactSlot0PriceRatherThanTheTickPrice() public {
        _swap(canonical, _swapToTickLimit(true, -17_777_777_777, canonical.config.tickQ));

        (uint160 sqrtPriceX96, int24 tick, uint128 liquidity) = _poolState(canonical);

        uint160 sqrtPriceAtTickX96 = TickMath.getSqrtPriceAtTick(tick);

        assertNotEq(sqrtPriceX96, sqrtPriceAtTickX96, "the swap must leave the price between tick boundaries");

        uint256 exactCapacity =
            ReferenceCalculations.referenceSupportingCapacity(true, sqrtPriceX96, canonical.config.tickQ, liquidity);
        uint256 tickRoundedCapacity = ReferenceCalculations.referenceSupportingCapacity(
            true, sqrtPriceAtTickX96, canonical.config.tickQ, liquidity
        );

        assertNotEq(exactCapacity, tickRoundedCapacity, "the two price sources must give different answers here");
        assertEq(canonical.hook.supportingCapacity(), exactCapacity, "production must use the exact Slot0 price");
    }

    /// @notice Proves the production read and the capacity kernel are the same derivation.
    /// @dev Measuring the authoritative present state through the state-parameterised kernel must give
    ///      exactly what the read gives. If the read had its own formula, this is where the two would
    ///      part company.
    function test_capacityRead_resolvesThroughTheSameKernelAsProspectiveMeasurement() public view {
        (uint160 sqrtPriceX96,, uint128 liquidity) = _poolState(canonical);

        assertEq(
            canonical.hook.supportingCapacity(),
            canonical.hook.supportingCapacityFromState(sqrtPriceX96, liquidity),
            "the read and the kernel must be one derivation"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     G5-F — INVALID DERIVATION BASIS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a present state outside the service domain yields no capacity, not zero capacity.
    /// @dev The pool is driven past `P_Q`, which the enforcement slice will later prevent but which is
    ///      reachable today because no enforcement exists. The read must then refuse: an ordinary zero
    ///      would present a violated realization domain as a merely exhausted one.
    function test_capacity_refusesAPresentStateOutsideTheServiceDomain() public {
        _swap(canonical, _swapToTickLimit(true, -1_000_000_000_000, canonical.config.lpTickLower));

        (uint160 sqrtPriceX96,,) = _poolState(canonical);

        assertLt(
            sqrtPriceX96, TickMath.getSqrtPriceAtTick(canonical.config.tickQ), "the pool must have left the domain"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CurrentPriceOutsideServiceDomain.selector,
                sqrtPriceX96,
                TickMath.getSqrtPriceAtTick(canonical.config.tickQ),
                TickMath.getSqrtPriceAtTick(canonical.config.tickO)
            )
        );
        canonical.hook.supportingCapacity();
    }

    /// @notice Proves capacity at `P_O` is an ordinary positive answer.
    /// @dev `P_O` is inside the closed domain and is the capacity maximum, not an edge to be rejected.
    function test_capacity_isPositiveAtThePOBoundary() public {
        _swap(canonical, _swapToTickLimit(false, -1_000_000_000_000, canonical.config.tickO));

        (uint160 sqrtPriceX96,,) = _poolState(canonical);

        assertEq(sqrtPriceX96, TickMath.getSqrtPriceAtTick(canonical.config.tickO), "the pool must rest exactly at P_O");
        assertGt(canonical.hook.supportingCapacity(), FROZEN_CANONICAL_INITIAL_S, "capacity is at its maximum at P_O");
    }

    /// @notice Proves an unconfigured Hook reports no capacity at all.
    /// @dev Without a service there is no protected direction, no boundary, and no pool — so there is no
    ///      capacity to report rather than a capacity of zero.
    function test_capacity_revertsBeforeAServiceExists() public {
        StandbyHook unconfigured = _deployDerivationHarness();

        vm.expectRevert(StandbyHook.StandbyHook__ServiceNotConfigured.selector);
        unconfigured.supportingCapacity();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev A protected `oneForZero` service with heterogeneous eighteen- and eight-decimal currencies.
    function _upwardProtectedConfig() internal pure returns (ServiceConfig memory config) {
        config = ServiceConfig({
            decimals0: 18,
            decimals1: 8,
            protectedZeroForOne: false,
            initialTick: 0,
            tickQ: 1_200,
            tickO: -600,
            lpTickLower: -1_200,
            lpTickUpper: 1_800,
            tickSpacing: 60,
            lpFee: 3_000,
            liquidity: 1_000_000_000_000_000
        });
    }

    /// @dev A protected `zeroForOne` service with the precisions reversed and boundary-aligned liquidity.
    ///
    ///      Its liquidity endpoints sit exactly on the configured service boundaries, which RR-SC-6
    ///      permits and which the enclosing canonical position does not exercise.
    function _reversedDecimalsConfig() internal pure returns (ServiceConfig memory config) {
        config = ServiceConfig({
            decimals0: 8,
            decimals1: 18,
            protectedZeroForOne: true,
            initialTick: -300,
            tickQ: -1_500,
            tickO: 750,
            lpTickLower: -1_500,
            lpTickUpper: 750,
            tickSpacing: 1,
            lpFee: 100,
            liquidity: 500_000_000_000_000
        });
    }

    /// @dev Asserts one activated service's traversal demand is within the supported bound, and that the
    ///      production classifier agrees with the independent reference about what that demand is.
    function _assertWithinTraversalBound(DeployedService memory _service, string memory _context) internal view {
        uint256 demand = ServiceDomain.prospectiveTraversalDemand(
            _service.config.tickQ, _service.config.tickO, _service.config.tickSpacing
        );

        assertEq(
            demand,
            ReferenceCalculations.referenceProspectiveTraversalDemand(
                _service.config.tickQ, _service.config.tickO, _service.config.tickSpacing
            ),
            _context
        );
        assertLe(demand, _service.hook.MAX_PROSPECTIVE_SWAP_STEPS(), _context);
    }

    /// @dev Asserts one service's production capacity equals the independent reference over actual state.
    function _assertCapacityEqualsReference(DeployedService memory _service, string memory _context) internal view {
        (uint160 sqrtPriceX96,, uint128 liquidity) = _poolState(_service);

        assertEq(
            _service.hook.supportingCapacity(),
            ReferenceCalculations.referenceSupportingCapacity(
                _service.config.protectedZeroForOne, sqrtPriceX96, _service.config.tickQ, liquidity
            ),
            _context
        );
    }
}

/// @notice Decimal-independence evidence for the F5 derivation kernel (G5-C).
/// @dev Kept in its own fixture because the claim needs a matched pair of services and nothing else: two
///      Standby services with the identical protected direction, boundaries, tick spacing, fee, liquidity
///      position, and liquidity, differing only in the decimal precision their currencies report.
///
///      Supporting Capacity and Capacity Obligation are raw amounts of the protected output currency,
///      which is exactly what lets them be compared without any protocol-wide normalization. The
///      derivation therefore has no business consulting `decimals()`, and if it did, these two services —
///      one six-and-six, one eighteen-and-eight — would report answers many orders of magnitude apart.
contract DerivationDecimalIndependenceTest is BaseDerivationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The frozen expected initial Supporting Capacity of the canonical geometry, restated here
    ///      independently of the fixture configuration library: 80,000.000000 raw protected-output units.
    uint256 internal constant FROZEN_CANONICAL_INITIAL_S = 80_000 * 10 ** 6;

    DeployedService internal sixAndSix;
    DeployedService internal eighteenAndEight;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Builds two geometrically identical services whose currencies differ only in precision.
    function setUp() public virtual override {
        super.setUp();

        ServiceConfig memory matched = _canonicalConfig();

        sixAndSix = _deployService(matched);

        matched.decimals0 = 18;
        matched.decimals1 = 8;

        eighteenAndEight = _deployService(matched);
    }

    /*//////////////////////////////////////////////////////////////
                       G5-C — DECIMAL INDEPENDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the two services really do differ only in decimal precision.
    function test_matchedServices_differOnlyInDecimalPrecision() public view {
        assertEq(sixAndSix.currency0.decimals(), 6, "the first service is six-and-six");
        assertEq(sixAndSix.currency1.decimals(), 6, "the first service is six-and-six");
        assertEq(eighteenAndEight.currency0.decimals(), 18, "the second service is eighteen-and-eight");
        assertEq(eighteenAndEight.currency1.decimals(), 8, "the second service is eighteen-and-eight");

        assertEq(sixAndSix.config.tickQ, eighteenAndEight.config.tickQ, "the boundaries must match");
        assertEq(sixAndSix.config.tickO, eighteenAndEight.config.tickO, "the boundaries must match");
        assertEq(
            sixAndSix.config.protectedZeroForOne,
            eighteenAndEight.config.protectedZeroForOne,
            "the protected direction must match"
        );

        (uint160 sqrtPriceA,, uint128 liquidityA) = _poolState(sixAndSix);
        (uint160 sqrtPriceB,, uint128 liquidityB) = _poolState(eighteenAndEight);

        assertEq(sqrtPriceA, sqrtPriceB, "the authoritative prices must match");
        assertEq(liquidityA, liquidityB, "the authoritative liquidity must match");
    }

    /// @notice Proves the derived capacity is identical, in raw units, across the two precisions.
    function test_capacity_isIndependentOfCurrencyDecimalPrecision() public view {
        assertEq(
            sixAndSix.hook.supportingCapacity(),
            eighteenAndEight.hook.supportingCapacity(),
            "identical geometry must derive identical raw capacity whatever the precisions"
        );
        assertEq(
            sixAndSix.hook.supportingCapacity(),
            FROZEN_CANONICAL_INITIAL_S,
            "and the shared answer must be the canonical amount"
        );
    }

    /// @notice Proves the derived capacity equals the independent reference for both precisions.
    /// @dev The reference is likewise composed without consulting either currency, so agreement here is
    ///      agreement about the raw protected-output amount rather than about a shared scaling habit.
    function test_capacity_equalsIndependentReferenceForBothPrecisions() public view {
        (uint160 sqrtPriceX96,, uint128 liquidity) = _poolState(eighteenAndEight);

        assertEq(
            eighteenAndEight.hook.supportingCapacity(),
            ReferenceCalculations.referenceSupportingCapacity(
                eighteenAndEight.config.protectedZeroForOne, sqrtPriceX96, eighteenAndEight.config.tickQ, liquidity
            ),
            "the asymmetric-decimal service must equal the independent reference"
        );
    }
}
