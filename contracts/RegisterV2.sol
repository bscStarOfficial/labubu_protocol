// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./lib/RegisterHelper.sol";
import "./interfaces/IManager.sol";
import "hardhat/console.sol";

contract RegisterV2 is UUPSUpgradeable, RegisterHelper {
    IManager public manager;

    event Registered(address referral, address referrer);

    function initialize(IManager _manager) initializer public {
        __UUPSUpgradeable_init();
        manager = _manager;
    }

    function register(address referral, address referrer) external {
        require(manager.hasRole(keccak256("SKY_LABUBU"), msg.sender), "!labubu");

        registerInternal(referral, referrer);
        emit Registered(referral, referrer);
    }

    function setReferrer(address referral, address referrer) external {
        manager.allowFoundation(msg.sender);
        registerInternal(referral, referrer);
        emit Registered(referral, referrer);
    }

    // 如果newImplementation没有upgradeTo方法，则无法继续升级
    function _authorizeUpgrade(address newImplementation) internal view override {
        manager.allowUpgrade(newImplementation, msg.sender);
    }
}
