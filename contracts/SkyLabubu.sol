// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ILabubuNFT.sol";
import "./interfaces/ILabubuOracle.sol";
import "./interfaces/ILabubuRecoupment.sol";
import "./interfaces/IManager.sol";
import "./interfaces/IPancake.sol";
import "./interfaces/IRegisterV2.sol";
import "./interfaces/IWETH.sol";
import "./lib/LabubuConst.sol";
import "./lib/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
//import "hardhat/console.sol";

contract SkyLabubu is ERC20Upgradeable, UUPSUpgradeable, AccessControlEnumerableUpgradeable, LabubuConst {
    using SafeMath for uint256;
    bytes32 internal constant FOUNDATION = keccak256("FOUNDATION");
    bytes32 internal constant UPGRADE = keccak256("UPGRADE");

    uint256 public maxAmount;

    ILabubuNFT public nft;
    ILabubuRecoupment public recoupment;
    ILabubuOracle public oracle;
    IRegisterV2 public registerV2;

    address public deflationAddress; // 每日1%销毁地址
    address public sellFeeAddress; // 卖出手续费地址
    address public depositFeeAddress; // 10%入金手续费

    address public pancakePair;

    mapping(address => uint256) public accountSales;
    mapping(address => uint256) public addLiquidityUnlockTime;
    mapping(address => uint256) public accountLpAmount;

    uint16[] public removeLpBurnRate;
    uint16[3] public dailyBurnRate;
    mapping(uint => bool) public dailyBurned; // 指定天数是否销毁

    bool public burnAndMintSwitch;
    bool public removeLpSwitch;

    event Deposit(address indexed from, uint usdtValue, uint bnbValue);
    event WithdrawalToken(address indexed token, address indexed receiver, uint indexed amount);
    event TriggerDailyBurnAndMint(uint256 indexed liquidityPairBalance, uint256 indexed burnAmount, uint256 indexed holdLPAwardAmount);
    event LpRedeemed(address indexed user, uint labubuPrice, uint backAmount, uint burnAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _wBNB, address _router) {
        _disableInitializers();

        bnbTokenAddress = _wBNB;
        pancakeV2Router = _router;
    }

    function initialize(
        address _minter,
        address _sellFeeAddress,
        address _deflationAddress,
        address _depositFeeAddress,
        ILabubuNFT _nft,
        IRegisterV2 _registerV2
    ) public initializer {
        // bnbTokenAddress 必须是token0
        require(address(this) > bnbTokenAddress, '!gt');

        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();
        __ERC20_init("Sky Labubu", "SkyLabubu");
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(UPGRADE, _msgSender());
        _grantRole(FOUNDATION, _msgSender());

        nft = _nft;

        sellFeeAddress = _sellFeeAddress;
        deflationAddress = _deflationAddress;
        depositFeeAddress = _depositFeeAddress;
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

        maxAmount = 0.1 ether;

        // 0销毁、1项目方、2分红
        dailyBurnRate = [100, 0, 100];

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

        addLiquidityUnlockTime[msg.sender] = block.timestamp;

        // 20%市场，10%NFT，10%项目方
        _distributeBNB(msg.sender, value);

        uint256 marketIncentives = value.mul(MARKET_INCENTIVES).div(BASE_PERCENT);
        uint256 _value = value.sub(marketIncentives).div(2);

        uint256 tokenAmt;
        tokenAmt = ethToTokenSwap(address(this), _value, address(this));
        IWETH(bnbTokenAddress).deposit{value: _value}();

        uint liquidity = addLiquidityEth(_value, tokenAmt, msg.sender);

        emit Deposit(msg.sender, getUsdtValue(value), value);
        return liquidity;
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
        if (!removeLpSwitch)
            require(tType != TransferType.RemoveLiquidity, "!Remove");

        if (tType == TransferType.RemoveLiquidity) {
            // 计算lp数量
            uint lpAmount = calLiquidityByLububu(amount);
            require(accountLpAmount[to] >= lpAmount, "!added lp amount");
            accountLpAmount[to] -= lpAmount;
            recoupment.setPayee(to, accountLpAmount[to]);

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

            emit LpRedeemed(to, oracle.getLabubuPrice(), amount, _amount);
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
        return hasRole(keccak256("TaxExempt"), account);
    }

    function isBlacklisted(address account) public view returns (bool) {
        return hasRole(keccak256("Blacklist"), account);
    }

    function getUsdtValue(uint bnbAmount) internal view returns (uint) {
        return oracle.getBnbPrice() * bnbAmount / 1e12;
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

        // 设置权重
        recoupment.setPayee(recipient, accountLpAmount[recipient]);

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

    function _distributeBNB(address user, uint256 _totalAmount) internal {
        require(
            address(nft) != address(0) &&
            depositFeeAddress != address(0) &&
            address(recoupment) != address(0), "!0"
        );
        // 推荐关系 20%
        // !!!这里的20%不能随意修改，recoupment合约value * 5，计算投入
        uint256 referralValue = _totalAmount.mul(2000).div(BASE_PERCENT);
        recoupment.distributeReferralReward{value: referralValue}(user);

        // NFT 10%
        uint256 nftValue = _totalAmount.mul(1000).div(BASE_PERCENT);
        nft.sendReward{value: nftValue}();

        // 项目方 10%
        uint256 depositFeeAmount = _totalAmount.mul(1000).div(BASE_PERCENT);
        safeTransferETH(depositFeeAddress, depositFeeAmount);
    }

    function triggerDailyBurnAndMint() external {
        if (!burnAndMintSwitch) return;

        uint256 timeKey = (block.timestamp / 86400) * 86400;
        if (dailyBurned[timeKey]) return;
        dailyBurned[timeKey] = true;

        uint256 liquidityPairBalance = this.balanceOf(pancakePair);
        if (liquidityPairBalance == 0) return;

        uint256 blackAmount = liquidityPairBalance.mul(dailyBurnRate[0]).div(BASE_PERCENT);
        if (blackAmount > 0) {
            super._update(pancakePair, BLACK_ADDRESS, blackAmount);
        }

        uint256 holdLPAwardAmount = liquidityPairBalance.mul(dailyBurnRate[1]).div(BASE_PERCENT);
        if (holdLPAwardAmount > 0) {
            super._update(pancakePair, deflationAddress, holdLPAwardAmount);
        }

        uint256 recoupmentAmount = liquidityPairBalance.mul(dailyBurnRate[2]).div(BASE_PERCENT);
        if (recoupmentAmount > 0) {
            super._update(pancakePair, address(this), recoupmentAmount);
            recoupment.sendReward(recoupmentAmount);
        }

        emit TriggerDailyBurnAndMint(liquidityPairBalance, blackAmount, holdLPAwardAmount);

        // 最后同步一次 Pair 状态
        IPancakePair(pancakePair).sync();
    }

    function setBurnAndMintSwitch(bool _switch) external onlyRole(FOUNDATION) {
        burnAndMintSwitch = _switch;
    }

    function setRemoveLpSwitch(bool _switch) external onlyRole(FOUNDATION) {
        removeLpSwitch = _switch;
    }

    function setMintNFTAddress(ILabubuNFT _nft) external onlyRole(FOUNDATION) {
        nft = _nft;
    }

    function setDeflationAddress(address _deflationAddress) external onlyRole(FOUNDATION) {
        deflationAddress = _deflationAddress;
    }

    function setMaxAmount(uint256 amount) external onlyRole(FOUNDATION) {
        maxAmount = amount;
    }

    function setOracle(ILabubuOracle _oracle) external onlyRole(FOUNDATION) {
        oracle = _oracle;
    }

    function setRecoupment(ILabubuRecoupment _recoupment) external onlyRole(FOUNDATION) {
        _approve(address(this), address(_recoupment), ~uint256(0));

        recoupment = _recoupment;
    }

    function withdrawEth(address recipient, uint256 value) external onlyRole(FOUNDATION) {
        require(address(this).balance >= value, "Insufficient BNB");
        safeTransferETH(recipient, value);

        emit WithdrawalToken(address(0x0), recipient, value);
    }

    function withdrawalToken(address token, address receiver, uint amount) external onlyRole(FOUNDATION) {
        IERC20(token).transfer(receiver, amount);
        emit WithdrawalToken(token, receiver, amount);
    }

    function setRemoveLpBurnRate(uint16[] calldata _burn) external onlyRole(FOUNDATION) {
        delete removeLpBurnRate; // 清空旧数据
        for (uint i = 0; i < _burn.length; i++) {
            removeLpBurnRate.push(_burn[i]);
        }
    }

    function setDailBurnRate(uint16[3] calldata _burn) external onlyRole(FOUNDATION) {
        require(_burn[0] + _burn[1] + _burn[2] == 200, "!200");

        dailyBurnRate = _burn;
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADE) {
        require(
            keccak256(Address.functionStaticCall(newImplementation, abi.encodeWithSignature('proxiableUUID()'))) ==
            ERC1967Utils.IMPLEMENTATION_SLOT,
            "!UUID"
        );
    }
}
