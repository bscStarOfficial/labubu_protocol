// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IManager} from "./interfaces/IManager.sol";

contract LabubuNFT is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, UUPSUpgradeable {
    uint256 public maxTokenId;
    uint256 public nftPrice;

    IManager public manager;
    address public reserve;

    mapping(address => Payee) public payees;
    uint256 public perDebt;

    struct Payee {
        uint256 released;
        uint256 available;
        uint256 debt;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IManager _manager, address _reserve) public initializer {
        __ERC721_init("LABUBU NFT", "LNFT");
        __ERC721Enumerable_init();

        maxTokenId = 100;
        nftPrice = 0.55 ether;

        manager = _manager;
        reserve = _reserve;
    }

    // 不能通过非钱包合约转，不然mint用户不对
    receive() external payable {
        safeMint(msg.sender);
    }

    function safeMint(address to) public payable returns (uint256) {
        uint256 tokenId = totalSupply();
        require(tokenId <= maxTokenId, '!max');
        require(msg.value == nftPrice, '!price');

        _safeMint(to, tokenId);

        safeTransferETH(reserve, nftPrice);

        return tokenId;
    }

    // @notice 提取收益
    function claim(address account) external {
        _release(account);

        Payee storage payee = payees[account];
        safeTransferETH(account, payee.available);

        unchecked {
            payee.released += payee.available;
            payee.available = 0;
        }
    }

    function sendReward() external payable {
        if (totalSupply() > 0) {
            perDebt += msg.value / totalSupply();
        }
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'ETH_TRANSFER_FAILED');
    }

    function setMaxTokenId(uint256 _maxTokenId) external {
        manager.allowFoundation(msg.sender);

        maxTokenId = _maxTokenId;
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        manager.allowUpgrade(newImplementation, msg.sender);
    }

    function _update(address to, uint256 tokenId, address auth)
    internal
    override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    returns (address)
    {
        // 先释放奖励
        _release(ownerOf(tokenId));
        _release(to);

        return super._update(to, tokenId, auth);
    }

    function _release(address account) internal virtual {
        uint pending = pendingProfit(account);

        Payee storage payee = payees[account];

        payee.debt = perDebt;
        payee.available += pending;
    }

    function pendingProfit(address account) public view returns (uint pending) {
        Payee memory payee = payees[account];
        pending = (perDebt - payee.debt) * balanceOf(account);
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
    override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
