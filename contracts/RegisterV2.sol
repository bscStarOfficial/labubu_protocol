// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./libraries/RegisterHelper.sol";
import "./interfaces/IManager.sol";
import "hardhat/console.sol";

contract RegisterV2 is Initializable, UUPSUpgradeable, RegisterHelper {
    IManager public manager;

    event Registered(address referral, address referrer);

    function initialize(IManager _manager) initializer public {
        __UUPSUpgradeable_init();
        manager = _manager;
    }

    function register(address referrer) external {
        registerInternal(msg.sender, referrer);
        emit Registered(msg.sender, referrer);
    }

    function setReferrer(address referral, address referrer) external {
        manager.allowFoundation(msg.sender);

        referrers[referral] = referrer;
    }

    // 如果newImplementation没有upgradeTo方法，则无法继续升级
    function _authorizeUpgrade(address newImplementation) internal view override {
        manager.allowUpgrade(newImplementation, msg.sender);
    }
}
