// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.20;

import "./interfaces/ILabubuOracle.sol";
import "hardhat/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IManager} from "./interfaces/IManager.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LabubuLP is Initializable, UUPSUpgradeable {
    using SafeCast for uint;

    IManager public manager;
    address public labubu;
    ILabubuOracle public oracle;

    mapping(address => Recoupment) public recoupments;
    uint public quotaTimes; // 额度倍数

    mapping(address => Payee) public payees;
    Statistic public statistic;

    struct Payee {
        uint share;
        uint debt;
        uint claimed;
        uint available;
    }

    struct Recoupment {
        uint deposit;
        uint quota; // 收益额度
        uint claimed;
    }

    struct Statistic {
        uint total;
        uint perDebt;
    }

    event PayeeSet(address account, uint share);
    event DepositReward(uint amount);
    event SendReward(uint amount, address token);
    event Released(address account, uint amount);
    // TODO usdAmount
    event Claimed(address account, uint labubuAmount, uint usdtAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IManager _manager, address _labubu) public initializer {
        __UUPSUpgradeable_init();
        manager = _manager;
        labubu = _labubu;

        quotaTimes = 3;
    }

    function addRecoupmentDeposit(address account, uint amount) external {
        recoupments[account].deposit += amount;
        recoupments[account].quota += amount * quotaTimes;
    }

    function addRecoupmentClaimed(address account, uint amount) external {
        recoupments[account].claimed += amount;
    }

    function getLeftQuota(address account) public view returns (uint) {
        Recoupment memory recoupment = recoupments[account];
        return recoupment.quota > recoupment.claimed ?
            recoupment.quota - recoupment.claimed : 0;
    }

    function setPayee(address account, uint shares) external {
        require(
            manager.hasRole(keccak256("SKY_LABUBU"), msg.sender),
            "!labubu"
        );

        _release(account);

        Payee storage payee = payees[account];
        if (shares > payee.share) {
            uint plus = shares - payee.share;
            statistic.total += plus;
            payee.share += plus;
        } else {
            uint sub = payee.share - shares;
            statistic.total -= sub;
            payee.share -= sub;
        }

        // release中只有在pending>0，才会修改debt
        payee.debt = statistic.perDebt;

        emit PayeeSet(account, shares);
    }

    function release(address account) external {
        _release(account);
    }

    function sendReward(uint amount) external {
        _sendReward(amount);
        IERC20(labubu).transferFrom(msg.sender, address(this), amount);
    }

    function _sendReward(uint reward) internal {
        if (reward > 0 && statistic.total > 0) {
            unchecked {
                statistic.perDebt += (reward / statistic.total).toUint128();
            }
        }
    }

    // @notice 提取收益
    function claim(address account) external {
        Payee storage payee = payees[account];
        uint reward = payee.available;

        uint pending = pendingReward(account);
        if (pending > 0) {
            payee.debt = statistic.perDebt;
            reward += pending;
        }
        if (reward == 0) return;

        payee.available = 0;
        payee.claimed += reward;

        // 额度检测
        uint quota = getLeftQuota(account);
        if (quota == 0) return;

        if (reward > getLeftQuota(account))
            reward = getLeftQuota(account);

        IERC20(labubu).transfer(account, reward);
        emit Claimed(account, reward, getUsdtValue(reward));
    }

    function _release(address account) internal virtual {
        uint pending = pendingReward(account);
        if (pending > 0) {
            Payee storage payee = payees[account];

            payee.debt = statistic.perDebt;
            payee.available += pending;

            emit Released(account, pending);
        }
    }

    // @notice pending
    function pendingReward(address account) public view returns (uint) {
        Payee memory payee = payees[account];
        return uint(statistic.perDebt - payee.debt) * payee.share;
    }

    function availableReward(address account) public view returns (uint) {
        return payees[account].available + pendingReward(account);
    }

    function getUsdtValue(uint labubuAmount) internal view returns (uint) {
        return oracle.getLabubuPrice() * labubuAmount / 1e12;
    }

    function setOracle(ILabubuOracle _oracle) external {
        manager.allowFoundation(msg.sender);

        oracle = _oracle;
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        manager.allowUpgrade(newImplementation, msg.sender);
    }
}
