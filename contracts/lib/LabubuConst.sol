// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract LabubuConst {
    // 推荐奖励
    uint256 public constant MARKET_INCENTIVES = 4000;
    uint256 public constant BASE_PERCENT = 10000;
    uint256 public constant MIN_AMOUNT = 0.1 ether; // 最低入金

    address public constant BLACK_ADDRESS = address(0xdEaD);
    address public constant SELL_MIDDLEWARE = address(0x1);// 有手续费
    address public constant BUY_MIDDLEWARE = address(0x2); // 买入不能转入address(this), 无手续费
    address public immutable bnbTokenAddress;
    address public immutable pancakeV2Router;
}

