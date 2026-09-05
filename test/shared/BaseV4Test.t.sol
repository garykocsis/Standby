// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {PoolManager} from "../../lib/v4-hooks-public/lib/v4-core/src/PoolManager.sol";
import {IPoolManager} from "../../lib/v4-hooks-public/lib/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "../../lib/v4-hooks-public/lib/v4-core/src/interfaces/IHooks.sol";

import {TickMath} from "../../lib/v4-hooks-public/lib/v4-core/src/libraries/TickMath.sol";

import {Currency} from "../../lib/v4-hooks-public/lib/v4-core/src/types/Currency.sol";
import {PoolKey} from "../../lib/v4-hooks-public/lib/v4-core/src/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "../../lib/v4-hooks-public/lib/v4-core/src/types/PoolOperation.sol";

import {PoolModifyLiquidityTest} from "../../lib/v4-hooks-public/lib/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "../../lib/v4-hooks-public/lib/v4-core/src/test/PoolSwapTest.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

contract TestToken {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string public name;
    string public symbol;

    uint8 public immutable i_decimals;

    uint256 public totalSupply;

    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        i_decimals = decimals_;
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the number of decimals used by the token.
    /// @return decimals_ The token decimal precision.
    function decimals() external view returns (uint8 decimals_) {
        decimals_ = i_decimals;
    }

    /// @notice Mints tokens to an account.
    /// @param to The account receiving the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    /// @notice Approves a spender to transfer tokens on behalf of the caller.
    /// @param spender The approved spender.
    /// @param amount The approved token amount.
    /// @return success Whether the approval succeeded.
    function approve(address spender, uint256 amount) external returns (bool success) {
        allowance[msg.sender][spender] = amount;
        success = true;
    }

    /// @notice Transfers tokens from the caller to another account.
    /// @param to The recipient.
    /// @param amount The amount transferred.
    /// @return success Whether the transfer succeeded.
    function transfer(address to, uint256 amount) external returns (bool success) {
        _transfer(msg.sender, to, amount);
        success = true;
    }

    /// @notice Transfers tokens between accounts using an allowance.
    /// @param from The account tokens are transferred from.
    /// @param to The recipient.
    /// @param amount The amount transferred.
    /// @return success Whether the transfer succeeded.
    function transferFrom(address from, address to, uint256 amount) external returns (bool success) {
        uint256 allowed = allowance[from][msg.sender];

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        _transfer(from, to, amount);

        success = true;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

abstract contract BaseV4Test is Test {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint160 internal constant SQRT_PRICE_1_1 = 1 << 96;

    uint24 internal constant FEE = 500;
    int24 internal constant TICK_SPACING = 10;

    int24 internal constant TICK_LOWER = -300;
    int24 internal constant TICK_UPPER = 300;

    uint256 internal constant INITIAL_TOKEN_BALANCE = 10_000_000e18;
    int256 internal constant INITIAL_LIQUIDITY = 1_000_000e18;

    PoolManager internal poolManager;
    PoolModifyLiquidityTest internal liquidityRouter;
    PoolSwapTest internal swapRouter;

    TestToken internal token0;
    TestToken internal token1;

    PoolKey internal poolKey;

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                         PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the vanilla Uniswap v4 infrastructure used by infrastructure tests.
    function setUp() public virtual {
        poolManager = new PoolManager(address(this));

        liquidityRouter = new PoolModifyLiquidityTest(IPoolManager(address(poolManager)));

        swapRouter = new PoolSwapTest(IPoolManager(address(poolManager)));

        TestToken tokenA = new TestToken("Token A", "TKNA", 18);
        TestToken tokenB = new TestToken("Token B", "TKNB", 18);

        if (address(tokenA) < address(tokenB)) {
            token0 = tokenA;
            token1 = tokenB;
        } else {
            token0 = tokenB;
            token1 = tokenA;
        }

        token0.mint(address(this), INITIAL_TOKEN_BALANCE);
        token1.mint(address(this), INITIAL_TOKEN_BALANCE);

        token0.approve(address(liquidityRouter), type(uint256).max);
        token1.approve(address(liquidityRouter), type(uint256).max);

        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);

        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _initializePool() internal {
        poolManager.initialize(poolKey, SQRT_PRICE_1_1);
    }

    function _addLiquidity() internal {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: INITIAL_LIQUIDITY,
            salt: bytes32(0)
        });

        liquidityRouter.modifyLiquidity(poolKey, params, bytes(""));
    }

    function _swapExactInput(bool zeroForOne, uint256 amountIn) internal {
        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;

        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        PoolSwapTest.TestSettings memory settings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        swapRouter.swap(poolKey, params, settings, bytes(""));
    }
}
