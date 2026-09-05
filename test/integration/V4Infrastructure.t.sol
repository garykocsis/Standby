// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BaseV4Test} from "../shared/BaseV4Test.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

contract V4InfrastructureTest is BaseV4Test {
    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                         PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves vanilla Uniswap v4 can initialize a pool,
    ///         add liquidity, and execute a zero-for-one swap.
    function test_vanillaV4Infrastructure_zeroForOne() public {
        _initializePool();
        _addLiquidity();

        uint256 token0Before = token0.balanceOf(address(this));
        uint256 token1Before = token1.balanceOf(address(this));

        _swapExactInput(true, 1e18);

        uint256 token0After = token0.balanceOf(address(this));
        uint256 token1After = token1.balanceOf(address(this));

        assertLt(token0After, token0Before);
        assertGt(token1After, token1Before);
    }

    /// @notice Proves vanilla Uniswap v4 can initialize a pool,
    ///         add liquidity, and execute a one-for-zero swap.
    function test_vanillaV4Infrastructure_oneForZero() public {
        _initializePool();
        _addLiquidity();

        uint256 token0Before = token0.balanceOf(address(this));
        uint256 token1Before = token1.balanceOf(address(this));

        _swapExactInput(false, 1e18);

        uint256 token0After = token0.balanceOf(address(this));
        uint256 token1After = token1.balanceOf(address(this));

        assertGt(token0After, token0Before);
        assertLt(token1After, token1Before);
    }
}
