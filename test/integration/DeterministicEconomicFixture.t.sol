// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {DeployStandbyHook} from "../../script/DeployStandbyHook.s.sol";
import {DeterministicFixtureDeployer} from "../../script/helpers/DeterministicFixtureDeployer.sol";
import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockUSTB} from "../../src/mocks/MockUSTB.sol";

import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Integration evidence for F1 — Deterministic Economic Fixture (G1-A and G1-B).
/// @dev The fixture is constructed through real paths only: the real pinned `PoolManager`, the canonical
///      F0 `DeployStandbyHook` procedure, the official pinned `PoolModifyLiquidityTest` liquidity path,
///      and the deterministic CREATE2 currency deployment. No PoolManager state is written directly and
///      no economic state is privileged-seeded.
///
///      Two real pools exist in this fixture, for a reason that is a genuine implementation-order
///      constraint rather than convenience:
///
///      - `canonicalPoolKey` binds the real StandbyHook. Frozen realization requirement RR-CONFIG-1
///        establishes the pool, binding the Hook, before Standby configuration and before liquidity, and
///        `configureAndActivate` later requires the pool's liquidity to be zero. At F1 the Hook's four
///        enabled callbacks also still fail closed with `HookNotImplemented`, so a liquidity addition to
///        this pool cannot succeed and must not be made to succeed by implementing F3/F6A behavior here.
///        This pool therefore carries the canonical identity evidence and no liquidity.
///
///      - `geometryPoolKey` is the same currencies, fee, and tick spacing with no Hook. It carries the
///        canonical liquidity position, and is the pool from which the canonical initial capacity
///        geometry is read. The Hook does not participate in the AMM arithmetic that determines
///        capacity, so the geometry evidence is unaffected by its absence.
contract DeterministicEconomicFixtureTest is Test {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The frozen expected initial capacity, restated here independently of the fixture config so
    ///      the gate assertion does not depend on a single constant definition.
    uint256 internal constant FROZEN_EXPECTED_INITIAL_S = 80_000 * 10 ** 6;

    /// @dev Fixture funding for the canonical liquidity position. The position needs roughly 99,850 of
    ///      each currency; this is a round over-provision.
    uint256 internal constant LP_FUNDING = 1_000_000 * 10 ** 6;

    IPoolManager internal poolManager;
    PoolModifyLiquidityTest internal liquidityRouter;

    DeployStandbyHook internal hookDeployer;
    StandbyHook internal hook;

    DeterministicFixtureDeployer internal fixtureDeployer;
    MockUSTB internal ustb;
    MockUSDC internal usdc;
    bytes32 internal currencySalt;

    PoolKey internal canonicalPoolKey;
    PoolKey internal geometryPoolKey;

    PoolId internal canonicalPoolId;
    PoolId internal geometryPoolId;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Builds the canonical deterministic economic fixture through real v4 execution paths.
    function setUp() public {
        poolManager = IPoolManager(address(new PoolManager(address(this))));
        liquidityRouter = new PoolModifyLiquidityTest(poolManager);

        hookDeployer = new DeployStandbyHook();
        (hook,) = hookDeployer.deployStandbyHook(poolManager, address(hookDeployer));

        fixtureDeployer = new DeterministicFixtureDeployer();
        (ustb, usdc, currencySalt) = fixtureDeployer.deployOrderedFixtureCurrencies();

        canonicalPoolKey = _fixturePoolKey(IHooks(address(hook)));
        geometryPoolKey = _fixturePoolKey(IHooks(address(0)));

        canonicalPoolId = canonicalPoolKey.toId();
        geometryPoolId = geometryPoolKey.toId();

        uint160 sqrtPriceInitialX96 = TickMath.getSqrtPriceAtTick(StandbyFixtureConfig.INITIAL_TICK);

        poolManager.initialize(canonicalPoolKey, sqrtPriceInitialX96);
        poolManager.initialize(geometryPoolKey, sqrtPriceInitialX96);

        ustb.mint(address(this), LP_FUNDING);
        usdc.mint(address(this), LP_FUNDING);

        ustb.approve(address(liquidityRouter), type(uint256).max);
        usdc.approve(address(liquidityRouter), type(uint256).max);

        liquidityRouter.modifyLiquidity(geometryPoolKey, _canonicalLiquidityParams(), bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                   G1-A — DETERMINISTIC CURRENCY IDENTITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves both canonical fixture currencies use exactly six decimals.
    function test_fixtureCurrencies_useExactlySixDecimals() public view {
        assertEq(ustb.decimals(), 6, "MockUSTB must use six decimals");
        assertEq(usdc.decimals(), 6, "MockUSDC must use six decimals");

        assertEq(ustb.decimals(), StandbyFixtureConfig.CURRENCY_DECIMALS, "MockUSTB decimals must be canonical");
        assertEq(usdc.decimals(), StandbyFixtureConfig.CURRENCY_DECIMALS, "MockUSDC decimals must be canonical");
    }

    /// @notice Proves the deployed fixture currencies satisfy `address(MockUSTB) < address(MockUSDC)`.
    function test_fixtureCurrencies_satisfyRequiredAddressOrdering() public view {
        assertLt(uint160(address(ustb)), uint160(address(usdc)), "MockUSTB must be the lower address");
    }

    /// @notice Proves the ordering is produced by construction, not observed after the fact.
    /// @dev The deployer selects a salt from the actual CREATE2 deployer address and the actual mock
    ///      init-code hashes, predicts both addresses before deploying, and the deployed currencies are
    ///      exactly those predictions. The relation therefore holds by the deployment procedure, and no
    ///      post-deployment relabelling took place.
    function test_deterministicDeployment_predictsTheOrderedAddressesBeforeDeploying() public view {
        address predictedUstb = fixtureDeployer.predictAddress(currencySalt, keccak256(type(MockUSTB).creationCode));
        address predictedUsdc = fixtureDeployer.predictAddress(currencySalt, keccak256(type(MockUSDC).creationCode));

        assertEq(address(ustb), predictedUstb, "MockUSTB must deploy to its predicted address");
        assertEq(address(usdc), predictedUsdc, "MockUSDC must deploy to its predicted address");
        assertLt(uint160(predictedUstb), uint160(predictedUsdc), "the predicted addresses must already be ordered");

        assertEq(fixtureDeployer.findOrderedSalt(), currencySalt, "salt selection must be deterministic");
    }

    /// @notice Proves the ordering guarantee does not depend on which deployer address is used.
    /// @dev A second deployer at a different address selects its own salt and still produces ordered
    ///      currencies. Ordering is a guarantee of the mechanism rather than luck of one deployment.
    function test_deterministicDeployment_guaranteesOrderingFromAnyDeployerAddress() public {
        DeterministicFixtureDeployer secondDeployer = new DeterministicFixtureDeployer();

        assertNotEq(address(secondDeployer), address(fixtureDeployer), "the second deployer must differ");

        (MockUSTB secondUstb, MockUSDC secondUsdc,) = secondDeployer.deployOrderedFixtureCurrencies();

        assertLt(
            uint160(address(secondUstb)), uint160(address(secondUsdc)), "ordering must hold for the second deployer"
        );
        assertNotEq(address(secondUstb), address(ustb), "the second deployment must be independent");
    }

    /*//////////////////////////////////////////////////////////////
                    G1-A — CANONICAL POOL IDENTITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the canonical PoolKey binds the ordered currencies, fee, spacing, and real Hook.
    function test_canonicalPoolKey_bindsOrderedCurrenciesFeeSpacingAndStandbyHook() public view {
        assertEq(Currency.unwrap(canonicalPoolKey.currency0), address(ustb), "currency0 must be MockUSTB");
        assertEq(Currency.unwrap(canonicalPoolKey.currency1), address(usdc), "currency1 must be MockUSDC");

        assertEq(canonicalPoolKey.fee, 500, "fee must be 500 pips");
        assertEq(canonicalPoolKey.tickSpacing, int24(10), "tick spacing must be 10");

        assertEq(address(canonicalPoolKey.hooks), address(hook), "the canonical pool must bind StandbyHook");
    }

    /// @notice Proves the canonical protected fixture direction is zeroForOne: MockUSTB -> MockUSDC.
    /// @dev The protected output currency is therefore MockUSDC, in which capacity, obligation, and
    ///      entitlement are denominated. This is a fixture fact only; Standby must never assume that
    ///      zeroForOne, currency0, or six decimals are protected in general.
    function test_canonicalProtectedDirection_isZeroForOneFromMockUSTBToMockUSDC() public view {
        assertTrue(StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE, "protected direction must be zeroForOne");

        assertEq(Currency.unwrap(canonicalPoolKey.currency0), address(ustb), "the protected input currency is MockUSTB");
        assertEq(
            Currency.unwrap(canonicalPoolKey.currency1), address(usdc), "the protected output currency is MockUSDC"
        );
    }

    /// @notice Proves the canonical Hook-bound pool was initialized through the real PoolManager at tick 0.
    function test_canonicalPool_isInitializedThroughRealPoolManagerAtTickZero() public view {
        (uint160 sqrtPriceX96, int24 tick,, uint24 lpFee) = poolManager.getSlot0(canonicalPoolId);

        assertEq(tick, int24(0), "the canonical initial tick must be exactly 0");
        assertEq(sqrtPriceX96, TickMath.getSqrtPriceAtTick(0), "the canonical initial price must be the tick-0 price");
        assertEq(lpFee, 500, "the authoritative LP fee must be 500 pips");
    }

    /*//////////////////////////////////////////////////////////////
                  G1-A — CANONICAL LIQUIDITY GEOMETRY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the canonical geometry pool is authoritatively initialized at tick 0.
    function test_geometryPool_isInitializedAtTickZeroWithCanonicalFeeAndSpacing() public view {
        (uint160 sqrtPriceX96, int24 tick,, uint24 lpFee) = poolManager.getSlot0(geometryPoolId);

        assertEq(tick, int24(0), "the geometry pool initial tick must be exactly 0");
        assertEq(sqrtPriceX96, TickMath.getSqrtPriceAtTick(0), "the geometry pool price must be the tick-0 price");
        assertEq(lpFee, 500, "the authoritative LP fee must be 500 pips");
        assertEq(geometryPoolKey.tickSpacing, int24(10), "tick spacing must be 10");
    }

    /// @notice Proves the canonical LP position exists over [-300, +300] with the canonical liquidity.
    /// @dev The position is read back from authoritative PoolManager state rather than inferred from the
    ///      requested liquidity delta.
    function test_canonicalLiquidityPosition_isEstablishedOverTheCanonicalRange() public view {
        (uint128 positionLiquidity,,) = poolManager.getPositionInfo(
            geometryPoolId,
            address(liquidityRouter),
            StandbyFixtureConfig.LP_TICK_LOWER,
            StandbyFixtureConfig.LP_TICK_UPPER,
            bytes32(0)
        );

        assertEq(positionLiquidity, uint128(6_707_079_990_254), "the canonical position liquidity must be exact");
    }

    /// @notice Proves the canonical liquidity is actually active at the canonical initial tick.
    function test_canonicalActiveLiquidity_isExactlyTheCanonicalAmount() public view {
        uint128 activeLiquidity = poolManager.getLiquidity(geometryPoolId);

        assertEq(activeLiquidity, uint128(6_707_079_990_254), "active liquidity must be the canonical amount");
        assertEq(
            activeLiquidity, StandbyFixtureConfig.CANONICAL_LIQUIDITY, "active liquidity must match the fixture config"
        );
    }

    /// @notice Proves no initialized liquidity boundary lies strictly inside the service domain.
    /// @dev The canonical demonstration must remain inside one constant active-liquidity interval, so
    ///      the LP boundaries must sit outside [tickQ, tickO].
    function test_canonicalLiquidityRange_enclosesTheServiceDomain() public pure {
        assertLt(StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.TICK_Q, "LP lower must be below tickQ");
        assertGt(StandbyFixtureConfig.LP_TICK_UPPER, StandbyFixtureConfig.TICK_O, "LP upper must be above tickO");
    }

    /*//////////////////////////////////////////////////////////////
                       G1-B — INDEPENDENT ECONOMICS
    //////////////////////////////////////////////////////////////*/

    /// @notice Independently derives initial protected capacity from actual canonical v4 state.
    /// @dev The inputs are read from authoritative PoolManager state, not from the fixture constants, and
    ///      the derivation is performed by the independent oracle rather than by any Standby production
    ///      code. At F1 no production Supporting Capacity implementation exists.
    function test_independentReference_derivesEightyThousandMockUSDCFromActualPoolState() public view {
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(geometryPoolId);
        uint128 activeLiquidity = poolManager.getLiquidity(geometryPoolId);

        uint256 capacity = ReferenceCalculations.protectedCapacityZeroForOne(
            sqrtPriceX96, StandbyFixtureConfig.TICK_Q, activeLiquidity
        );

        assertEq(capacity, 80_000_000_000, "initial capacity must be 80,000,000,000 raw MockUSDC units");
        assertEq(capacity, FROZEN_EXPECTED_INITIAL_S, "initial capacity must be 80,000.000000 MockUSDC");
        assertEq(capacity, StandbyFixtureConfig.EXPECTED_INITIAL_S, "initial capacity must match the fixture config");
    }

    /// @notice Proves the reference derivation depends on the actual pool state rather than constants.
    /// @dev Deriving from a different liquidity produces a different capacity, so a passing canonical
    ///      assertion cannot be an artifact of the oracle ignoring its inputs.
    function test_independentReference_dependsOnActualLiquidity() public view {
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(geometryPoolId);

        uint256 halfLiquidityCapacity = ReferenceCalculations.protectedCapacityZeroForOne(
            sqrtPriceX96, StandbyFixtureConfig.TICK_Q, StandbyFixtureConfig.CANONICAL_LIQUIDITY / 2
        );

        assertApproxEqAbs(
            halfLiquidityCapacity, StandbyFixtureConfig.EXPECTED_INITIAL_S / 2, 1, "capacity must scale with liquidity"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        F1 STRUCTURAL BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the Hook-bound canonical pool holds no liquidity at F1.
    /// @dev Frozen realization requirement RR-CONFIG-1 initializes the pool, binding the Hook, before
    ///      Standby configuration and before liquidity, and `configureAndActivate` later requires zero
    ///      pool liquidity. The canonical Hook-bound pool must therefore be empty at this point.
    function test_canonicalHookBoundPool_holdsNoLiquidityAtF1() public view {
        assertEq(poolManager.getLiquidity(canonicalPoolId), 0, "the canonical pool must hold no liquidity at F1");
    }

    /// @notice Proves liquidity cannot yet be added to the Hook-bound canonical pool.
    /// @dev The Hook's `beforeAddLiquidity` permission is enabled and still fails closed with
    ///      `HookNotImplemented`. Authoritative liquidity admission belongs to the later enforcement
    ///      slice that implements it, and F1 must not supply that behavior to make a fixture convenient.
    ///      This is the concrete evidence that the canonical liquidity position cannot be established in
    ///      the Hook-bound pool at F1.
    function test_canonicalHookBoundPool_rejectsLiquidityAdditionUntilEnforcementIsImplemented() public {
        bytes memory expectedRevert = abi.encodeWithSelector(
            CustomRevert.WrappedError.selector,
            address(hook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(BaseHook.HookNotImplemented.selector),
            abi.encodePacked(Hooks.HookCallFailed.selector)
        );

        vm.expectRevert(expectedRevert);
        liquidityRouter.modifyLiquidity(canonicalPoolKey, _canonicalLiquidityParams(), bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a fixture PoolKey over the deterministically ordered currencies.
    function _fixturePoolKey(IHooks _hooks) internal view returns (PoolKey memory key) {
        key = PoolKey({
            currency0: Currency.wrap(address(ustb)),
            currency1: Currency.wrap(address(usdc)),
            fee: StandbyFixtureConfig.LP_FEE,
            tickSpacing: StandbyFixtureConfig.TICK_SPACING,
            hooks: _hooks
        });
    }

    /// @dev The canonical liquidity modification: the full service domain plus a margin on each side.
    function _canonicalLiquidityParams() internal pure returns (ModifyLiquidityParams memory params) {
        params = ModifyLiquidityParams({
            tickLower: StandbyFixtureConfig.LP_TICK_LOWER,
            tickUpper: StandbyFixtureConfig.LP_TICK_UPPER,
            liquidityDelta: int256(uint256(StandbyFixtureConfig.CANONICAL_LIQUIDITY)),
            salt: bytes32(0)
        });
    }
}
