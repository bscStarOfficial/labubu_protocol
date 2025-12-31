// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.20;

import "./interfaces/ILabubuOracle.sol";
import "./interfaces/IRegisterV2.sol";
import "hardhat/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IManager} from "./interfaces/IManager.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LabubuRecoupment is Initializable, UUPSUpgradeable {
    using SafeCast for uint;

    IManager public manager;
    address public labubu;
    ILabubuOracle public oracle;
    IRegisterV2 public registerV2;

    address public marketAddress; // 默认邀请人地址

    mapping(address => Recoupment) public recoupments;
    uint public quotaTimes; // 额度倍数

    uint16 constant public BASE_PERCENT = 2000;
    uint16[] public invitationAwardRates;


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

    event DistributeReferralReward(address indexed from, address indexed to, uint8 indexed level, uint tp, uint tokenAmount, uint usdtValue);
    event PayeeSet(address account, uint share);
    event DepositReward(uint amount);
    event SendReward(uint amount, address token);
    event Released(address account, uint amount);
    event Claimed(address account, uint labubuAmount, uint usdtAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        claim(msg.sender);
    }

    function initialize(
        address _marketAddress,
        IManager _manager,
        IRegisterV2 _registerV2,
        ILabubuOracle _oracle,
        address _labubu
    ) public initializer {
        __UUPSUpgradeable_init();
        manager = _manager;
        registerV2 = _registerV2;
        oracle = _oracle;
        labubu = _labubu;

        quotaTimes = 3;

        marketAddress = _marketAddress;
        invitationAwardRates.push(500);
        invitationAwardRates.push(400);
        invitationAwardRates.push(300);
        invitationAwardRates.push(200);
        for (uint8 i = 4; i < 10; i++) {
            invitationAwardRates.push(100);
        }
    }

    function distributeReferralReward(address account) external payable {
        require(
            manager.hasRole(keccak256("SKY_LABUBU"), msg.sender),
            "!labubu"
        );

        uint value = msg.value;

        uint bnbPrice = oracle.getBnbPrice();
        recoupments[account].deposit += value * 5 * bnbPrice / 1e12; // 20%
        recoupments[account].quota += value * 5 * quotaTimes * bnbPrice / 1e12;

        uint distributedReward;
        (address[] memory _referrers, uint realCount) = registerV2.getReferrers(account, 10);
        for (uint8 i = 0; i < realCount; i++) {
            address referrer = _referrers[i];
            uint reward = getReferrerReward(referrer, i, value);

            if (reward > 0) {
                // 回本
                (uint bnbAmount, uint bnbToU) = transferBnbCheckQuota(referrer, reward);
                emit DistributeReferralReward(account, referrer, i + 1, 0, bnbAmount, bnbToU);
                distributedReward += bnbAmount;
            }
        }

        // 剩余部分
        uint256 remaining = value - distributedReward;
        if (remaining > 0) {
            safeTransferETH(marketAddress, remaining);
        }
    }

    function getReferrerReward(address referrer, uint i, uint amount) internal view returns (uint) {
        uint256 rate = invitationAwardRates[i]; // 对应层级的万分比
        uint256 reward = amount * rate / BASE_PERCENT;
        if (reward == 0) return 0;
        if (payees[referrer].share == 0) return 0;

        bool eligible = false;
        if (i == 0) {
            eligible = true;
        } else if (i == 1) {
            eligible = invitationNumAboveThreshold(referrer, 3);
        } else if (i == 2) {
            eligible = invitationNumAboveThreshold(referrer, 5);
        } else if (i == 3) {
            eligible = invitationNumAboveThreshold(referrer, 7);
        } else {
            eligible = invitationNumAboveThreshold(referrer, 10);
        }

        return eligible ? reward : 0;
    }

    function getLeftQuota(address account) public view returns (uint) {
        Recoupment memory recoupment = recoupments[account];
        return recoupment.quota > recoupment.claimed ?
            recoupment.quota - recoupment.claimed : 0;
    }

    function invitationNumAboveThreshold(address account, uint256 num) internal view returns (bool) {
        uint256 validNum;
        address[] memory referrals = registerV2.getReferrals(account);
        for (uint8 i = 0; i < referrals.length; i++) {
            address referral = referrals[i];
            if (payees[referral].share > 0) {
                validNum++;
            }
            if (validNum >= num) {
                break;
            }
        }

        return validNum >= num;
    }

    // LP权重
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

    function sendReward(uint reward) external {
        _sendReward(reward);
        IERC20(labubu).transferFrom(msg.sender, address(this), reward);
    }

    function _sendReward(uint reward) internal {
        if (reward > 0 && statistic.total > 0) {
            unchecked {
                statistic.perDebt += reward * 1e12 / statistic.total;
            }
        }
    }

    // @notice 提取收益
    function claim(address account) public {
        Payee storage payee = payees[account];
        uint totalReward = payee.available;

        uint pending = pendingReward(account);
        if (pending > 0) {
            payee.debt = statistic.perDebt;
            totalReward += pending;
        }
        if (totalReward == 0) return;

        payee.available = 0;
        payee.claimed += totalReward;

        transferLabubuCheckQuota(account, totalReward, 8);

        // 20% 动态
        uint distributedReward;
        uint marketReward = totalReward * 2 / 10;
        (address[] memory _referrers, uint realCount) = registerV2.getReferrers(account, 10);
        for (uint8 i = 0; i < realCount; i++) {
            address referrer = _referrers[i];
            uint rReward = getReferrerReward(referrer, i, marketReward);

            if (rReward > 0) {
                (uint labubuAmount, uint labubuToU) = transferLabubuCheckQuota(referrer, rReward, 10);
                emit DistributeReferralReward(account, referrer, i + 1, 1, labubuAmount, labubuToU);
                distributedReward += labubuAmount;
            }
        }

        // 剩余部分
        uint256 remaining = marketReward - distributedReward;
        if (remaining > 0) {
            IERC20(labubu).transfer(marketAddress, remaining);
        }
    }

    function _release(address account) internal virtual {
        uint pending = pendingReward(account);
        if (pending > 0) {
            Payee storage payee = payees[account];

            payee.debt = statistic.perDebt;
            payee.available += pending;
            // 不计算leftQuota了，如果计算leftQuota，注意available要转换成u
            //
            emit Released(account, pending);
        }
    }

    // @notice 静态收益transferPtg为8，20%要转换成动态收益。动态收益transferPtg为10。
    function transferLabubuCheckQuota(address account, uint labubuAmount, uint transferPtg) internal returns (uint, uint) {
        // 额度检测
        uint leftQuota = getLeftQuota(account);
        if (leftQuota == 0) return (0, 0);

        uint price = oracle.getLabubuPrice();
        uint labubuToU = price * labubuAmount / 1e12;

        if (labubuToU > leftQuota) {
            labubuAmount = leftQuota * 1e12 / price;
            labubuToU = leftQuota;
        }

        if (labubuAmount > 0) {
            recoupments[account].claimed += labubuToU;
            IERC20(labubu).transfer(account, labubuAmount * transferPtg / 10);
            emit Claimed(account, labubuAmount, labubuToU);
        }

        return (labubuAmount, labubuToU);
    }

    function transferBnbCheckQuota(address account, uint bnbAmount) internal returns (uint, uint){
        // 额度检测
        uint leftQuota = getLeftQuota(account);
        if (leftQuota == 0) return (0, 0);

        uint price = oracle.getBnbPrice();
        uint bnbToU = price * bnbAmount / 1e12;

        if (bnbToU > leftQuota) {
            bnbAmount = leftQuota * 1e12 / price;
            bnbToU = leftQuota;
        }

        if (bnbAmount > 0) {
            recoupments[account].claimed += bnbToU;
            safeTransferETH(account, bnbAmount);
        }
        return (bnbAmount, bnbToU);
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'ETH_TRANSFER_FAILED');
    }

    // @notice pending
    function pendingReward(address account) public view returns (uint) {
        Payee memory payee = payees[account];
        return uint(statistic.perDebt - payee.debt) * payee.share / 1e12;
    }

    function availableReward(address account) public view returns (uint) {
        return payees[account].available + pendingReward(account);
    }

    function setOracle(ILabubuOracle _oracle) external {
        manager.allowFoundation(msg.sender);

        oracle = _oracle;
    }

    function setQuota(address account, uint quota) external {
        manager.allowFoundation(msg.sender);

        recoupments[account].quota = quota;
    }

    function setAvailableTest(address account, uint available) external {
        require(block.chainid == 31337, '!test');

        payees[account].available = available;
        payees[account].debt = statistic.perDebt;
    }


    function _authorizeUpgrade(address newImplementation) internal view override {
        manager.allowUpgrade(newImplementation, msg.sender);
    }
}
