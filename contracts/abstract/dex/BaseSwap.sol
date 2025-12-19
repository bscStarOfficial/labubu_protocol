// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

abstract contract BaseSwap {
    IUniswapV2Router02 public immutable ROUTER;
    uint public constant slippage = 5;

    constructor(address ROUTER_) {
        ROUTER = IUniswapV2Router02(ROUTER_);
    }

    function swapExactTokensForTokensSF(
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMin,
        address to
    ) internal {
        address[] memory path = new address[](2);
        path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        if (amountOutMin == 0) {
            uint[] memory amounts = ROUTER.getAmountsOut(amountIn, path);
            amountOutMin = amounts[amounts.length - 1] * (100 - slippage) / 100;
        }

        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            block.timestamp
        );
    }

    function swapTokensForExactTokens(
        address tokenIn,
        address tokenOut,
        uint amountOut,
        uint amountInMax,
        address to
    ) internal {
        address[] memory path = new address[](2);
        path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        ROUTER.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            to,
            block.timestamp
        );
    }
}
