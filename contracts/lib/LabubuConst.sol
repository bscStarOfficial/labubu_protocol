// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract LabubuConst {
    // 推荐奖励
    uint256 public constant MARKET_INCENTIVES = 4000;
    uint256 public constant BURN_AWARD_PERCENT = 25;
    uint256 public constant BURN_BLACK_PERCENT = 25;
    uint256 public constant BASE_PERCENT = 10000;
    uint256 public constant MIN_AMOUNT = 0.1 ether; // 最低入金

    address public constant BLACK_ADDRESS = address(0xdEaD);

    address public immutable bnbTokenAddress;
    address public immutable pancakeV2Router;
}

