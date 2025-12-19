// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ILabubuOracle {
    function setOpenPrice() external;
    function getDecline() external view returns (uint);
}
