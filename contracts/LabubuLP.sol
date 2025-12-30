// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IManager} from "./interfaces/IManager.sol";
import "hardhat/console.sol";

contract LabubuLP is Initializable, UUPSUpgradeable {
    using SafeCast for uint;

    IManager public manager;
    address public labubu;

    mapping(address => Payee) public payees;
    Statistic public statistic;

    struct Payee {
        uint40 share;
        uint128 debt;
        uint released; // 这里的released 应该叫claimed更合适
        uint available;
    }


    struct Statistic {
        uint128 total;
        uint128 perDebt;
    }

    event PayeeSet(address account, uint share);
    event DepositReward(uint amount);
    event SendReward(uint amount, address token);
    event Released(address account, uint amount);
    // TODO usdAmount
    event Claimed(address account, uint amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IManager _manager, address _labubu) public initializer {
        __UUPSUpgradeable_init();

        manager = _manager;
        labubu = _labubu;
    }

    function setPayee(address account, uint40 shares) external {
        require(
            manager.hasRole(keccak256("SKY_LABUBU"), msg.sender),
            "!labubu"
        );

        _release(account);

        Payee storage payee = payees[account];
        if (shares > payee.share) {
            uint40 plus = shares - payee.share;
            statistic.total += plus;
            payee.share += plus;
        } else {
            uint40 sub = payee.share - shares;
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

        if (reward > 0) {
            payee.available = 0;
            payee.released += reward;

            IERC20(labubu).transfer(account, reward);

            emit Claimed(account, reward);
        }
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

    function _authorizeUpgrade(address newImplementation) internal view override {
        manager.allowUpgrade(newImplementation, msg.sender);
    }
}
