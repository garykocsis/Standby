// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";
import {IEligibilityRegistry} from "../../src/interfaces/IEligibilityRegistry.sol";
import {ServiceDomain} from "../../src/libraries/ServiceDomain.sol";

import {BaseStandbyServiceTest} from "../shared/BaseStandbyServiceTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for G3-C — configuration / trust fidelity.
/// @dev Every activation attempt in this suite runs against the real pinned `PoolManager`, a Hook
///      deployed by the canonical production procedure, and pools created by real
///      `PoolManager.initialize` calls. Pool initialization, current liquidity, and current price are
///      read from authoritative PoolManager state by the production code under test.
///
///      Each test starts from the shared unconfigured fixture, so an attempt that must be rejected can
///      be proved to have left the Hook unconfigured.
contract StandbyServiceConfigurationTest is BaseStandbyServiceTest {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev A tick spacing of one, at which a bitmap word covers only 256 ticks, so the supported
    ///      traversal bound is reachable within an ordinary domain width.
    int24 internal constant FINE_TICK_SPACING = 1;

    /// @dev A domain whose traversal demand is exactly the supported bound: fifteen bitmap words, plus
    ///      the one conditional step a numeric top that is not on a word edge allows for.
    int24 internal constant EXACT_BOUND_TICK_Q = -3_484;
    int24 internal constant EXACT_BOUND_TICK_O = 100;

    /// @dev One tick lower, which moves the numeric bottom into the next word and demands one step more.
    int24 internal constant OVER_BOUND_TICK_Q = -3_585;

    event ProtectedExecutionServiceActivated(
        PoolId indexed serviceId,
        PoolKey poolKey,
        bool protectedZeroForOne,
        int24 tickQ,
        int24 tickO,
        address registry,
        address exerciseRouter,
        address establishmentAuthority
    );

    /*//////////////////////////////////////////////////////////////
                    G3-C — POSITIVE ACTIVATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the canonical fixture activates when every required condition is satisfied.
    function test_configureAndActivate_activatesTheCanonicalService() public {
        assertEq(poolManager.getLiquidity(canonicalPoolId), 0, "the canonical pool must start empty");

        vm.expectEmit(true, false, false, true, address(hook));
        emit ProtectedExecutionServiceActivated(
            canonicalPoolId,
            canonicalPoolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            address(registry),
            exerciseRouter,
            establishmentAuthority
        );

        PoolId returnedServiceId = _activateCanonicalService();

        assertEq(PoolId.unwrap(returnedServiceId), PoolId.unwrap(canonicalPoolId), "activation must return the PoolId");
    }

    /// @notice Proves the complete persisted PES basis reads back exactly as configured.
    function test_activatedService_readsBackTheCompleteConfiguredBasis() public {
        _activateCanonicalService();

        StandbyHook.ProtectedExecutionService memory service = hook.protectedExecutionService();

        assertTrue(service.configured, "the service-existence fact must be true");

        assertEq(Currency.unwrap(service.poolKey.currency0), address(ustb), "currency0 fidelity");
        assertEq(Currency.unwrap(service.poolKey.currency1), address(usdc), "currency1 fidelity");
        assertEq(uint256(service.poolKey.fee), uint256(StandbyFixtureConfig.LP_FEE), "fee fidelity");
        assertEq(service.poolKey.tickSpacing, StandbyFixtureConfig.TICK_SPACING, "tick spacing fidelity");
        assertEq(address(service.poolKey.hooks), address(hook), "hook binding fidelity");

        assertEq(address(service.registry), address(registry), "registry fidelity");
        assertTrue(service.protectedZeroForOne, "protected direction fidelity");
        assertEq(service.tickQ, StandbyFixtureConfig.TICK_Q, "tickQ fidelity");
        assertEq(service.tickO, StandbyFixtureConfig.TICK_O, "tickO fidelity");
        assertEq(service.exerciseRouter, exerciseRouter, "ExerciseRouter fidelity");
        assertEq(service.establishmentAuthority, establishmentAuthority, "establishment authority fidelity");

        assertEq(PoolId.unwrap(hook.serviceId()), PoolId.unwrap(canonicalPoolId), "service identity fidelity");
    }

    /// @notice Proves the service identity is derived from the persisted PoolKey, not persisted itself.
    /// @dev The reported identity equals an independent recomputation of the PoolId from the persisted
    ///      key, so no separately stored identity can drift from the stored basis.
    function test_serviceId_isDerivedFromThePersistedPoolKey() public {
        _activateCanonicalService();

        StandbyHook.ProtectedExecutionService memory service = hook.protectedExecutionService();

        PoolKey memory persistedKey = service.poolKey;

        assertEq(PoolId.unwrap(hook.serviceId()), PoolId.unwrap(persistedKey.toId()), "identity must be derived");
    }

    /// @notice Proves activation does not require or manufacture liquidity in the configured pool.
    /// @dev RR-CONFIG-5: configuration does not mutate the pool and does not require positive capacity.
    function test_activation_leavesTheAuthoritativePoolStateUnchanged() public {
        (uint160 sqrtPriceBefore, int24 tickBefore,, uint24 lpFeeBefore) = poolManager.getSlot0(canonicalPoolId);

        _activateCanonicalService();

        (uint160 sqrtPriceAfter, int24 tickAfter,, uint24 lpFeeAfter) = poolManager.getSlot0(canonicalPoolId);

        assertEq(sqrtPriceAfter, sqrtPriceBefore, "activation must not move the price");
        assertEq(tickAfter, tickBefore, "activation must not move the tick");
        assertEq(lpFeeAfter, lpFeeBefore, "activation must not change the fee");
        assertEq(poolManager.getLiquidity(canonicalPoolId), 0, "activation must not create liquidity");
    }

    /*//////////////////////////////////////////////////////////////
                      G3-C 1 — ACTIVATION AUTHORITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves only the configured Hook-wide configuration authority can activate.
    function test_configureAndActivate_rejectsAnAccountThatIsNotTheConfigurationAuthority() public {
        vm.prank(unauthorizedAccount);
        vm.expectRevert(
            abi.encodeWithSelector(StandbyHook.StandbyHook__NotConfigurationAuthority.selector, unauthorizedAccount)
        );
        hook.configureAndActivate(
            canonicalPoolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves configuration authority is not conferred by any other Standby role.
    /// @dev The registry administrator, the establishment authority, the designated ExerciseRouter, and
    ///      both trusted perimeters are each rejected. Configuration authority is its own permission
    ///      domain, not a consequence of holding some other Standby role.
    function test_configureAndActivate_rejectsEveryOtherStandbyRole() public {
        address[5] memory otherRoles =
            [registryAdmin, establishmentAuthority, exerciseRouter, trustedUniversalRouter, trustedPositionManager];

        for (uint256 i = 0; i < otherRoles.length; ++i) {
            vm.prank(otherRoles[i]);
            vm.expectRevert(
                abi.encodeWithSelector(StandbyHook.StandbyHook__NotConfigurationAuthority.selector, otherRoles[i])
            );
            hook.configureAndActivate(
                canonicalPoolKey,
                StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
                StandbyFixtureConfig.TICK_Q,
                StandbyFixtureConfig.TICK_O,
                IEligibilityRegistry(address(registry)),
                exerciseRouter,
                establishmentAuthority
            );
        }

        _assertNoServiceConfigured(hook);
    }

    /*//////////////////////////////////////////////////////////////
                      G3-C 2 — ONE-SHOT LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves activation succeeds exactly once, even for the configuration authority.
    function test_configureAndActivate_succeedsExactlyOnce() public {
        _activateCanonicalService();

        vm.prank(configurationAuthority);
        vm.expectRevert(StandbyHook.StandbyHook__ServiceAlreadyConfigured.selector);
        hook.configureAndActivate(
            canonicalPoolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );
    }

    /// @notice Proves no post-activation path can replace any semantic service fact.
    /// @dev A second activation supplying a different registry, direction, domain, ExerciseRouter, and
    ///      establishment authority over a different real initialized pool is rejected, and every
    ///      persisted fact still reads as originally configured.
    function test_activatedService_cannotBeReinterpretedByASecondActivation() public {
        _activateCanonicalService();

        PoolKey memory replacementKey =
            _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, StandbyFixtureConfig.TICK_SPACING);
        _initializePoolAtTick(replacementKey, StandbyFixtureConfig.INITIAL_TICK);

        EligibilityRegistry replacementRegistry = new EligibilityRegistry(makeAddr("replacementRegistryAdmin"));
        address replacementExerciseRouter = makeAddr("replacementExerciseRouter");
        address replacementEstablishmentAuthority = makeAddr("replacementEstablishmentAuthority");

        vm.prank(configurationAuthority);
        vm.expectRevert(StandbyHook.StandbyHook__ServiceAlreadyConfigured.selector);
        hook.configureAndActivate(
            replacementKey,
            false,
            StandbyFixtureConfig.TICK_O,
            StandbyFixtureConfig.TICK_Q,
            IEligibilityRegistry(address(replacementRegistry)),
            replacementExerciseRouter,
            replacementEstablishmentAuthority
        );

        StandbyHook.ProtectedExecutionService memory service = hook.protectedExecutionService();

        assertEq(address(service.registry), address(registry), "the registry reference cannot be replaced");
        assertTrue(service.protectedZeroForOne, "the protected direction cannot be replaced");
        assertEq(service.tickQ, StandbyFixtureConfig.TICK_Q, "tickQ cannot be replaced");
        assertEq(service.tickO, StandbyFixtureConfig.TICK_O, "tickO cannot be replaced");
        assertEq(service.exerciseRouter, exerciseRouter, "the ExerciseRouter cannot be replaced");
        assertEq(
            service.establishmentAuthority, establishmentAuthority, "the establishment authority cannot be replaced"
        );
        assertEq(uint256(service.poolKey.fee), uint256(StandbyFixtureConfig.LP_FEE), "the PoolKey cannot be replaced");
    }

    /// @notice Proves the Hook exposes no service setter, pause, deactivation, or migration surface.
    /// @dev The Hook has no fallback, so a call to any absent selector reverts. This enumerates the
    ///      post-activation reinterpretation surfaces the frozen realization forbids and shows that none
    ///      of them exists on the deployed contract.
    function test_hook_exposesNoPostActivationServiceMutationSurface() public {
        _activateCanonicalService();

        string[] memory forbiddenSignatures = new string[](10);
        forbiddenSignatures[0] = "setEligibilityRegistry(address)";
        forbiddenSignatures[1] = "setExerciseRouter(address)";
        forbiddenSignatures[2] = "setEstablishmentAuthority(address)";
        forbiddenSignatures[3] = "setServiceDomain(int24,int24)";
        forbiddenSignatures[4] = "setProtectedDirection(bool)";
        forbiddenSignatures[5] = "setActive(bool)";
        forbiddenSignatures[6] = "pause()";
        forbiddenSignatures[7] = "unpause()";
        forbiddenSignatures[8] = "deactivate()";
        forbiddenSignatures[9] = "migrate(address)";

        for (uint256 i = 0; i < forbiddenSignatures.length; ++i) {
            (bool success,) = address(hook).call(abi.encodeWithSignature(forbiddenSignatures[i], address(1)));
            assertFalse(success, forbiddenSignatures[i]);
        }

        StandbyHook.ProtectedExecutionService memory service = hook.protectedExecutionService();

        assertEq(address(service.registry), address(registry), "the service basis must be untouched");
        assertEq(service.exerciseRouter, exerciseRouter, "the service basis must be untouched");
    }

    /*//////////////////////////////////////////////////////////////
                    G3-C 3/4 — POOL IDENTITY AND STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a PoolKey that binds no Hook is rejected.
    function test_configureAndActivate_rejectsAPoolKeyThatBindsNoHook() public {
        PoolKey memory hooklessKey =
            _poolKeyFor(IHooks(address(0)), StandbyFixtureConfig.LP_FEE, StandbyFixtureConfig.TICK_SPACING);
        _initializePoolAtTick(hooklessKey, StandbyFixtureConfig.INITIAL_TICK);

        _expectActivationRevert(
            hooklessKey,
            abi.encodeWithSelector(StandbyHook.StandbyHook__PoolKeyDoesNotBindThisHook.selector, address(0))
        );
    }

    /// @notice Proves a PoolKey that binds a different StandbyHook is rejected.
    /// @dev A second Hook deployed through the canonical procedure is a fully valid Standby Hook. It is
    ///      still not this Hook, and this Hook must not adopt its pool.
    function test_configureAndActivate_rejectsAPoolKeyThatBindsADifferentStandbyHook() public {
        StandbyHook otherHook = _deployHook(configurationAuthority, trustedUniversalRouter, trustedPositionManager);

        PoolKey memory otherKey =
            _poolKeyFor(IHooks(address(otherHook)), StandbyFixtureConfig.LP_FEE, StandbyFixtureConfig.TICK_SPACING);
        _initializePoolAtTick(otherKey, StandbyFixtureConfig.INITIAL_TICK);

        _expectActivationRevert(
            otherKey,
            abi.encodeWithSelector(StandbyHook.StandbyHook__PoolKeyDoesNotBindThisHook.selector, address(otherHook))
        );
    }

    /// @notice Proves an uninitialized pool is rejected using authoritative PoolManager state.
    function test_configureAndActivate_rejectsAnUninitializedPool() public {
        PoolKey memory uninitializedKey =
            _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, StandbyFixtureConfig.TICK_SPACING);
        PoolId uninitializedPoolId = uninitializedKey.toId();

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(uninitializedPoolId);
        assertEq(sqrtPriceX96, 0, "the pool must genuinely be uninitialized");

        _expectActivationRevert(
            uninitializedKey,
            abi.encodeWithSelector(StandbyHook.StandbyHook__PoolNotInitialized.selector, uninitializedPoolId)
        );
    }

    /// @notice Proves a dynamic-fee pool is rejected as an unsupported accounting model.
    /// @dev The pool is genuinely initialized through the real PoolManager with the dynamic-fee
    ///      sentinel, so the rejection comes from Standby's fee-model rule and not from v4 refusing the
    ///      pool. The supported model is the static LP fee the selected prospective derivation assumes.
    function test_configureAndActivate_rejectsADynamicFeePool() public {
        PoolKey memory dynamicFeeKey =
            _poolKeyFor(IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, StandbyFixtureConfig.TICK_SPACING);
        _initializePoolAtTick(dynamicFeeKey, StandbyFixtureConfig.INITIAL_TICK);

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(dynamicFeeKey.toId());
        assertGt(sqrtPriceX96, 0, "the dynamic-fee pool must genuinely be initialized");

        _expectActivationRevert(
            dynamicFeeKey,
            abi.encodeWithSelector(StandbyHook.StandbyHook__UnsupportedFeeModel.selector, LPFeeLibrary.DYNAMIC_FEE_FLAG)
        );
    }

    /*//////////////////////////////////////////////////////////////
                  G3-C 7..11 — DIRECTION AND SERVICE DOMAIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves protected `zeroForOne` requires `tickQ < tickO`.
    function test_configureAndActivate_rejectsInvertedDomainForProtectedZeroForOne() public {
        vm.prank(configurationAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidServiceDomainOrder.selector,
                true,
                StandbyFixtureConfig.TICK_O,
                StandbyFixtureConfig.TICK_Q
            )
        );
        hook.configureAndActivate(
            canonicalPoolKey,
            true,
            StandbyFixtureConfig.TICK_O,
            StandbyFixtureConfig.TICK_Q,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves protected `oneForZero` requires `tickQ > tickO`.
    /// @dev The same tick pair that is valid for `zeroForOne` is invalid for `oneForZero`, which is what
    ///      makes the boundaries direction-relative rather than numerically low/high.
    function test_configureAndActivate_rejectsInvertedDomainForProtectedOneForZero() public {
        vm.prank(configurationAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidServiceDomainOrder.selector,
                false,
                StandbyFixtureConfig.TICK_Q,
                StandbyFixtureConfig.TICK_O
            )
        );
        hook.configureAndActivate(
            canonicalPoolKey,
            false,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves the opposite protected direction activates when its own ordering is satisfied.
    /// @dev Standby must not hard-code the canonical fixture direction, so the mirrored configuration
    ///      over the same real pool must be accepted.
    function test_configureAndActivate_acceptsProtectedOneForZeroWithItsOwnOrdering() public {
        vm.prank(configurationAuthority);
        hook.configureAndActivate(
            canonicalPoolKey,
            false,
            StandbyFixtureConfig.TICK_O,
            StandbyFixtureConfig.TICK_Q,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        StandbyHook.ProtectedExecutionService memory service = hook.protectedExecutionService();

        assertFalse(service.protectedZeroForOne, "the protected direction must be oneForZero");
        assertEq(service.tickQ, StandbyFixtureConfig.TICK_O, "tickQ is the direction-relative boundary");
        assertEq(service.tickO, StandbyFixtureConfig.TICK_Q, "tickO is the opposite boundary");
    }

    /// @notice Proves equal service boundaries are rejected: the domain cannot be degenerate.
    function test_configureAndActivate_rejectsEqualServiceBoundaries() public {
        vm.prank(configurationAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InvalidServiceDomainOrder.selector,
                true,
                StandbyFixtureConfig.TICK_Q,
                StandbyFixtureConfig.TICK_Q
            )
        );
        hook.configureAndActivate(
            canonicalPoolKey,
            true,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_Q,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves a boundary outside the valid Uniswap tick range is rejected.
    function test_configureAndActivate_rejectsAnOutOfRangeServiceTick() public {
        int24 outOfRangeTick = TickMath.MAX_TICK + 10;

        vm.prank(configurationAuthority);
        vm.expectRevert(abi.encodeWithSelector(StandbyHook.StandbyHook__InvalidServiceTick.selector, outOfRangeTick));
        hook.configureAndActivate(
            canonicalPoolKey,
            true,
            StandbyFixtureConfig.TICK_Q,
            outOfRangeTick,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /*//////////////////////////////////////////////////////////////
           G3-C — PROSPECTIVE DERIVABILITY ADMISSION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the canonical fixture domain is comfortably inside the supported traversal bound.
    /// @dev The admission rule added by the F5 correction must not disturb the canonical demonstration.
    ///      This states the canonical margin explicitly, so a later change to the bound or to the
    ///      classifier that quietly narrowed it would be visible here rather than in an unrelated suite.
    function test_configureAndActivate_leavesTheCanonicalDomainWellInsideTheTraversalBound() public {
        uint256 demand = ServiceDomain.prospectiveTraversalDemand(
            StandbyFixtureConfig.TICK_Q, StandbyFixtureConfig.TICK_O, StandbyFixtureConfig.TICK_SPACING
        );

        assertEq(demand, 3, "the canonical domain demands three traversal steps");
        assertLt(demand, hook.MAX_PROSPECTIVE_SWAP_STEPS(), "the canonical domain must be well inside the bound");

        _activateCanonicalService();

        assertTrue(hook.protectedExecutionService().configured, "the canonical fixture must still activate");
    }

    /// @notice Proves a domain demanding exactly the supported bound activates.
    /// @dev The accepting side of the boundary. A rule that rejected at the bound rather than beyond it
    ///      would exclude configurations the realization can in fact derive.
    function test_configureAndActivate_acceptsADomainDemandingExactlyTheSupportedBound() public {
        PoolKey memory key = _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, FINE_TICK_SPACING);
        _initializePoolAtTick(key, EXACT_BOUND_TICK_O);

        assertEq(
            ServiceDomain.prospectiveTraversalDemand(EXACT_BOUND_TICK_Q, EXACT_BOUND_TICK_O, FINE_TICK_SPACING),
            hook.MAX_PROSPECTIVE_SWAP_STEPS(),
            "the fixture must sit exactly on the bound"
        );

        vm.prank(configurationAuthority);
        hook.configureAndActivate(
            key,
            true,
            EXACT_BOUND_TICK_Q,
            EXACT_BOUND_TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        StandbyHook.ProtectedExecutionService memory service = hook.protectedExecutionService();

        assertTrue(service.configured, "an exactly-bounded domain must activate");
        assertEq(service.tickQ, EXACT_BOUND_TICK_Q, "tickQ fidelity");
        assertEq(service.tickO, EXACT_BOUND_TICK_O, "tickO fidelity");
    }

    /// @notice Proves a domain demanding one step beyond the supported bound is rejected atomically.
    /// @dev One tick of extra width moves the numeric bottom into the next bitmap word and pushes demand
    ///      past the bound. Everything else about the configuration is admissible, so the rejection is
    ///      isolating the realization-admissibility failure and nothing else, and it leaves no fragment
    ///      of a Protected Execution Service behind.
    function test_configureAndActivate_rejectsADomainDemandingOneStepBeyondTheBound() public {
        PoolKey memory key = _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, FINE_TICK_SPACING);
        _initializePoolAtTick(key, EXACT_BOUND_TICK_O);

        uint256 bound = hook.MAX_PROSPECTIVE_SWAP_STEPS();
        uint256 demand =
            ServiceDomain.prospectiveTraversalDemand(OVER_BOUND_TICK_Q, EXACT_BOUND_TICK_O, FINE_TICK_SPACING);

        assertEq(demand, bound + 1, "the fixture must sit exactly one step beyond the bound");

        vm.prank(configurationAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProspectiveTraversalDemandExceedsBound.selector, demand, bound
            )
        );
        hook.configureAndActivate(
            key,
            true,
            OVER_BOUND_TICK_Q,
            EXACT_BOUND_TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves an over-bound rejection is rejected for both protected directions.
    /// @dev The numeric domain is what determines traversal demand, because ordinary swaps run in both
    ///      directions on any service. A rule that only looked along the protected direction would let
    ///      the same unsupported geometry through under the other label.
    function test_configureAndActivate_rejectsAnOverBoundDomainInEitherProtectedDirection() public {
        PoolKey memory key = _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, FINE_TICK_SPACING);
        _initializePoolAtTick(key, EXACT_BOUND_TICK_O);

        uint256 bound = hook.MAX_PROSPECTIVE_SWAP_STEPS();
        uint256 demand =
            ServiceDomain.prospectiveTraversalDemand(EXACT_BOUND_TICK_O, OVER_BOUND_TICK_Q, FINE_TICK_SPACING);

        vm.prank(configurationAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__ProspectiveTraversalDemandExceedsBound.selector, demand, bound
            )
        );
        hook.configureAndActivate(
            key,
            false,
            EXACT_BOUND_TICK_O,
            OVER_BOUND_TICK_Q,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves a rejected over-bound attempt leaves the Hook able to activate a valid service.
    /// @dev Atomicity is not only about persisting nothing; the one-shot activation right must survive a
    ///      rejected attempt intact. If the failed attempt had consumed it, the correction would have
    ///      turned a recoverable misconfiguration into a permanently inert Hook.
    function test_configureAndActivate_stillAcceptsTheCanonicalServiceAfterAnOverBoundRejection() public {
        PoolKey memory overBoundKey = _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, FINE_TICK_SPACING);
        _initializePoolAtTick(overBoundKey, EXACT_BOUND_TICK_O);

        vm.prank(configurationAuthority);
        try hook.configureAndActivate(
            overBoundKey,
            true,
            OVER_BOUND_TICK_Q,
            EXACT_BOUND_TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        ) returns (PoolId) {
            assertTrue(false, "an over-bound domain must not activate");
        } catch {}

        _assertNoServiceConfigured(hook);

        _activateCanonicalService();

        StandbyHook.ProtectedExecutionService memory service = hook.protectedExecutionService();

        assertTrue(service.configured, "the canonical service must still be activatable afterwards");
        assertEq(service.tickQ, StandbyFixtureConfig.TICK_Q, "the canonical tickQ must be the persisted one");
        assertEq(service.tickO, StandbyFixtureConfig.TICK_O, "the canonical tickO must be the persisted one");
    }

    /// @notice Proves a boundary misaligned to the authoritative pool tick spacing is rejected.
    function test_configureAndActivate_rejectsAMisalignedServiceTick() public {
        int24 misalignedTick = StandbyFixtureConfig.TICK_Q + 1;

        vm.prank(configurationAuthority);
        vm.expectRevert(
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__MisalignedServiceTick.selector,
                misalignedTick,
                StandbyFixtureConfig.TICK_SPACING
            )
        );
        hook.configureAndActivate(
            canonicalPoolKey,
            true,
            misalignedTick,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves an authoritative current price above the service domain is rejected.
    function test_configureAndActivate_rejectsCurrentPriceAboveTheServiceDomain() public {
        PoolKey memory outsideKey = _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, StandbyFixtureConfig.TICK_SPACING);
        _initializePoolAtTick(outsideKey, StandbyFixtureConfig.TICK_O + StandbyFixtureConfig.TICK_SPACING);

        _expectActivationRevert(
            outsideKey,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CurrentPriceOutsideServiceDomain.selector,
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_O + StandbyFixtureConfig.TICK_SPACING),
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q),
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_O)
            )
        );
    }

    /// @notice Proves an authoritative current price below the service domain is rejected.
    function test_configureAndActivate_rejectsCurrentPriceBelowTheServiceDomain() public {
        PoolKey memory outsideKey = _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, StandbyFixtureConfig.TICK_SPACING);
        _initializePoolAtTick(outsideKey, StandbyFixtureConfig.TICK_Q - StandbyFixtureConfig.TICK_SPACING);

        _expectActivationRevert(
            outsideKey,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CurrentPriceOutsideServiceDomain.selector,
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q - StandbyFixtureConfig.TICK_SPACING),
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q),
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_O)
            )
        );
    }

    /// @notice Proves the service domain is closed at `tickQ`: exact boundary equality activates.
    function test_configureAndActivate_acceptsCurrentPriceExactlyAtTickQ() public {
        PoolKey memory boundaryKey =
            _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, StandbyFixtureConfig.TICK_SPACING);
        _initializePoolAtTick(boundaryKey, StandbyFixtureConfig.TICK_Q);

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(boundaryKey.toId());
        assertEq(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q),
            "the pool must sit exactly on the tickQ price"
        );

        vm.prank(configurationAuthority);
        hook.configureAndActivate(
            boundaryKey,
            true,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        assertTrue(hook.protectedExecutionService().configured, "boundary equality at tickQ must activate");
    }

    /// @notice Proves the service domain is closed at `tickO`: exact boundary equality activates.
    function test_configureAndActivate_acceptsCurrentPriceExactlyAtTickO() public {
        PoolKey memory boundaryKey =
            _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, StandbyFixtureConfig.TICK_SPACING);
        _initializePoolAtTick(boundaryKey, StandbyFixtureConfig.TICK_O);

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(boundaryKey.toId());
        assertEq(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_O),
            "the pool must sit exactly on the tickO price"
        );

        vm.prank(configurationAuthority);
        hook.configureAndActivate(
            boundaryKey,
            true,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        assertTrue(hook.protectedExecutionService().configured, "boundary equality at tickO must activate");
    }

    /// @notice Proves domain containment is judged on the authoritative price, not on the current tick.
    /// @dev A pool initialized one unit of square-root price above the `tickO` price still reports
    ///      current tick `tickO`. A tick-space containment check would accept it; the closed price
    ///      domain does not, so this is the case that separates the two implementations.
    function test_configureAndActivate_rejectsAPriceAboveTickOThatStillReportsTickO() public {
        uint160 sqrtAtTickO = TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_O);

        PoolKey memory justAboveKey =
            _poolKeyFor(IHooks(address(hook)), ALTERNATE_FEE, StandbyFixtureConfig.TICK_SPACING);
        poolManager.initialize(justAboveKey, sqrtAtTickO + 1);

        (uint160 sqrtPriceX96, int24 currentTick,,) = poolManager.getSlot0(justAboveKey.toId());

        assertEq(currentTick, StandbyFixtureConfig.TICK_O, "the pool must still report tickO");
        assertGt(sqrtPriceX96, sqrtAtTickO, "the price must be strictly above the tickO price");

        _expectActivationRevert(
            justAboveKey,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__CurrentPriceOutsideServiceDomain.selector,
                sqrtPriceX96,
                TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.TICK_Q),
                sqrtAtTickO
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                    G3-C 12..14 — SERVICE PARTICIPANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves activation without an EligibilityRegistry is rejected.
    function test_configureAndActivate_rejectsAnUnsetEligibilityRegistry() public {
        vm.prank(configurationAuthority);
        vm.expectRevert(StandbyHook.StandbyHook__InvalidEligibilityRegistry.selector);
        hook.configureAndActivate(
            canonicalPoolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(0)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves activation without a designated ExerciseRouter is rejected.
    function test_configureAndActivate_rejectsAnUnsetExerciseRouter() public {
        vm.prank(configurationAuthority);
        vm.expectRevert(StandbyHook.StandbyHook__InvalidExerciseRouter.selector);
        hook.configureAndActivate(
            canonicalPoolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            address(0),
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }

    /// @notice Proves activation without a commitment-establishment authority is rejected.
    function test_configureAndActivate_rejectsAnUnsetEstablishmentAuthority() public {
        vm.prank(configurationAuthority);
        vm.expectRevert(StandbyHook.StandbyHook__InvalidEstablishmentAuthority.selector);
        hook.configureAndActivate(
            canonicalPoolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            address(0)
        );

        _assertNoServiceConfigured(hook);
    }

    /*//////////////////////////////////////////////////////////////
              G3-C 15 — TRUSTED REALIZATION DEPENDENCIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves a service cannot be established on a Hook with no trusted ordinary-swap perimeter.
    function test_configureAndActivate_rejectsAHookWithNoTrustedUniversalRouter() public {
        StandbyHook perimeterlessHook = _deployHook(configurationAuthority, address(0), trustedPositionManager);

        PoolKey memory key = _poolKeyFor(
            IHooks(address(perimeterlessHook)), StandbyFixtureConfig.LP_FEE, StandbyFixtureConfig.TICK_SPACING
        );
        _initializePoolAtTick(key, StandbyFixtureConfig.INITIAL_TICK);

        vm.prank(configurationAuthority);
        vm.expectRevert(StandbyHook.StandbyHook__InvalidTrustedUniversalRouter.selector);
        perimeterlessHook.configureAndActivate(
            key,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(perimeterlessHook);
    }

    /// @notice Proves a service cannot be established on a Hook with no trusted liquidity perimeter.
    /// @dev The ordinary-swap perimeter being present does not satisfy the liquidity perimeter
    ///      requirement: the two are distinct roles and are validated separately.
    function test_configureAndActivate_rejectsAHookWithNoTrustedPositionManager() public {
        StandbyHook perimeterlessHook = _deployHook(configurationAuthority, trustedUniversalRouter, address(0));

        PoolKey memory key = _poolKeyFor(
            IHooks(address(perimeterlessHook)), StandbyFixtureConfig.LP_FEE, StandbyFixtureConfig.TICK_SPACING
        );
        _initializePoolAtTick(key, StandbyFixtureConfig.INITIAL_TICK);

        vm.prank(configurationAuthority);
        vm.expectRevert(StandbyHook.StandbyHook__InvalidTrustedPositionManager.selector);
        perimeterlessHook.configureAndActivate(
            key,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(perimeterlessHook);
    }

    /*//////////////////////////////////////////////////////////////
                    G3-C — AUTHORITY-DOMAIN SEPARATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves every trust and authority role of the activated service stays its own address.
    /// @dev Read fidelity alone would pass if the Hook collapsed two roles onto one stored slot, so this
    ///      asserts the roles are pairwise distinct in the activated configuration as well as exact.
    function test_activatedService_keepsEveryTrustAndAuthorityRoleDistinct() public {
        _activateCanonicalService();

        StandbyHook.ProtectedExecutionService memory service = hook.protectedExecutionService();

        assertEq(hook.i_trustedUniversalRouter(), trustedUniversalRouter, "ordinary-swap perimeter fidelity");
        assertEq(hook.i_trustedPositionManager(), trustedPositionManager, "liquidity perimeter fidelity");
        assertEq(hook.i_configurationAuthority(), configurationAuthority, "configuration authority fidelity");

        assertNotEq(
            hook.i_trustedUniversalRouter(),
            hook.i_trustedPositionManager(),
            "the two trusted perimeters must remain distinct roles"
        );
        assertNotEq(
            service.exerciseRouter,
            hook.i_trustedUniversalRouter(),
            "ExerciseRouter trust is not ordinary-swap perimeter trust"
        );
        assertNotEq(
            service.exerciseRouter,
            hook.i_trustedPositionManager(),
            "ExerciseRouter trust is not liquidity perimeter trust"
        );
        assertNotEq(
            service.establishmentAuthority,
            hook.i_configurationAuthority(),
            "establishment authority is not configuration authority"
        );
        assertNotEq(
            service.establishmentAuthority, service.exerciseRouter, "establishment authority is not exercise authority"
        );
        assertNotEq(
            service.establishmentAuthority,
            EligibilityRegistry(address(service.registry)).i_admin(),
            "establishment authority is not registry administration authority"
        );
    }

    /// @notice Proves the Hook binds the registry reference without adopting registry administration.
    /// @dev The configured registry keeps its own administrator, and the Hook exposes no membership
    ///      management surface. Membership remains externally mutable under the F2 registry; F3 binds
    ///      the source, it does not consume or duplicate the answers.
    function test_activatedService_bindsTheRegistryWithoutAdoptingItsAdministration() public {
        _activateCanonicalService();

        StandbyHook.ProtectedExecutionService memory service = hook.protectedExecutionService();

        assertEq(EligibilityRegistry(address(service.registry)).i_admin(), registryAdmin, "registry keeps its admin");

        string[] memory membershipSignatures = new string[](3);
        membershipSignatures[0] = "setBeneficiaryEligibility(address,bool)";
        membershipSignatures[1] = "setTraderEligibility(address,bool)";
        membershipSignatures[2] = "setLiquidityEligibility(address,bool)";

        for (uint256 i = 0; i < membershipSignatures.length; ++i) {
            (bool success,) = address(hook).call(abi.encodeWithSignature(membershipSignatures[i], address(1), true));
            assertFalse(success, membershipSignatures[i]);
        }

        address beneficiary = makeAddr("beneficiary");

        vm.prank(registryAdmin);
        registry.setBeneficiaryEligibility(beneficiary, true);

        assertTrue(
            IEligibilityRegistry(address(service.registry)).canReceiveProtectedService(beneficiary),
            "registry membership must remain externally mutable"
        );
        assertEq(address(hook.protectedExecutionService().registry), address(registry), "the reference is unchanged");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Attempts a canonical-parameter activation over `_key` as the configuration authority,
    ///      expects the given revert, and proves no partial service state became authoritative.
    function _expectActivationRevert(PoolKey memory _key, bytes memory _expectedRevert) internal {
        vm.prank(configurationAuthority);
        vm.expectRevert(_expectedRevert);
        hook.configureAndActivate(
            _key,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );

        _assertNoServiceConfigured(hook);
    }
}
