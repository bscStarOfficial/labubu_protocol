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

contract Distributor {
    constructor() {}
}

contract SkyLabubu is ERC20Upgradeable, UUPSUpgradeable, LabubuConst {
    using SafeMath for uint256;

    uint256 public maxAmount = 0.1 ether;
    uint16[] public InvitationAwardRates;

    Distributor public _DISTRIBUTOR;
    ILabubuNFT public nft;
    ILabubuOracle public oracle;
    IManager public manager;
    IRegisterV2 public registerV2;

    address public defaultInviteAddress; // 默认邀请人地址
    address public deflationAddress; // 每日1%销毁地址
    address private sellFeeAddress; // 卖出手续费地址
    address public depositFeeAddress; // 10%入金手续费

    address public pancakePair;
    mapping(address => bool) public pairs;
    mapping(address => bool) public isTaxExempt;
    mapping(address => bool) public isBlacklisted;

    mapping(address => uint256) public accountSales;
    mapping(address => uint256) public directTeamSales;

    bool public updateSwitch = true;

    bool private swapping;
    mapping(address => uint256) public addLiquidityUnlockTime;

    address[] public lpHolders;
    mapping(address => bool) public isLpHolder;
    mapping(address => uint256) public lpHolderAmount;

    bool public burnAndMintSwitch = false;

    uint256[] public burnRate;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _wBNB,
        address _router
    ) {
        _disableInitializers();

        bnbTokenAddress = _wBNB;
        pancakeV2Router = _router;
    }

    function initialize(
        address _defaultInviteAddress,
        address _minter,
        ILabubuNFT _nft,
        address _sellFeeAddress,
        address _deflationAddress,
        address _depositFeeAddress,
        ILabubuOracle _oracle,
        IManager _manager,
        IRegisterV2 _registerV2
    ) public initializer {
        __ERC20_init("Sky Labubu", "SkyLabubu");

        defaultInviteAddress = _defaultInviteAddress;
        nft = _nft;

        sellFeeAddress = _sellFeeAddress;
        deflationAddress = _deflationAddress;
        depositFeeAddress = _depositFeeAddress;
        oracle = _oracle;
        manager = _manager;
        registerV2 = _registerV2;

        _DISTRIBUTOR = new Distributor();

        pancakePair = IPancakeFactory(
            IPancakeRouter02(pancakeV2Router).factory()
        ).createPair(address(this), bnbTokenAddress);
        pairs[pancakePair] = true;

        _approve(address(this), pancakeV2Router, ~uint256(0));
        IERC20(bnbTokenAddress).approve(pancakeV2Router, ~uint256(0));

        burnRate.push(9000);
        burnRate.push(7000);
        burnRate.push(5000);
        burnRate.push(3000);

        InvitationAwardRates.push(500);
        InvitationAwardRates.push(400);
        InvitationAwardRates.push(300);
        InvitationAwardRates.push(200);
        for (uint8 i = 4; i < 10; i++) {
            InvitationAwardRates.push(100);
        }

        isTaxExempt[address(this)] = true;
        isTaxExempt[msg.sender] = true;
        isTaxExempt[address(_DISTRIBUTOR)] = true;
        isTaxExempt[sellFeeAddress] = true;
        isTaxExempt[_minter] = true;

        // 初始供应量
        _mint(_minter, 210000000000 * 10 ** decimals());
    }

    receive() external payable {
        uint256 value = msg.value;

        // 早期入金限制
        require(nft.canDeposit(msg.sender, value), '!can');

        if (value == 0.6 ether) {
            nft.safeMint{value: value}(msg.sender);
            return;
        }

        // 1e17 原版限制isContract(msg.sender)
        if (value < MIN_AMOUNT || value > maxAmount || value % 0.1 ether > 0) {
            safeTransferETH(msg.sender, value);
            return;
        }

        require(registerV2.registered(msg.sender), "!registered");

        accountSales[msg.sender] += value;
        require(accountSales[msg.sender] <= maxAmount, "maxAmount");

        address referrer = registerV2.referrers(msg.sender);
        directTeamSales[referrer] = directTeamSales[referrer] + value;
        addLiquidityUnlockTime[msg.sender] = block.timestamp;

        uint256 marketIncentives = value.mul(MARKET_INCENTIVES).div(BASE_PERCENT);

        // 20%市场，10%NFT，10%项目方
        _distributeReferralReward(msg.sender, value, marketIncentives);

        uint256 _value = value.sub(marketIncentives).div(2);

        uint256 tokenAmt;
        tokenAmt = ethToTokenSwap(address(this), _value, address(this));
        wrapEth(_value);

        uint256 lpAmount = addLiquidityEth(_value, tokenAmt, msg.sender);
        lpHolderAmount[msg.sender] = lpAmount;

        _addLpHolder(msg.sender);
    }


    event RemoveThePool(address indexed from, address indexed to, uint256 indexed amount, uint256 _lpAmount, uint256 lpAmount, uint256 time);
    event UpdateLog(address indexed from, address indexed to, uint256 indexed amount, bool isRemove);

    function _update(address from, address to, uint256 amount) internal override {
        require(!isBlacklisted[from], "ERC20: sender is blacklisted");

        if (amount == 1 ether && !registerV2.registered(from)) {
            registerV2.register(from, to);
        }
        if (from == address(deflationAddress) || to == address(deflationAddress)) {
            super._update(from, to, amount);
            return;
        }
        if (isTaxExempt[from] || isTaxExempt[to]) {
            super._update(from, to, amount);
            return;
        }

        require(updateSwitch, "!updateSwitch");
        require(_isAddLiquidity(amount) == 0, "!addLp");

        bool isRemove = pairs[from] && _isRemoveLiquidity(amount) > 0;

        emit UpdateLog(from, to, amount, isRemove);

        if (from != pancakeV2Router) {
            if (isRemove && !isBlacklisted[to]) {
                uint256 _amount;
                IPancakePair pair = IPancakePair(pancakePair);
                uint256 _lpAmount = pair.balanceOf(to);
                if (_lpAmount == 0) {
                    _lpAmount = pair.balanceOf(tx.origin);
                }
                uint256 lpAmount = lpHolderAmount[to];
                if (lpAmount == 0) {
                    lpAmount = lpHolderAmount[tx.origin];
                }
                // require(_lpAmount == lpAmount, "There is no way to withdraw if you have not added a pool");

                uint256 _addLiquidityUnlockTime = addLiquidityUnlockTime[to];
                if (_addLiquidityUnlockTime == 0) {
                    _addLiquidityUnlockTime = addLiquidityUnlockTime[tx.origin];
                }
                require(_addLiquidityUnlockTime > 0, "There is no way to withdraw if you have not added a pool");
                if (block.timestamp < _addLiquidityUnlockTime + 30 days) {
                    _amount = amount.mul(burnRate[0]).div(BASE_PERCENT);
                } else if (block.timestamp < _addLiquidityUnlockTime + 60 days) {
                    _amount = amount.mul(burnRate[1]).div(BASE_PERCENT);
                } else if (block.timestamp < _addLiquidityUnlockTime + 90 days) {
                    _amount = amount.mul(burnRate[2]).div(BASE_PERCENT);
                } else {
                    _amount = amount.mul(burnRate[3]).div(BASE_PERCENT);
                }
                // addLiquidityUnlockTime[to] = 0;
                // addLiquidityUnlockTime[tx.origin] = 0;
                emit RemoveThePool(from, to, amount, _lpAmount, lpAmount, _addLiquidityUnlockTime);
                super._update(from, BLACK_ADDRESS, _amount);
                amount = amount.sub(_amount);
            } else if (pairs[from]) {
                require(false, "Buying is prohibited");
            } else if (pairs[to]) {
                if (!swapping) {
                    swapping = true;
                    amount = swapSellAward(from, amount);
                    swapping = false;
                }
            }
        }

        super._update(from, to, amount);
    }


    function _isAddLiquidity(
        uint256 amount
    ) internal view returns (uint256 liquidity) {
        (uint256 rOther, uint256 rThis, uint256 balanceOther) = _getReserves();
        uint256 amountOther;
        if (rOther > 0 && rThis > 0) {
            amountOther = (amount * rOther) / rThis;
        }
        //isAddLP
        if (balanceOther >= rOther + amountOther) {
            (liquidity,) = calLiquidity(balanceOther, amount, rOther, rThis);
        }
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'ETH_TRANSFER_FAILED');
    }

    function _getReserves()
    public
    view
    returns (uint256 rOther, uint256 rThis, uint256 balanceOther)
    {
        IPancakePair mainPair = IPancakePair(pancakePair);
        (uint r0, uint256 r1,) = mainPair.getReserves();

        address tokenOther = bnbTokenAddress;
        if (tokenOther < address(this)) {
            rOther = r0;
            rThis = r1;
        } else {
            rOther = r1;
            rThis = r0;
        }

        balanceOther = IERC20(tokenOther).balanceOf(pancakePair);
    }

    function _isRemoveLiquidity(
        uint256 amount
    ) internal view returns (uint256 liquidity) {
        (uint256 rOther, , uint256 balanceOther) = _getReserves();
        //isRemoveLP
        if (balanceOther <= rOther) {
            liquidity =
                (amount * IPancakePair(pancakePair).totalSupply()) /
                (balanceOf(pancakePair) - amount);
        }
    }

    function calLiquidity(
        uint256 balanceA,
        uint256 amount,
        uint256 r0,
        uint256 r1
    ) private view returns (uint256 liquidity, uint256 feeToLiquidity) {
        uint256 pairTotalSupply = IPancakePair(pancakePair).totalSupply();
        address feeTo = IPancakeFactory(
            IPancakeRouter02(pancakeV2Router).factory()
        ).feeTo();
        bool feeOn = feeTo != address(0);
        uint256 _kLast = IPancakePair(pancakePair).kLast();
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(r0 * r1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = pairTotalSupply *
                        (rootK - rootKLast) *
                                8;
                    uint256 denominator = rootK * 17 + (rootKLast * 8);
                    feeToLiquidity = numerator / denominator;
                    if (feeToLiquidity > 0) pairTotalSupply += feeToLiquidity;
                }
            }
        }
        uint256 amount0 = balanceA - r0;
        if (pairTotalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount) - 1000;
        } else {
            liquidity = Math.min(
                (amount0 * pairTotalSupply) / r0,
                (amount * pairTotalSupply) / r1
            );
        }
    }


    function setUpdateSwitch(bool _updateSwitch) external {
        manager.allowFoundation(msg.sender);
        updateSwitch = _updateSwitch;
    }

    function ethToTokenSwap(address toToken, uint256 amount, address recipient) internal returns (uint256) {
        require(msg.value > 0, "Send ETH to swap");

        address[] memory path = new address[](2);
        path[0] = bnbTokenAddress;
        path[1] = toToken;

        IPancakeRouter02(pancakeV2Router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            address(_DISTRIBUTOR),
            block.timestamp + 600
        );

        uint256 balanceAfter = IERC20(toToken).balanceOf(address(_DISTRIBUTOR));
        super._update(address(_DISTRIBUTOR), recipient, balanceAfter);

        return balanceAfter;
    }


    function addLiquidityEth(uint256 tokenAmtA, uint256 tokenAmtB, address recipient) internal returns (uint256) {
        require(tokenAmtA > 0, "Insufficient tokenA balance");
        require(tokenAmtB > 0, "Insufficient tokenB balance");

        IPancakeRouter02(pancakeV2Router).addLiquidity(
            address(bnbTokenAddress),
            address(this),
            tokenAmtA,
            tokenAmtB,
            0,
            0,
            recipient,
            block.timestamp + 600
        );

        IPancakePair pair = IPancakePair(pancakePair);
        return pair.balanceOf(recipient);
    }


    function tokenToEthSwap(uint256 amountIn, address recipient) internal {
        require(amountIn > 0, "Invalid input amount");

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = bnbTokenAddress;

        // uint256 before = address(this).balance;

        IPancakeRouter02(pancakeV2Router).swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            recipient,
            block.timestamp + 600
        );

        // uint256 received = address(this).balance - before;
        // return received;
    }

    // 卖出税
    function swapSellAward(address from, uint256 amount) internal returns (uint256){
        // 跌几个点，手续费x2。最低5%
        uint rate = oracle.getDecline() * 2;
        if (rate < 500) rate = 500;

        uint256 sellFeeAmount = amount.mul(rate).div(BASE_PERCENT);
        super._update(from, address(this), sellFeeAmount);
        tokenToEthSwap(sellFeeAmount, sellFeeAddress);

        uint256 _amount = amount.sub(sellFeeAmount);
        return _amount;
    }

    function isLpValueAboveThreshold(address user) internal view returns (bool) {
        IPancakePair pair = IPancakePair(pancakePair);

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        uint256 totalSupply = pair.totalSupply();

        if (totalSupply == 0) return false; // 防止除0异常

        address token0 = pair.token0();

        // 判断哪一侧是 BNB
        (uint256 reserveBNB,) = token0 == bnbTokenAddress
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        uint256 userLP = pair.balanceOf(user);
        uint256 userShare = userLP.mul(1e18).div(totalSupply);

        uint256 bnbAmount = reserveBNB.mul(userShare).div(1e18);

        uint256 lpValueInBNB = bnbAmount.mul(2);

        return lpValueInBNB >= MIN_AMOUNT.div(2);
    }


    function isChildListLpValueAboveThreshold(address account, uint256 num) internal view returns (bool) {
        uint256 validNum;
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


    event DistributeReferralReward(address indexed from, address indexed to, uint8 indexed level, uint256 amount);

    function _distributeReferralReward(address user, uint256 _totalAmount, uint256 totalReward) internal {
        uint256 distributedReward = 0;

        (address[] memory _referrers, uint realCount) = registerV2.getReferrers(user, 10);
        for (uint8 i = 0; i < realCount; i++) {
            address referrer = _referrers[i];
            uint256 rate = InvitationAwardRates[i]; // 对应层级的万分比
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
        uint256 buyAmount = 0;
        if (depositFeeAddress != address(0)) {
            buyAmount = _totalAmount.mul(1000).div(BASE_PERCENT);
            safeTransferETH(depositFeeAddress, buyAmount);
        }

        // 剩余部分
        uint256 remaining = totalReward.sub(distributedReward).sub(nftAmount).sub(buyAmount);
        if (remaining > 0) {
            safeTransferETH(defaultInviteAddress, remaining);
        }
    }


    uint256 public lastTriggerTime = block.timestamp;
    uint256 public holdLPAward;
    uint256 public TRIGGER_INTERVAL = 6 hours;

    event TriggerDailyBurnAndMint(uint256 indexed liquidityPairBalance, uint256 indexed burnAmount, uint256 indexed holdLPAwardAmount, uint256 rounds);

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

    function _addLpHolder(address account) internal {
        // TODO 排除初始添加lp的地址
        if (!isLpHolder[account]) {
            isLpHolder[account] = true;
            lpHolders.push(account);
        }
    }

    // TODO claim bnb fee, 添加流动池子可能用不玩


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

    function wrapEth(uint256 _value) public {
        IWETH(bnbTokenAddress).deposit{value: _value}();
    }

    function setMaxAmount(uint256 amount) external {
        manager.allowFoundation(msg.sender);

        maxAmount = amount;
    }

    function setTriggerInterval(uint256 _tigger) external {
        manager.allowFoundation(msg.sender);

        TRIGGER_INTERVAL = _tigger;
    }

    function excludeFromFeeBatch(address[] calldata addrs, bool excluded) external {
        manager.allowFoundation(msg.sender);

        for (uint256 i = 0; i < addrs.length; i++) {
            isTaxExempt[addrs[i]] = excluded;
        }
    }


    function blacklistBatch(address[] calldata addrs, bool blacklisted) external {
        manager.allowFoundation(msg.sender);

        for (uint256 i = 0; i < addrs.length; i++) {
            isBlacklisted[addrs[i]] = blacklisted;
        }
    }

    event WithdrawalToken(address indexed token, address indexed receiver, uint indexed amount);

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

    function setBurnRate(uint256[] calldata _burn) external {
        manager.allowFoundation(msg.sender);

        delete burnRate; // 清空旧数据
        for (uint i = 0; i < _burn.length; i++) {
            burnRate.push(_burn[i]);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        manager.allowUpgrade(newImplementation, msg.sender);
    }
}
