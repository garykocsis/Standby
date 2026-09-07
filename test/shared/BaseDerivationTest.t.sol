// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {DeployStandbyHook} from "../../script/DeployStandbyHook.s.sol";
import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";
import {IEligibilityRegistry} from "../../src/interfaces/IEligibilityRegistry.sol";

import {StandbyDerivationHarness} from "../harness/StandbyDerivationHarness.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice A minimal exact-transfer ERC-20 whose decimal precision is chosen per deployment.
/// @dev Test instrumentation for the generalization evidence. Standby production code must never consult
///      `decimals()`, so this exists to make a configuration in which any such dependence would be
///      visible: two currencies with different precisions, neither of them the canonical six.
contract DerivationTestCurrency {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint8 public immutable i_decimals;

    uint256 public totalSupply;

    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a currency with the requested decimal precision.
    /// @param _decimals The decimal precision this currency reports.
    constructor(uint8 _decimals) {
        i_decimals = _decimals;
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the decimal precision of the currency.
    /// @return decimals_ The configured decimal precision.
    function decimals() external view returns (uint8 decimals_) {
        decimals_ = i_decimals;
    }

    /// @notice Mints currency to an account.
    /// @param _to The account receiving the minted currency.
    /// @param _amount The raw amount minted.
    function mint(address _to, uint256 _amount) external {
        totalSupply += _amount;
        balanceOf[_to] += _amount;
    }

    /// @notice Approves a spender to transfer currency on behalf of the caller.
    /// @param _spender The approved spender.
    /// @param _amount The approved raw amount.
    /// @return success Always true; failure reverts.
    function approve(address _spender, uint256 _amount) external returns (bool success) {
        allowance[msg.sender][_spender] = _amount;

        success = true;
    }

    /// @notice Transfers currency from the caller to another account.
    /// @param _to The recipient.
    /// @param _amount The raw amount transferred.
    /// @return success Always true; failure reverts.
    function transfer(address _to, uint256 _amount) external returns (bool success) {
        balanceOf[msg.sender] -= _amount;
        balanceOf[_to] += _amount;

        success = true;
    }

    /// @notice Transfers currency between accounts using an allowance.
    /// @param _from The account the transfer debits.
    /// @param _to The recipient.
    /// @param _amount The raw amount transferred.
    /// @return success Always true; failure reverts.
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool success) {
        uint256 approved = allowance[_from][msg.sender];

        if (approved != type(uint256).max) allowance[_from][msg.sender] = approved - _amount;

        balanceOf[_from] -= _amount;
        balanceOf[_to] += _amount;

        success = true;
    }
}

/// @notice A single-use CREATE2 deployer for derivation harnesses.
/// @dev Hook addresses must encode their permission bits, so every harness has to be mined. Mining
///      searches salts from zero and skips any address that already holds code, so a second search from
///      the same deployer with the same constructor arguments re-walks everything the first search
///      walked before it can find anything new — and a fixture that builds several services pays that
///      cost repeatedly, in one call frame, until it exhausts memory.
///
///      Giving each harness its own deployer gives each search its own address space, so every search
///      finds an early salt and the cost stays linear in the number of services. This contract holds no
///      state and no authority; it exists only to be a distinct CREATE2 origin.
contract DerivationHarnessDeployer {
    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys one derivation harness at the mined salt.
    /// @param _salt The salt mined against this deployer's address.
    /// @param _poolManager The PoolManager whose callbacks the Hook answers.
    /// @param _configurationAuthority The only account authorized to activate the service.
    /// @param _trustedUniversalRouter The trusted ordinary-swap perimeter.
    /// @param _trustedPositionManager The trusted liquidity perimeter.
    /// @return harness The deployed harness.
    function deploy(
        bytes32 _salt,
        IPoolManager _poolManager,
        address _configurationAuthority,
        address _trustedUniversalRouter,
        address _trustedPositionManager
    ) external returns (StandbyDerivationHarness harness) {
        harness = new StandbyDerivationHarness{salt: _salt}(
            _poolManager, _configurationAuthority, _trustedUniversalRouter, _trustedPositionManager
        );
    }
}

/// @notice Shared real-path fixture for F5 authoritative-derivation evidence.
/// @dev Every service this fixture builds is built the way a real one would be: the real pinned
///      `PoolManager`, the canonical `DeployStandbyHook` mining and deployment procedure, a real
///      `PoolManager.initialize`, the production `configureAndActivate` transition, and the official
///      pinned liquidity and swap routers. No pool state and no service state is written directly.
///
///      The Hook deployed here is `StandbyDerivationHarness` rather than the production `StandbyHook`,
///      for one structural reason: production's callbacks fail closed until their enforcement slice
///      exists, so a production Hook-bound pool can hold no liquidity and execute no swap. The harness
///      admits those callbacks and decides nothing. Everything the derivations read — price, tick, active
///      liquidity, the tick bitmap — is written by the real PoolManager.
///
///      The fixture is parameterized rather than canonical-only, because derivation correctness must not
///      be a property of one currency pair, one direction, one tick layout, or one decimal precision.
abstract contract BaseDerivationTest is Test {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The complete description of one Standby service configuration to build.
    /// @param decimals0 The decimal precision of currency0.
    /// @param decimals1 The decimal precision of currency1.
    /// @param protectedZeroForOne The protected swap direction.
    /// @param initialTick The tick whose exact price the pool is initialized at.
    /// @param tickQ The protected execution-quality boundary.
    /// @param tickO The opposite realization-domain boundary.
    /// @param lpTickLower The lower endpoint of the liquidity position.
    /// @param lpTickUpper The upper endpoint of the liquidity position.
    /// @param tickSpacing The pool tick spacing.
    /// @param lpFee The static LP fee, in pips.
    /// @param liquidity The liquidity added over the position.
    struct ServiceConfig {
        uint8 decimals0;
        uint8 decimals1;
        bool protectedZeroForOne;
        int24 initialTick;
        int24 tickQ;
        int24 tickO;
        int24 lpTickLower;
        int24 lpTickUpper;
        int24 tickSpacing;
        uint24 lpFee;
        uint128 liquidity;
    }

    /// @notice A built and activated Standby service, with its real pool and real liquidity.
    /// @param hook The deployed derivation harness Hook.
    /// @param poolKey The real Hook-bound PoolKey.
    /// @param poolId The identity of the service pool.
    /// @param currency0 The deployed currency0.
    /// @param currency1 The deployed currency1.
    /// @param config The configuration this service was built from.
    struct DeployedService {
        StandbyDerivationHarness hook;
        PoolKey poolKey;
        PoolId poolId;
        DerivationTestCurrency currency0;
        DerivationTestCurrency currency1;
        ServiceConfig config;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The bound on the deterministic search for correctly ordered currency addresses.
    uint256 internal constant MAX_CURRENCY_ORDERING_ATTEMPTS = 64;

    /// @dev Fixture funding. Far larger than any position or swap these tests establish.
    uint256 internal constant FIXTURE_FUNDING = 1e30;

    address internal configurationAuthority;
    address internal trustedUniversalRouter;
    address internal trustedPositionManager;
    address internal exerciseRouter;
    address internal establishmentAuthority;
    address internal registryAdmin;

    IPoolManager internal poolManager;
    PoolModifyLiquidityTest internal liquidityRouter;
    PoolSwapTest internal swapRouter;

    DeployStandbyHook internal hookDeployer;
    EligibilityRegistry internal registry;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Builds the real shared v4 and Standby environment the derivation fixtures deploy into.
    function setUp() public virtual {
        configurationAuthority = makeAddr("configurationAuthority");
        trustedUniversalRouter = makeAddr("trustedUniversalRouter");
        trustedPositionManager = makeAddr("trustedPositionManager");
        exerciseRouter = makeAddr("exerciseRouter");
        establishmentAuthority = makeAddr("establishmentAuthority");
        registryAdmin = makeAddr("registryAdmin");

        poolManager = IPoolManager(address(new PoolManager(address(this))));

        liquidityRouter = new PoolModifyLiquidityTest(poolManager);
        swapRouter = new PoolSwapTest(poolManager);

        hookDeployer = new DeployStandbyHook();
        registry = new EligibilityRegistry(registryAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical deterministic fixture configuration, from the frozen fixture constants.
    function _canonicalConfig() internal pure returns (ServiceConfig memory config) {
        config = ServiceConfig({
            decimals0: StandbyFixtureConfig.CURRENCY_DECIMALS,
            decimals1: StandbyFixtureConfig.CURRENCY_DECIMALS,
            protectedZeroForOne: StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            initialTick: StandbyFixtureConfig.INITIAL_TICK,
            tickQ: StandbyFixtureConfig.TICK_Q,
            tickO: StandbyFixtureConfig.TICK_O,
            lpTickLower: StandbyFixtureConfig.LP_TICK_LOWER,
            lpTickUpper: StandbyFixtureConfig.LP_TICK_UPPER,
            tickSpacing: StandbyFixtureConfig.TICK_SPACING,
            lpFee: StandbyFixtureConfig.LP_FEE,
            liquidity: StandbyFixtureConfig.CANONICAL_LIQUIDITY
        });
    }

    /// @dev Builds and activates a Standby service through real deployment and production transitions.
    ///
    ///      The order is the frozen one: initialize the pool, activate the service against the empty
    ///      pool, and only then add liquidity. Activation requires zero liquidity, so a fixture that
    ///      funded the pool first could not activate at all.
    function _deployService(ServiceConfig memory _config) internal returns (DeployedService memory service) {
        service = _prepareService(_config);

        _activateService(service);

        _fundAndApprove(service, address(this));

        if (_config.liquidity != 0) {
            _addLiquidity(service, _config.lpTickLower, _config.lpTickUpper, int256(uint256(_config.liquidity)));
        }
    }

    /// @dev Builds everything a service needs and stops short of activating it.
    ///
    ///      Split out so a test can attempt the production activation transition itself and observe how it
    ///      answers. A rejection test must reach the real `configureAndActivate` with a real initialized
    ///      pool behind it, or it would be proving something about a fixture rather than about admission.
    function _prepareService(ServiceConfig memory _config) internal returns (DeployedService memory service) {
        service.config = _config;

        (service.currency0, service.currency1) = _deployOrderedCurrencies(_config.decimals0, _config.decimals1);

        service.hook = _deployDerivationHarness();

        service.poolKey = PoolKey({
            currency0: Currency.wrap(address(service.currency0)),
            currency1: Currency.wrap(address(service.currency1)),
            fee: _config.lpFee,
            tickSpacing: _config.tickSpacing,
            hooks: IHooks(address(service.hook))
        });
        service.poolId = service.poolKey.toId();

        poolManager.initialize(service.poolKey, TickMath.getSqrtPriceAtTick(_config.initialTick));
    }

    /// @dev Runs the production activation transition for a prepared service.
    function _activateService(DeployedService memory _service) internal {
        vm.prank(configurationAuthority);
        _service.hook.configureAndActivate(
            _service.poolKey,
            _service.config.protectedZeroForOne,
            _service.config.tickQ,
            _service.config.tickO,
            IEligibilityRegistry(address(registry)),
            exerciseRouter,
            establishmentAuthority
        );
    }

    /// @dev Deploys two currencies whose addresses already satisfy the Uniswap ordering requirement.
    ///
    ///      The decimal precisions are assigned to `currency0` and `currency1` by the caller, so a
    ///      redeploy is used to obtain the ordering rather than relabelling the two after the fact —
    ///      relabelling would silently swap the precisions the test intended.
    function _deployOrderedCurrencies(uint8 _decimals0, uint8 _decimals1)
        internal
        returns (DerivationTestCurrency currency0, DerivationTestCurrency currency1)
    {
        for (uint256 attempt = 0; attempt < MAX_CURRENCY_ORDERING_ATTEMPTS; ++attempt) {
            DerivationTestCurrency candidate0 = new DerivationTestCurrency(_decimals0);
            DerivationTestCurrency candidate1 = new DerivationTestCurrency(_decimals1);

            if (address(candidate0) < address(candidate1)) return (candidate0, candidate1);
        }

        revert("ordered currency deployment failed");
    }

    /// @dev Mines and deploys a derivation harness at an address encoding the required permission bits.
    ///
    ///      The mask is the one the canonical production deployment procedure owns, so the harness is a
    ///      real permission-valid Hook rather than an address-unconstrained stand-in.
    function _deployDerivationHarness() internal returns (StandbyDerivationHarness deployed) {
        DerivationHarnessDeployer deployer = new DerivationHarnessDeployer();

        bytes memory constructorArgs =
            abi.encode(poolManager, configurationAuthority, trustedUniversalRouter, trustedPositionManager);

        (, bytes32 salt) = HookMiner.find(
            address(deployer),
            hookDeployer.REQUIRED_HOOK_PERMISSION_MASK(),
            type(StandbyDerivationHarness).creationCode,
            constructorArgs
        );

        deployed =
            deployer.deploy(salt, poolManager, configurationAuthority, trustedUniversalRouter, trustedPositionManager);
    }

    /// @dev Funds an account with both currencies and approves the official routers on its behalf.
    function _fundAndApprove(DeployedService memory _service, address _account) internal {
        _service.currency0.mint(_account, FIXTURE_FUNDING);
        _service.currency1.mint(_account, FIXTURE_FUNDING);

        vm.startPrank(_account);

        _service.currency0.approve(address(liquidityRouter), type(uint256).max);
        _service.currency1.approve(address(liquidityRouter), type(uint256).max);
        _service.currency0.approve(address(swapRouter), type(uint256).max);
        _service.currency1.approve(address(swapRouter), type(uint256).max);

        vm.stopPrank();
    }

    /// @dev Modifies liquidity through the official pinned router and the real PoolManager.
    function _addLiquidity(DeployedService memory _service, int24 _tickLower, int24 _tickUpper, int256 _liquidityDelta)
        internal
    {
        liquidityRouter.modifyLiquidity(
            _service.poolKey,
            ModifyLiquidityParams({
                tickLower: _tickLower,
                tickUpper: _tickUpper,
                liquidityDelta: _liquidityDelta,
                salt: bytes32(0)
            }),
            bytes("")
        );
    }

    /// @dev Executes a swap through the official pinned router and the real PoolManager.
    function _swap(DeployedService memory _service, SwapParams memory _params) internal {
        swapRouter.swap(
            _service.poolKey, _params, PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}), bytes("")
        );
    }

    /// @dev Reads the authoritative current square-root price, tick, and active liquidity.
    function _poolState(DeployedService memory _service)
        internal
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint128 liquidity)
    {
        (sqrtPriceX96, tick,,) = poolManager.getSlot0(_service.poolId);

        liquidity = poolManager.getLiquidity(_service.poolId);
    }

    /// @dev Builds swap parameters whose price limit stops exactly at a chosen tick's price.
    function _swapToTickLimit(bool _zeroForOne, int256 _amountSpecified, int24 _limitTick)
        internal
        pure
        returns (SwapParams memory params)
    {
        params = SwapParams({
            zeroForOne: _zeroForOne,
            amountSpecified: _amountSpecified,
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(_limitTick)
        });
    }
}
