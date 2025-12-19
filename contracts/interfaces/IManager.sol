// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IManager {
    function allowWithdraw() external view;

    function allowUpgrade(address newImplementation, address sender) external view;

    function allowFoundation(address sender) external view;

    function allowParam(address sender) external view;

    function allowMint(address sender) external view;

    function allowBitMiner(address sender) external view;

    function paused() external view returns (bool);

    function hasFreeRole(address sender) external view returns (bool);

    function hasRole(bytes32 role, address account) external view returns (bool);
}
