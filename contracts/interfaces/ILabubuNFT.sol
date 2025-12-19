// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ILabubuNFT {
    function safeMint(address to) external payable returns (uint256);
    function sendReward() external payable;
    function canDeposit(address account, uint value) external returns (bool);
}
