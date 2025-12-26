// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IManager} from "./interfaces/IManager.sol";
import "hardhat/console.sol";

contract LabubuNFT is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, UUPSUpgradeable {
    uint256 public maxTokenId;   // 最大mint的id
    uint256 public maxDepositId; // 最大可入金Id
    uint256 public maxDailyAmount; // 每日最大可入金数量

    mapping(uint256 => uint256) public dailyAmount;
    mapping(address => bool) public depositWhitelist; // labubu入金白名单 此字段废弃
    uint256 public nftPrice;

    IManager public manager;
    address public reserve;

    mapping(address => Payee) public payees;
    uint256 public perDebt;
    bool public onlyAA;

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
        nftPrice = 0.6 ether;
        maxDailyAmount = 100 ether;

        manager = _manager;
        reserve = _reserve;

        onlyAA = true;
    }

    // 不能通过非钱包合约转，不然mint用户不对
    receive() external payable {
        safeMint(msg.sender);
    }

    function safeMint(address to) public payable returns (uint256) {
        if (onlyAA) require(isContract(to), 'onlyAA');

        require(msg.value == nftPrice, '!price');

        // 一个地址只能购买一张
        require(balanceOf(to) == 0, 'one');

        uint256 tokenId = totalSupply();
        require(tokenId <= maxTokenId, '!max');

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

    function canDeposit(address account, uint value) external returns (bool) {
        require(
            manager.hasRole(keccak256("SKY_LABUBU"), msg.sender),
            "!labubu"
        );

        uint256 day = block.timestamp / 86400;
        if (dailyAmount[day] + value >= maxDailyAmount) return false;
        dailyAmount[day] += value;

        if (manager.hasRole(keccak256('Deposit_Whitelist'), account))
            return true;

        uint balance = balanceOf(account);
        for (uint i = 0; i < balance; i++) {
            uint tokenId = tokenOfOwnerByIndex(account, i);
            if (tokenId <= maxDepositId)
                return true;
        }
        return false;
    }

    function fistTokenId(address account) external view returns (uint) {
        if (balanceOf(account) == 0) return 999999;
        else return tokenOfOwnerByIndex(account, 0);
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'ETH_TRANSFER_FAILED');
    }

    function setMaxTokenId(uint256 _maxTokenId) external {
        manager.allowFoundation(msg.sender);

        maxTokenId = _maxTokenId;
    }

    function setMaxDepositId(uint256 _maxDepositId) external {
        manager.allowFoundation(msg.sender);

        maxDepositId = _maxDepositId;
    }

    function setMaxDailyAmount(uint256 _maxDailyAmount) external {
        manager.allowFoundation(msg.sender);

        maxDailyAmount = _maxDailyAmount;
    }

    function setDepositWhitelist(address[] memory accounts, bool status) external {
        manager.allowFoundation(msg.sender);

        for (uint i = 0; i < accounts.length; i++) {
            depositWhitelist[accounts[i]] = status;
        }
    }

    function setOnlyAA(bool _onlyAA) external {
        manager.allowFoundation(msg.sender);

        onlyAA = _onlyAA;
    }

    function setNftPrice(uint256 _nftPrice) external {
        manager.allowFoundation(msg.sender);
        nftPrice = _nftPrice;
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        manager.allowUpgrade(newImplementation, msg.sender);
    }

    function _update(address to, uint256 tokenId, address auth)
    internal
    override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    returns (address)
    {
        require(_ownerOf(tokenId) == address(0), '!transfer');

        // 先释放奖励
        _release(_ownerOf(tokenId));
        _release(to);

        return super._update(to, tokenId, auth);
    }

    function _release(address account) internal virtual {
        if (account == address(0)) return;
        uint pending = pendingProfit(account);

        Payee storage payee = payees[account];

        payee.debt = perDebt;
        payee.available += pending;
    }

    function pendingProfit(address account) public view returns (uint pending) {
        Payee memory payee = payees[account];
        pending = (perDebt - payee.debt) * balanceOf(account);
    }

    function availableReward(address account) public view returns (uint) {
        return payees[account].available + pendingProfit(account);
    }

    function isContract(address _address) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_address)
        }
        return (size > 0);
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
