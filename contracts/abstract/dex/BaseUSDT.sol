// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Distributor {
    constructor(address _USDT) {
        IERC20(_USDT).approve(msg.sender, type(uint256).max);
    }
}

abstract contract BaseUSDT {
    bool public inSwapAndLiquify;
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    Distributor public immutable distributor;
    address public immutable USDT;
    bool public immutable isFirstReserveU;

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor(address _USDT, address _ROUTER) {
        USDT = _USDT;
        uniswapV2Router = IUniswapV2Router02(_ROUTER);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), _USDT);
        distributor = new Distributor(_USDT);

        isFirstReserveU = IUniswapV2Pair(uniswapV2Pair).token0() == _USDT;
    }

    function getReserves() public view returns (uint112, uint112) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(uniswapV2Pair).getReserves();
        if (isFirstReserveU) {
            return (reserve0, reserve1);
        } else {
            return (reserve1, reserve0);
        }
    }
}
