// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {DeployStandbyHook} from "../../script/DeployStandbyHook.s.sol";
import {DeterministicFixtureDeployer} from "../../script/helpers/DeterministicFixtureDeployer.sol";
import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";
import {IEligibilityRegistry} from "../../src/interfaces/IEligibilityRegistry.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockUSTB} from "../../src/mocks/MockUSTB.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared real-path fixture for F3 StandbyHook trust and Protected Execution Service evidence.
/// @dev Everything here is constructed through production paths: the real pinned `PoolManager`, the
///      canonical `DeployStandbyHook` procedure, the F1 deterministic ordered fixture currencies, the
///      F2 `EligibilityRegistry`, and real `PoolManager.initialize` calls. No Standby economic state is
///      written directly and no harness is used.
///
///      Every trust and authority role is given its own distinct address, so a test that passes cannot
///      be passing because two semantically distinct roles happen to be the same account.
abstract contract BaseStandbyServiceTest is Test {
    using PoolIdLibrary for PoolKey;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A pool fee distinct from the canonical fixture fee, used to build additional real pools
    ///      bound to the same Hook without colliding with the canonical PoolId.
    uint24 internal constant ALTERNATE_FEE = 3000;

    address internal configurationAuthority;
    address internal trustedUniversalRouter;
    address internal trustedPositionManager;
    address internal exerciseRouter;
    address internal establishmentAuthority;
    address internal registryAdmin;
    address internal unauthorizedAccount;

    IPoolManager internal poolManager;
    DeployStandbyHook internal hookDeployer;
    StandbyHook internal hook;
    EligibilityRegistry internal registry;

    DeterministicFixtureDeployer internal fixtureDeployer;
    MockUSTB internal ustb;
    MockUSDC internal usdc;

    PoolKey internal canonicalPoolKey;
    PoolId internal canonicalPoolId;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Builds the real unconfigured Standby environment: PoolManager, Hook, registry, currencies,
    ///         and the canonical Hook-bound pool initialized at the canonical tick with zero liquidity.
    function setUp() public virtual {
        configurationAuthority = makeAddr("configurationAuthority");
        trustedUniversalRouter = makeAddr("trustedUniversalRouter");
        trustedPositionManager = makeAddr("trustedPositionManager");
        exerciseRouter = makeAddr("exerciseRouter");
        establishmentAuthority = makeAddr("establishmentAuthority");
        registryAdmin = makeAddr("registryAdmin");
        unauthorizedAccount = makeAddr("unauthorizedAccount");

        poolManager = IPoolManager(address(new PoolManager(address(this))));

        hookDeployer = new DeployStandbyHook();
        hook = _deployHook(configurationAuthority, trustedUniversalRouter, trustedPositionManager);

        registry = new EligibilityRegistry(registryAdmin);

        fixtureDeployer = new DeterministicFixtureDeployer();
        (ustb, usdc,) = fixtureDeployer.deployOrderedFixtureCurrencies();

        canonicalPoolKey =
            _poolKeyFor(IHooks(address(hook)), StandbyFixtureConfig.LP_FEE, StandbyFixtureConfig.TICK_SPACING);
        canonicalPoolId = canonicalPoolKey.toId();

        _initializePoolAtTick(canonicalPoolKey, StandbyFixtureConfig.INITIAL_TICK);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Deploys a StandbyHook through the canonical production deployment procedure.
    function _deployHook(
        address _configurationAuthority,
        address _trustedUniversalRouter,
        address _trustedPositionManager
    ) internal returns (StandbyHook deployedHook) {
        (deployedHook,) = hookDeployer.deployStandbyHook(
            poolManager,
            address(hookDeployer),
            _configurationAuthority,
            _trustedUniversalRouter,
            _trustedPositionManager
        );
    }

    /// @dev Builds a PoolKey over the deterministically ordered fixture currencies.
    function _poolKeyFor(IHooks _hooks, uint24 _fee, int24 _tickSpacing) internal view returns (PoolKey memory key) {
        key = PoolKey({
            currency0: Currency.wrap(address(ustb)),
            currency1: Currency.wrap(address(usdc)),
            fee: _fee,
            tickSpacing: _tickSpacing,
            hooks: _hooks
        });
    }

    /// @dev Initializes a pool through the real PoolManager at the exact square-root price of a tick.
    function _initializePoolAtTick(PoolKey memory _key, int24 _tick) internal {
        poolManager.initialize(_key, TickMath.getSqrtPriceAtTick(_tick));
    }

    /// @dev Activates the canonical Protected Execution Service through the production transition.
    function _activateCanonicalService() internal returns (PoolId serviceId) {
        vm.prank(configurationAuthority);
        serviceId = hook.configureAndActivate(
            canonicalPoolKey,
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            StandbyFixtureConfig.TICK_Q,
            StandbyFixtureConfig.TICK_O,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );
    }

    /// @dev Proves a rejected activation attempt left no partial Protected Execution Service behind.
    function _assertNoServiceConfigured(StandbyHook _hook) internal view {
        StandbyHook.ProtectedExecutionService memory service = _hook.protectedExecutionService();

        assertFalse(service.configured, "no service-existence fact may persist");
        assertEq(Currency.unwrap(service.poolKey.currency0), address(0), "no currency0 may persist");
        assertEq(Currency.unwrap(service.poolKey.currency1), address(0), "no currency1 may persist");
        assertEq(uint256(service.poolKey.fee), 0, "no fee may persist");
        assertEq(service.poolKey.tickSpacing, int24(0), "no tick spacing may persist");
        assertEq(address(service.poolKey.hooks), address(0), "no hook binding may persist");
        assertEq(address(service.registry), address(0), "no registry may persist");
        assertFalse(service.protectedZeroForOne, "no protected direction may persist");
        assertEq(service.tickQ, int24(0), "no tickQ may persist");
        assertEq(service.tickO, int24(0), "no tickO may persist");
        assertEq(service.exerciseRouter, address(0), "no ExerciseRouter may persist");
        assertEq(service.establishmentAuthority, address(0), "no establishment authority may persist");

        try _hook.serviceId() returns (PoolId) {
            assertTrue(false, "an unconfigured Hook must report no service identity");
        } catch {}
    }
}
