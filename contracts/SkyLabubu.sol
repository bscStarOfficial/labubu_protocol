// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ILabubuNFT.sol";
import "./interfaces/ILabubuOracle.sol";
import "./interfaces/IManager.sol";
import "./interfaces/IPancake.sol";
import "./interfaces/IRegisterV2.sol";
import "./interfaces/IWETH.sol";
import "./lib/LabubuConst.sol";
import "./lib/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "hardhat/console.sol";

contract SkyLabubu is ERC20Upgradeable, UUPSUpgradeable, LabubuConst {
    using SafeMath for uint256;

    uint256 public maxAmount;
    uint16[] public invitationAwardRates;

    ILabubuNFT public nft;
    ILabubuOracle public oracle;
    IManager public manager;
    IRegisterV2 public registerV2;

    address public marketAddress; // 默认邀请人地址
    address public deflationAddress; // 每日1%销毁地址
    address public sellFeeAddress; // 卖出手续费地址
    address public depositFeeAddress; // 10%入金手续费

    address public pancakePair;

    mapping(address => uint256) public accountSales;
    mapping(address => uint256) public directTeamSales;
    mapping(address => uint256) public addLiquidityUnlockTime;
    mapping(address => uint256) public accountLpAmount;

    uint256[] public removeLpBurnRate;

    bool public burnAndMintSwitch;
    uint256 public lastTriggerTime;

    event WithdrawalToken(address indexed token, address indexed receiver, uint indexed amount);
    event DistributeReferralReward(address indexed from, address indexed to, uint8 indexed level, uint256 amount);
    event TriggerDailyBurnAndMint(uint256 indexed liquidityPairBalance, uint256 indexed burnAmount, uint256 indexed holdLPAwardAmount, uint256 rounds);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _wBNB, address _router) {
        _disableInitializers();

        bnbTokenAddress = _wBNB;
        pancakeV2Router = _router;
    }

    function initialize(
        address _marketAddress,
        address _minter,
        address _sellFeeAddress,
        address _deflationAddress,
        address _depositFeeAddress,
        ILabubuNFT _nft,
        IManager _manager,
        IRegisterV2 _registerV2
    ) public initializer {
        // bnbTokenAddress 必须是token0
        require(address(this) > bnbTokenAddress, '!gt');

        __UUPSUpgradeable_init();
        __ERC20_init("Sky Labubu", "SkyLabubu");

        marketAddress = _marketAddress;
        nft = _nft;

        sellFeeAddress = _sellFeeAddress;
        deflationAddress = _deflationAddress;
        depositFeeAddress = _depositFeeAddress;
        manager = _manager;
        registerV2 = _registerV2;

        pancakePair = IPancakeFactory(
            IPancakeRouter02(pancakeV2Router).factory()
        ).createPair(address(this), bnbTokenAddress);

        _approve(address(this), pancakeV2Router, ~uint256(0));
        IERC20(bnbTokenAddress).approve(pancakeV2Router, ~uint256(0));

        removeLpBurnRate.push(9000);
        removeLpBurnRate.push(7000);
        removeLpBurnRate.push(5000);
        removeLpBurnRate.push(3000);

        invitationAwardRates.push(500);
        invitationAwardRates.push(400);
        invitationAwardRates.push(300);
        invitationAwardRates.push(200);
        for (uint8 i = 4; i < 10; i++) {
            invitationAwardRates.push(100);
        }
        maxAmount = 0.1 ether;

        // 初始供应量
        _mint(_minter, 210000000000 * 10 ** decimals());
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable returns (uint256) {
        uint256 value = msg.value;

        // 早期入金限制
        nft.canDeposit(msg.sender, value);

        if (value == 0.6 ether) {
            nft.safeMint{value: value}(msg.sender);
            return 0;
        }

        // 1e17 原版限制isContract(msg.sender)
        if (value < MIN_AMOUNT || value > maxAmount || value % 0.1 ether > 0) {
            revert("!value");
        }

        require(registerV2.registered(msg.sender), "!registered");

        accountSales[msg.sender] += value;
        require(accountSales[msg.sender] <= maxAmount, "maxAmount");

        address referrer = registerV2.referrers(msg.sender);
        directTeamSales[referrer] += value;
        addLiquidityUnlockTime[msg.sender] = block.timestamp;

        uint256 marketIncentives = value.mul(MARKET_INCENTIVES).div(BASE_PERCENT);

        // 20%市场，10%NFT，10%项目方
        _distributeReferralReward(msg.sender, value, marketIncentives);

        uint256 _value = value.sub(marketIncentives).div(2);

        uint256 tokenAmt;
        tokenAmt = ethToTokenSwap(address(this), _value, address(this));
        IWETH(bnbTokenAddress).deposit{value: _value}();

        return addLiquidityEth(_value, tokenAmt, msg.sender);
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(!isBlacklisted(from), "!blacklisted");

        if (amount == 1 ether && !registerV2.registered(from)) {
            registerV2.register(from, to);
        }

        if (isTaxExempt(from) || isTaxExempt(to)) {
            super._update(from, to, amount);
            return;
        }

        TransferType tType = getTransferType(from, to);
        require(tType != TransferType.Buy, "!buy");
        require(tType != TransferType.AddLiquidity, "!add");

        if (tType == TransferType.RemoveLiquidity) {
            // 计算lp数量
            uint lpAmount = calLiquidityByLububu(amount);
            require(accountLpAmount[to] >= lpAmount, "!added lp amount");
            accountLpAmount[to] -= lpAmount;

            // 记录添加的lpAmount
            uint256 _addLiquidityUnlockTime = addLiquidityUnlockTime[to];

            uint256 _amount;
            if (block.timestamp < _addLiquidityUnlockTime + 30 days) {
                _amount = amount.mul(removeLpBurnRate[0]).div(BASE_PERCENT);
            } else if (block.timestamp < _addLiquidityUnlockTime + 60 days) {
                _amount = amount.mul(removeLpBurnRate[1]).div(BASE_PERCENT);
            } else if (block.timestamp < _addLiquidityUnlockTime + 90 days) {
                _amount = amount.mul(removeLpBurnRate[2]).div(BASE_PERCENT);
            } else {
                _amount = amount.mul(removeLpBurnRate[3]).div(BASE_PERCENT);
            }
            super._update(from, BLACK_ADDRESS, _amount);
            amount = amount.sub(_amount);
            super._update(from, to, amount);
        } else if (tType == TransferType.Sell) {
            swapSellAward(from, amount);
        } else {
            super._update(from, to, amount);
        }
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'ETH_TRANSFER_FAILED');
    }

    enum TransferType {
        AddLiquidity,
        RemoveLiquidity,
        Sell,
        Buy,
        Transfer
    }

    function getTransferType(address from, address to) public view returns (TransferType) {
        if (to == SELL_MIDDLEWARE) {
            return TransferType.Sell;
        } else if (to == pancakePair) {
            return TransferType.AddLiquidity;
        } else if (from == pancakePair) {
            uint256 balanceBnb = IERC20(bnbTokenAddress).balanceOf(pancakePair);
            (uint256 rBnb,,) = IPancakePair(pancakePair).getReserves();
            if (balanceBnb < rBnb) return TransferType.RemoveLiquidity;
            else return TransferType.Buy;
        } else {
            return TransferType.Transfer;
        }
    }

    function isTaxExempt(address account) public view returns (bool) {
        return manager.hasRole(keccak256("TaxExempt"), account);
    }

    function isBlacklisted(address account) public view returns (bool) {
        return manager.hasRole(keccak256("Blacklist"), account);
    }

    function ethToTokenSwap(address toToken, uint256 amount, address recipient) internal returns (uint256) {
        require(msg.value > 0, "Send ETH to swap");

        address[] memory path = new address[](2);
        path[0] = bnbTokenAddress;
        path[1] = toToken;

        IPancakeRouter02(pancakeV2Router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            BUY_MIDDLEWARE,
            block.timestamp
        );
        uint256 balance = IERC20(toToken).balanceOf(BUY_MIDDLEWARE);

        super._update(BUY_MIDDLEWARE, recipient, balance);

        return balance;
    }

    function addLiquidityEth(uint256 tokenAmtA, uint256 tokenAmtB, address recipient) internal returns (uint256) {
        require(tokenAmtA > 0, "Insufficient tokenA balance");
        require(tokenAmtB > 0, "Insufficient tokenB balance");

        (,,uint liquidity) = IPancakeRouter02(pancakeV2Router).addLiquidity(
            address(bnbTokenAddress),
            address(this),
            tokenAmtA,
            tokenAmtB,
            0,
            0,
            recipient,
            block.timestamp + 600
        );
        accountLpAmount[recipient] += liquidity;

        return liquidity;
    }

    function calLiquidityByLububu(uint256 lububuAmount) public view returns (uint) {
        uint totalLp = IPancakePair(pancakePair).totalSupply();
        (,uint rThis,) = IPancakePair(pancakePair).getReserves();
        return lububuAmount * totalLp / rThis;
    }

    function tokenToEthSwap(uint256 amountIn, address recipient) internal {
        require(amountIn > 0, "Invalid input amount");

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = bnbTokenAddress;

        IPancakeRouter02(pancakeV2Router).swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            recipient,
            block.timestamp + 600
        );
    }

    function swapSellAward(address from, uint256 amount) internal {
        // 跌几个点，手续费x2。最低5%
        uint rate = oracle.getDecline() * 2;
        if (rate < 500) rate = 500;
        if (rate >= 10000) rate = 10000;
        // 手续费
        uint256 sellFeeAmount = amount.mul(rate).div(BASE_PERCENT);
        // tokenToEthSwap(sellFeeAmount, sellFeeAddress);
        super._update(from, sellFeeAddress, sellFeeAmount);
        // 卖出
        uint256 leftAmount = amount.sub(sellFeeAmount);
        if (leftAmount > 0) {
            super._update(from, address(this), leftAmount);
            tokenToEthSwap(leftAmount, from);
        }
    }

    function isLpValueAboveThreshold(address user) internal view returns (bool) {
        IPancakePair pair = IPancakePair(pancakePair);

        (uint112 reserveBnb, ,) = pair.getReserves();
        uint256 totalSupply = pair.totalSupply();

        if (totalSupply == 0) return false; // 防止除0异常

        uint256 userLP = pair.balanceOf(user);
        uint256 userShare = userLP.mul(1e18).div(totalSupply);

        uint256 bnbAmount = uint(reserveBnb).mul(userShare).div(1e18);

        uint256 lpValueInBNB = bnbAmount.mul(2);

        return lpValueInBNB >= MIN_AMOUNT.div(2);
    }

    function isChildListLpValueAboveThreshold(address account, uint256 num) internal view returns (bool) {
        uint256 validNum;
        // TODO referrals 太多如何？
        address[] memory referrals = registerV2.getReferrals(account);
        for (uint8 i = 0; i < referrals.length; i++) {
            address c = referrals[i];
            bool valid = isLpValueAboveThreshold(c);
            if (valid) {
                validNum = validNum.add(1);
            }
            if (validNum >= num) {
                break;
            }
        }

        return validNum >= num;
    }

    function _distributeReferralReward(address user, uint256 _totalAmount, uint256 totalReward) internal {
        uint256 distributedReward = 0;

        (address[] memory _referrers, uint realCount) = registerV2.getReferrers(user, 10);
        for (uint8 i = 0; i < realCount; i++) {
            address referrer = _referrers[i];
            uint256 rate = invitationAwardRates[i]; // 对应层级的万分比
            uint256 reward = _totalAmount.mul(rate).div(BASE_PERCENT);
            if (reward == 0) {
                continue;
            }

            bool eligible = false;
            if (i == 0) {
                eligible = isLpValueAboveThreshold(referrer);
            } else if (i == 1) {
                eligible = isLpValueAboveThreshold(referrer) && isChildListLpValueAboveThreshold(referrer, 3);
            } else if (i == 2) {
                eligible = isLpValueAboveThreshold(referrer) && isChildListLpValueAboveThreshold(referrer, 5);
            } else if (i == 3) {
                eligible = isLpValueAboveThreshold(referrer) && isChildListLpValueAboveThreshold(referrer, 7);
            } else {
                eligible = isLpValueAboveThreshold(referrer) && isChildListLpValueAboveThreshold(referrer, 10);
            }

            if (eligible) {
                safeTransferETH(referrer, reward);
                emit DistributeReferralReward(user, referrer, i + 1, reward);
                distributedReward += reward;
            }
        }

        //NFT 10%
        uint256 nftAmount = 0;
        if (address(nft) != address(0)) {
            nftAmount = _totalAmount.mul(1000).div(BASE_PERCENT);
            nft.sendReward{value: nftAmount}();
        }

        //项目方 10%
        uint256 depositFeeAmount = 0;
        if (depositFeeAddress != address(0)) {
            depositFeeAmount = _totalAmount.mul(1000).div(BASE_PERCENT);
            safeTransferETH(depositFeeAddress, depositFeeAmount);
        }

        // 剩余部分
        uint256 remaining = totalReward.sub(distributedReward).sub(nftAmount).sub(depositFeeAmount);
        if (remaining > 0) {
            safeTransferETH(marketAddress, remaining);
        }
    }

    function triggerDailyBurnAndMint() external {
        if (!burnAndMintSwitch) return;

        uint256 nowTime = block.timestamp;

        // 周期
        if (nowTime <= lastTriggerTime + TRIGGER_INTERVAL) {
            return;
        }

        uint256 rounds = (nowTime - lastTriggerTime) / TRIGGER_INTERVAL;
        // 通缩可暂停，最大一次通缩4次。
        if (rounds > 4) rounds = 4;
        lastTriggerTime = nowTime;

        uint256 liquidityPairBalance = this.balanceOf(pancakePair);
        if (liquidityPairBalance == 0) return;

        uint256 blackAmount = liquidityPairBalance.mul(BURN_BLACK_PERCENT).mul(rounds).div(BASE_PERCENT);
        if (blackAmount > 0) {
            super._update(pancakePair, BLACK_ADDRESS, blackAmount);
        }

        uint256 holdLPAwardAmount = liquidityPairBalance.mul(BURN_AWARD_PERCENT).mul(rounds).div(BASE_PERCENT);
        if (holdLPAwardAmount > 0) {
            super._update(pancakePair, address(deflationAddress), holdLPAwardAmount);
        }

        emit TriggerDailyBurnAndMint(liquidityPairBalance, blackAmount, holdLPAwardAmount, rounds);

        // 最后同步一次 Pair 状态
        IPancakePair(pancakePair).sync();
    }

    function setBurnAndMintSwitch(bool _switch) external {
        manager.allowFoundation(msg.sender);
        burnAndMintSwitch = _switch;
        lastTriggerTime = block.timestamp;
    }

    function setMintNFTAddress(ILabubuNFT _nft) external {
        manager.allowFoundation(msg.sender);
        nft = _nft;
    }

    function setDeflationAddress(address _deflationAddress) external {
        manager.allowFoundation(msg.sender);
        deflationAddress = _deflationAddress;
    }

    function setMaxAmount(uint256 amount) external {
        manager.allowFoundation(msg.sender);

        maxAmount = amount;
    }

    function setOracle(ILabubuOracle _oracle) external {
        manager.allowFoundation(msg.sender);

        oracle = _oracle;
    }

    function withdrawEth(address recipient, uint256 value) external {
        manager.allowFoundation(msg.sender);

        require(address(this).balance >= value, "Insufficient BNB");
        safeTransferETH(recipient, value);

        emit WithdrawalToken(address(0x0), recipient, value);
    }

    function withdrawalToken(address token, address receiver, uint amount) external {
        manager.allowFoundation(msg.sender);

        IERC20(token).transfer(receiver, amount);
        emit WithdrawalToken(token, receiver, amount);
    }

    function setRemoveLpBurnRate(uint256[] calldata _burn) external {
        manager.allowFoundation(msg.sender);

        delete removeLpBurnRate; // 清空旧数据
        for (uint i = 0; i < _burn.length; i++) {
            removeLpBurnRate.push(_burn[i]);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        manager.allowUpgrade(newImplementation, msg.sender);
    }
}
