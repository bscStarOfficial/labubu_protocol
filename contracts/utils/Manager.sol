// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "hardhat/console.sol";

contract Manager is Initializable, UUPSUpgradeable, AccessControlEnumerableUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 internal constant FOUNDATION = keccak256("FOUNDATION");
    bytes32 internal constant BIT_MINER = keccak256("BIT_MINER");
    bytes32 internal constant UPGRADE = keccak256("UPGRADE");
    bytes32 internal constant PARAM = keccak256("PARAM");
    /// @notice 发行权限
    bytes32 internal constant MINT = keccak256("MINT");
    bytes32 internal constant FREE = keccak256("FREE");

    function initialize() initializer virtual public {
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(UPGRADE, _msgSender());
        _grantRole(PARAM, _msgSender());
        _grantRole(FOUNDATION, _msgSender());
        _grantRole(MINT, _msgSender());
    }

    function allowUpgrade(address newImplementation, address sender) public view {
        require(hasRole(UPGRADE, sender), "!role");
        require(
            keccak256(Address.functionStaticCall(newImplementation, abi.encodeWithSignature('proxiableUUID()'))) ==
            keccak256(abi.encodePacked(ERC1967Utils.IMPLEMENTATION_SLOT)),
            "!UUID"
        );
    }

    function allowFoundation(address sender) public view {
        require(hasRole(FOUNDATION, sender), "!role");
    }

    function allowParam(address sender) public view {
        require(hasRole(PARAM, sender), "!role");
    }

    function allowMint(address sender) public view {
        require(hasRole(MINT, sender), "!role");
    }

    function allowBitMiner(address sender) public view {
        require(hasRole(BIT_MINER, sender), "!role");
    }

    function hasFreeRole(address sender) public view returns (bool) {
        return hasRole(FREE, sender);
    }

    function getKeccak256(string memory name) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(name));
    }

    // 如果newImplementation没有upgradeTo方法，则无法继续升级
    function _authorizeUpgrade(address newImplementation) internal view override {
        allowUpgrade(newImplementation, _msgSender());
    }
}
