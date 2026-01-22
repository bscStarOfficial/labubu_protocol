// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IManager} from "./interfaces/IManager.sol";
import {IPancakePair} from "./interfaces/IPancake.sol";
import "hardhat/console.sol";

contract LabubuOracle is Initializable, UUPSUpgradeable {
    IManager public manager;
    IPancakePair public pair;
    address public labubu;
    mapping(uint => uint) public labubuOpenPrice; // labubu openPrice
    uint private labubuTestPrice;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IManager _manager,
        IPancakePair _pair,
        address _labubu
    ) public initializer {
        __UUPSUpgradeable_init();

        manager = _manager;
        pair = _pair;
        labubu = _labubu;
    }

    function getDecline() public view returns (uint) {
        uint currentDay = block.timestamp / 86400;
        uint openPrice = labubuOpenPrice[currentDay];
        if (openPrice == 0) return 0;

        uint currentPrice = getLabubuPrice();
        if (currentPrice >= openPrice) return 0;

        uint rate = (openPrice - currentPrice) * 1e4 / openPrice;
        return rate - rate % 1e2;
    }

    // @notice star price 价格精度12
    function getLabubuPrice() public view returns (uint price) {
        if (labubuTestPrice != 0) return labubuTestPrice;

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        if (pair.token0() == labubu) {
            price = uint(reserve1) * getBnbPrice() / uint(reserve0);
        } else {
            price = uint(reserve0) * getBnbPrice() / uint(reserve1);
        }
    }

    // @notice bnb price 价格精度12
    function getBnbPrice() public view returns (uint price) {
        if (block.chainid != 56) price = 1000e12;
        else {
            (uint112 reserve0, uint112 reserve1,) = IPancakePair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE).getReserves();
            price = uint(reserve0) * 1e12 / uint(reserve1);
        }
    }

    function setOpenPrice() public returns (uint, uint) {
        uint currentDay = block.timestamp / 86400;
        uint currentPrice = getLabubuPrice();
        // 设置开盘价
        if (labubuOpenPrice[currentDay] == 0)
            labubuOpenPrice[currentDay] = currentPrice;

        return (currentDay, labubuOpenPrice[currentDay]);
    }

    function getOpenPrice() public view returns (uint, uint, bool) {
        uint currentDay = block.timestamp / 86400;
        bool isSet = labubuOpenPrice[currentDay] > 0;
        uint price = isSet ?
            labubuOpenPrice[currentDay] : getLabubuPrice();

        return (currentDay, price, isSet);
    }

    function setOpenPriceByAdmin(uint price) external {
        manager.allowFoundation(msg.sender);
        uint currentDay = block.timestamp / 86400;
        labubuOpenPrice[currentDay] = price;
    }

    function setLabubuPriceForTest(uint price) external {
        if (block.chainid == 31337) {
            labubuTestPrice = price;
        }
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        manager.allowUpgrade(newImplementation, msg.sender);
    }
}
