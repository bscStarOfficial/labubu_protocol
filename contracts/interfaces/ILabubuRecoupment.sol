// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ILabubuRecoupment {
    function distributeReferralReward(address account) external payable;
    function sendReward(uint amount) external;
}
