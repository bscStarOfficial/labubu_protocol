// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IRegisterV2 {
    function getReferrers(address user, uint count) external view returns (address[] memory _referrers, uint realCount);
    function registered(address user) external view returns (bool);
    function referrers(address) external view returns (address);
    function getReferrals(address user) external view returns (address[] memory);
    function register(address referral, address referrer) external;
}
