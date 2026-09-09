// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseCanonicalAcceptanceTest} from "../shared/BaseCanonicalAcceptanceTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Canonical acceptance evidence that fresh construction reaches exactly the frozen pre-A1 state
///         (GB — Bootstrap Fidelity).
/// @dev The question here is narrow and comes before every other acceptance question: starting from an
///      empty chain, does the production deployment and bootstrap path put the system exactly where the
///      canonical demonstration says it starts?
///
///      Everything asserted below was produced by real deployment and real production transitions — the
///      pinned `PoolManager`, the canonical Hook deployment procedure, the deterministic ordered fixture
///      currencies, the Hook's own one-shot service activation, the registry's own administrator, and the
///      canonical position added through the trusted liquidity perimeter and the Hook's production
///      liquidity enforcement. No storage was written directly, no harness took part, no economic state
///      was seeded, and no commitment was pre-created.
///
///      The frozen expectations — ordered MockUSTB/MockUSDC, protected `zeroForOne`, tick 0, `tickQ`
///      -240, `tickO` +240, spacing 10, fee 500, `L = 6,707,079,990,254`, `S = 80,000`, `O = 0`, no
///      commitment — are test assertions taken from the canonical fixture, checked against authoritative
///      production state. They are not a second state machine, and the two economic quantities are
///      checked against an independent reconstruction as well as against their frozen values.
contract BootstrapFidelityTest is BaseCanonicalAcceptanceTest {
    /*//////////////////////////////////////////////////////////////
              GB-1 — DETERMINISTIC ORDERED FIXTURE CURRENCIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves fresh construction deploys the canonical currencies in the canonical order.
    /// @dev The ordering is what makes the protected direction meaningful, and it is established by the
    ///      deterministic deployment rather than by relabelling whichever token happened to sort lower.
    function test_bootstrap_deploysTheCanonicalCurrenciesInTheCanonicalOrder() public view {
        address ustb = address(canonical.environment.ustb);
        address usdc = address(canonical.environment.usdc);

        assertLt(uint160(ustb), uint160(usdc), "MockUSTB must be the lower address");

        assertEq(Currency.unwrap(canonical.poolKey.currency0), ustb, "currency0 must be MockUSTB");
        assertEq(Currency.unwrap(canonical.poolKey.currency1), usdc, "currency1 must be MockUSDC");

        assertEq(canonical.environment.ustb.symbol(), "MockUSTB", "currency0 must be the MockUSTB fixture currency");
        assertEq(canonical.environment.usdc.symbol(), "MockUSDC", "currency1 must be the MockUSDC fixture currency");

        assertEq(
            uint256(canonical.environment.ustb.decimals()),
            uint256(StandbyFixtureConfig.CURRENCY_DECIMALS),
            "MockUSTB must carry the canonical precision"
        );
        assertEq(
            uint256(canonical.environment.usdc.decimals()),
            uint256(StandbyFixtureConfig.CURRENCY_DECIMALS),
            "MockUSDC must carry the canonical precision"
        );
    }

    /*//////////////////////////////////////////////////////////////
                 GB-2 — CANONICAL SERVICE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves fresh construction activates exactly the canonical Protected Execution Service.
    /// @dev Read back from the Hook's own configuration surface rather than from the bootstrap inputs, so
    ///      a bootstrap that had passed some other domain, direction, registry, coordinator, or authority
    ///      would be visible here.
    function test_bootstrap_activatesExactlyTheCanonicalProtectedExecutionService() public view {
        StandbyHook.ProtectedExecutionService memory service = canonical.environment.hook.protectedExecutionService();

        assertTrue(service.configured, "the service must be configured");

        assertEq(
            Currency.unwrap(service.poolKey.currency0),
            address(canonical.environment.ustb),
            "the service must be over MockUSTB"
        );
        assertEq(
            Currency.unwrap(service.poolKey.currency1),
            address(canonical.environment.usdc),
            "the service must be over MockUSDC"
        );
        assertEq(
            address(service.poolKey.hooks), address(canonical.environment.hook), "the service pool must bind the Hook"
        );
        assertEq(uint256(service.poolKey.fee), uint256(StandbyFixtureConfig.LP_FEE), "the canonical fee is 500 pips");
        assertEq(service.poolKey.tickSpacing, StandbyFixtureConfig.TICK_SPACING, "the canonical tick spacing is 10");

        assertTrue(service.protectedZeroForOne, "the canonical protected direction is zeroForOne");
        assertEq(service.tickQ, StandbyFixtureConfig.TICK_Q, "the canonical tickQ is -240");
        assertEq(service.tickO, StandbyFixtureConfig.TICK_O, "the canonical tickO is +240");

        assertEq(
            address(service.registry),
            address(canonical.environment.registry),
            "the service must consume the deployed registry"
        );
        assertEq(
            service.exerciseRouter,
            address(canonical.environment.exerciseRouter),
            "the service must designate the deployed ExerciseRouter"
        );
        assertEq(
            service.establishmentAuthority,
            canonical.actors.establishmentAuthority,
            "the service must admit commitments through the establishment authority"
        );

        assertEq(
            PoolId.unwrap(canonical.environment.hook.serviceId()),
            PoolId.unwrap(canonical.serviceId),
            "the activated service identity must be the bootstrapped pool"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    GB-3 — CANONICAL POOL GEOMETRY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves fresh construction leaves the real pool at the canonical price and liquidity.
    /// @dev Both facts are read from the PoolManager, which is the only authority on either. The active
    ///      liquidity is the exact canonical constant: the position spans the whole service domain, so
    ///      every canonical action afterwards happens inside one constant-liquidity interval.
    function test_bootstrap_reachesTheCanonicalPoolGeometry() public view {
        (uint160 sqrtPriceX96, int24 tick, uint128 liquidity) = _poolState(canonical);

        assertEq(tick, StandbyFixtureConfig.INITIAL_TICK, "the canonical initial tick is 0");
        assertEq(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.INITIAL_TICK),
            "the pool must sit at the exact price of the canonical initial tick"
        );
        assertEq(liquidity, StandbyFixtureConfig.CANONICAL_LIQUIDITY, "the canonical active liquidity is L");
    }

    /*//////////////////////////////////////////////////////////////
              GB-4 — CANONICAL INITIAL ECONOMIC STATE / READY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves fresh construction ends at `S = 80,000`, `O = 0`, with no commitment in existence.
    /// @dev The frozen bootstrap row of the canonical sequence. Supporting Capacity is checked against the
    ///      frozen expectation and against an independent reconstruction from PoolManager state; the
    ///      obligation is checked the same way, and separately proven to be zero because nothing was ever
    ///      admitted rather than because something admitted has since lapsed.
    function test_bootstrap_reachesTheCanonicalInitialEconomicState() public view {
        assertEq(
            canonical.environment.hook.supportingCapacity(),
            StandbyFixtureConfig.EXPECTED_INITIAL_S,
            "canonical bootstrap Supporting Capacity is 80,000 MockUSDC"
        );
        assertEq(canonical.environment.hook.aggregateObligation(), 0, "canonical bootstrap obligation is zero");

        _assertDerivationsMatchOracles(canonical, "bootstrap derivations must equal their reconstructions");

        assertEq(canonical.environment.hook.nextCommitmentId(), 1, "no commitment identity may have been consumed yet");
        assertEq(_occupiedReferenceCount(canonical), 0, "the bounded enforcement index must be empty");

        uint256[MAX_LIVE_COMMITMENTS] memory references = canonical.environment.hook.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(references[slot], 0, "no enforcement reference may exist at bootstrap");
        }
    }

    /*//////////////////////////////////////////////////////////////
                GB-5 — HOOK PERMISSIONS AND TRUST BINDINGS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the freshly deployed Hook address encodes exactly the required permission bits.
    /// @dev The mask is reconstructed here from the pinned `Hooks` flag constants rather than read from
    ///      the deployment procedure, so this is an independent statement about the deployed address. The
    ///      pinned validator is then asked whether the address agrees with the Hook's own declared
    ///      permissions, which is the check Uniswap itself performs.
    function test_bootstrap_deploysAHookWhoseAddressEncodesExactlyTheRequiredPermissions() public view {
        uint160 requiredMask = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.AFTER_SWAP_FLAG
        );

        uint160 encoded = uint160(address(canonical.environment.hook)) & Hooks.ALL_HOOK_MASK;

        assertEq(encoded, requiredMask, "the deployed Hook address must encode exactly the required permissions");

        Hooks.Permissions memory declared = canonical.environment.hook.getHookPermissions();

        assertTrue(declared.beforeAddLiquidity, "beforeAddLiquidity must be enabled");
        assertTrue(declared.beforeRemoveLiquidity, "beforeRemoveLiquidity must be enabled");
        assertTrue(declared.beforeSwap, "beforeSwap must be enabled");
        assertTrue(declared.afterSwap, "afterSwap must be enabled");

        assertFalse(declared.beforeInitialize, "beforeInitialize must be disabled");
        assertFalse(declared.afterInitialize, "afterInitialize must be disabled");
        assertFalse(declared.afterAddLiquidity, "afterAddLiquidity must be disabled");
        assertFalse(declared.afterRemoveLiquidity, "afterRemoveLiquidity must be disabled");
        assertFalse(declared.beforeDonate, "beforeDonate must be disabled");
        assertFalse(declared.afterDonate, "afterDonate must be disabled");
        assertFalse(declared.beforeSwapReturnDelta, "beforeSwapReturnDelta must be disabled");
        assertFalse(declared.afterSwapReturnDelta, "afterSwapReturnDelta must be disabled");
        assertFalse(declared.afterAddLiquidityReturnDelta, "afterAddLiquidityReturnDelta must be disabled");
        assertFalse(declared.afterRemoveLiquidityReturnDelta, "afterRemoveLiquidityReturnDelta must be disabled");

        Hooks.validateHookPermissions(IHooks(address(canonical.environment.hook)), declared);
    }

    /// @notice Proves the freshly deployed components are bound to the intended real infrastructure.
    /// @dev The Hook's PoolManager binding is immutable and is the one the infrastructure resolution
    ///      produced; the coordinator resolves its own PoolManager from the Hook, so the two cannot
    ///      disagree; and the two trusted perimeters are bound in their own distinct roles.
    function test_bootstrap_bindsTheDeployedComponentsToTheResolvedInfrastructure() public view {
        address poolManager = address(canonical.environment.poolManager);

        assertEq(poolManager, canonical.networkConfig.poolManager, "the environment must use the resolved PoolManager");
        assertEq(canonical.networkConfig.chainId, block.chainid, "the resolved configuration must describe this chain");

        assertEq(
            address(canonical.environment.hook.poolManager()),
            poolManager,
            "the Hook must be bound to the real PoolManager"
        );
        assertEq(
            address(canonical.environment.exerciseRouter.i_poolManager()),
            poolManager,
            "the coordinator must resolve the same PoolManager"
        );
        assertEq(
            address(canonical.environment.exerciseRouter.i_hook()),
            address(canonical.environment.hook),
            "the coordinator must be bound to the deployed Hook"
        );

        assertEq(
            canonical.environment.hook.i_configurationAuthority(),
            canonical.actors.configurationAuthority,
            "the Hook must be bound to the intended configuration authority"
        );
        assertEq(
            canonical.environment.hook.i_trustedUniversalRouter(),
            address(canonical.environment.swapPerimeter),
            "the Hook must trust the deployed ordinary-swap perimeter"
        );
        assertEq(
            canonical.environment.hook.i_trustedPositionManager(),
            address(canonical.environment.liquidityPerimeter),
            "the Hook must trust the deployed liquidity perimeter"
        );
        assertTrue(
            address(canonical.environment.swapPerimeter) != address(canonical.environment.liquidityPerimeter),
            "the two trusted perimeters must be distinct contracts"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     GB-6 — PRE-A1 CUSTODY AND ACTORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves no Standby contract holds protected output before the first canonical action.
    /// @dev Standby backs future execution out of shared AMM liquidity rather than out of a reserve, so a
    ///      protected-output balance held by the Hook or the coordinator at bootstrap would contradict the
    ///      claim the demonstration is about. Both currencies are checked on both contracts.
    function test_bootstrap_leavesNoCustodyWithTheHookOrTheCoordinator() public view {
        address hook = address(canonical.environment.hook);
        address coordinator = address(canonical.environment.exerciseRouter);

        assertEq(canonical.environment.usdc.balanceOf(hook), 0, "the Hook must hold no protected output");
        assertEq(canonical.environment.ustb.balanceOf(hook), 0, "the Hook must hold no input currency");
        assertEq(canonical.environment.usdc.balanceOf(coordinator), 0, "the coordinator must hold no protected output");
        assertEq(canonical.environment.ustb.balanceOf(coordinator), 0, "the coordinator must hold no input currency");
    }

    /// @notice Proves bootstrap grants exactly the eligibility the canonical sequence needs, and no more.
    /// @dev Each actor holds one predicate, in its own domain. The exercise authority holds none at all,
    ///      which matters later: the canonical exercise must succeed on the commitment's own authority
    ///      rather than on an unrelated registry grant.
    function test_bootstrap_grantsExactlyTheCanonicalEligibility() public view {
        assertTrue(
            canonical.environment.registry.canReceiveProtectedService(canonical.actors.beneficiary),
            "the Beneficiary must be eligible to receive protected service"
        );
        assertTrue(canonical.environment.registry.canSwap(canonical.actors.trader), "the trader must be eligible");
        assertTrue(
            canonical.environment.registry.canProvideLiquidity(canonical.actors.liquidityProvider),
            "the liquidity provider must be eligible"
        );

        assertFalse(
            canonical.environment.registry.canSwap(canonical.actors.beneficiary),
            "Beneficiary eligibility must not imply trader eligibility"
        );
        assertFalse(
            canonical.environment.registry.canProvideLiquidity(canonical.actors.trader),
            "trader eligibility must not imply liquidity eligibility"
        );
        assertFalse(
            canonical.environment.registry.canSwap(canonical.actors.exerciseAuthority),
            "the exercise authority must hold no trader eligibility"
        );
        assertFalse(
            canonical.environment.registry.canReceiveProtectedService(canonical.actors.exerciseAuthority),
            "the exercise authority must hold no Beneficiary eligibility"
        );
    }

    /// @notice Proves the Beneficiary starts with no protected output and the exerciser with none either.
    /// @dev What makes the canonical delivery measurable. The Beneficiary holds zero MockUSDC before A1,
    ///      so every unit it ends with came from the exercise; and the exerciser is funded in input
    ///      currency only, so it cannot have been the source of that delivery.
    function test_bootstrap_fundsTheCanonicalActorsWithoutPrefundingTheDelivery() public view {
        assertEq(
            canonical.environment.usdc.balanceOf(canonical.actors.beneficiary),
            0,
            "the Beneficiary must hold no protected output at bootstrap"
        );
        assertEq(
            canonical.environment.ustb.balanceOf(canonical.actors.beneficiary),
            0,
            "the Beneficiary must hold no input currency at bootstrap"
        );
        assertEq(
            canonical.environment.usdc.balanceOf(canonical.actors.exerciseAuthority),
            0,
            "the exerciser must hold no protected output"
        );
        assertGt(
            canonical.environment.ustb.balanceOf(canonical.actors.exerciseAuthority),
            0,
            "the exerciser must be able to pay for its own exercise"
        );
        assertGt(
            canonical.environment.ustb.balanceOf(canonical.actors.trader),
            0,
            "the trader must be able to pay for ordinary swaps"
        );
    }
}
