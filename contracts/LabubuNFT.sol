// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LabubuNFT is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    /// @custom:storage-location erc7201:LabubuNFT
    struct LabubuNFTStorage {
        uint256 _nextTokenId;
    }

    // keccak256(abi.encode(uint256(keccak256("LabubuNFT")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LABUBUNFT_STORAGE_LOCATION = 0x5b1b2a94b5f0a52bec0bd3d813aeb21e1c88da10ce0190d331abd301cee1d200;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address minter, address upgrader)
    public
    initializer
    {
        __ERC721_init("LABUBU NFT", "LNFT");
        __ERC721Enumerable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function safeMint(address to) public onlyRole(MINTER_ROLE) returns (uint256) {
        LabubuNFTStorage storage $ = _getLabubuNFTStorage();
        uint256 tokenId = $._nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function _getLabubuNFTStorage()
    private
    pure
    returns (LabubuNFTStorage storage $)
    {
        assembly {$.slot := LABUBUNFT_STORAGE_LOCATION}
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyRole(UPGRADER_ROLE)
    {}

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
    internal
    override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
    internal
    override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
