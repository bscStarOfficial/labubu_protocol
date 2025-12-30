const {expect} = require("chai");
const {ethers, deployments} = require("hardhat");
const common = require("./util/common");
const {loadFixture, time, setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {nftInit} = require("./util/nft");
const {parseEther, formatEther} = require("ethers/lib/utils");
const {grantRole, dead} = require("./util/common");
const {deposit, totalSupply, inviteReferral, labubuInit, setMaxAmount, labubuApprove, mockDeposit, accountLpAmount, labubuTransfer, sell, triggerDailyBurnAndMint, setBurnAndMintSwitch, setRemoveLpSwitch} = require("./util/labubu");
const {addLiquidityETH, dexInit, buy, getLabubuAmountByLp, removeLiquidityETH, lpApprove, removeLiquidity, lpBalance, getPair} = require("./util/dex");
const {setReferrer, register18} = require("./util/registerV2");
const {setOpenPrice, getLabubuPrice, getOpenPrice, setOpenPriceByAdmin, getDecline} = require("./util/oracle");
const BigNumber = require("bignumber.js");

let deployer, marketAddress, minter, sellFeeAddress, deflationAddress, depositFeeAddress;
let labubu, nft, manager, oracle, registerV2, router;

let w = [];

async function initialFixture() {
  await deployments.fixture();
  await nftInit();
  await dexInit();
  await labubuInit();

  [labubu, nft, manager, oracle, registerV2, router] = await common.getContractByNames([
    'SkyLabubu', "LabubuNFT", 'Manager', 'LabubuOracle', 'RegisterV2', "UniswapV2Router02"
  ]);
  [deployer, marketAddress, minter, sellFeeAddress, deflationAddress, depositFeeAddress] = await common.getAccounts(
    ["deployer", "marketAddress", "minter", "sellFeeAddress", "deflationAddress", "depositFeeAddress"]
  );

  w = await register18()
  for (let wi of w) {
    await grantRole('Deposit_Whitelist', wi);
  }
  await nft.setOnlyAA(false);
  await setReferrer(minter)

  await common.multiApprove(labubu, [router]);
  await setBalance(minter.address, parseEther('100000'))
  await addLiquidityETH(minter, 10000_0000, 1_0000);

  await setMaxAmount(1000);
}

describe("oracle & 卖出", function () {
  before(async () => {
    await initialFixture();
    await labubuTransfer(minter, w[0], 10000);
  })
  it("设置开盘价", async function () {
    await setOpenPrice()
    expect(await getLabubuPrice()).to.eq(0.1)
    let p = await getOpenPrice();
    expect(p[1]).to.eq(0.1)
    expect(p[2]).to.eq(true)
  })
  it("匹配decline", async function () {
    await setOpenPriceByAdmin(
      new BigNumber(0.1).multipliedBy(0.99).multipliedBy(1e12).toFixed()
    );
    expect(await getDecline()).to.eq(0)
    // 跌9个点（0.09090909）9.09%
    await setOpenPriceByAdmin(
      new BigNumber(0.1).multipliedBy(1.1).multipliedBy(1e12).toFixed()
    );
    expect(await getDecline()).to.eq(900)
  })
  it("跌几个点，手续费x2。", async function () {
    // 18%
    await expect(sell(w[0], 1000)).to.changeTokenBalances(
      labubu,
      [labubu, sellFeeAddress, w[0]],
      [
        0,
        parseEther('180'),
        parseEther('1000').mul(-1),
      ]
    )
  })
  it("最低5%", async function () {
    await setOpenPriceByAdmin(
      new BigNumber(0.1).multipliedBy(0.99).multipliedBy(1e12).toFixed()
    );
    // 5%
    await expect(sell(w[0], 1000)).to.changeTokenBalances(
      labubu,
      [labubu, sellFeeAddress, w[0]],
      [
        0,
        parseEther('50'),
        parseEther('1000').mul(-1),
      ]
    )
  })
})

describe("赎回Lp", function () {
  before(async () => {
    await initialFixture();
  })
  it("默认无法赎回LP", async function () {
    await deposit(w[1], 0.1);
    await lpApprove(w[1])
    await expect(removeLiquidity(w[1], 0.001)).revertedWith("!Remove")

    await setRemoveLpSwitch(true);
  })
  it('赎回数量不能多于添加数量', async () => {
    let lpAmount = await mockDeposit(w[0], 0.1);
    await deposit(w[0], 0.1);
    // 计算最大可赎回
    expect(await accountLpAmount(w[0])).to.eq(lpAmount)

    await lpApprove(w[0])
    await removeLiquidity(w[0], lpAmount)
    expect(await accountLpAmount(w[0])).to.closeTo(0, 0.00001)
  })
  it('30天内90%币销毁', async function () {
    // lpAmount = await mockDeposit(w[1], 0.1);
    await deposit(w[1], 0.1);
    await lpApprove(w[1])
    let lpAmount = 0.001;
    let lububuAmount = await getLabubuAmountByLp(lpAmount);
    await expect(removeLiquidity(w[1], lpAmount)).to.changeTokenBalances(
      labubu,
      [w[1], dead],
      [
        lububuAmount.mul(1).div(10).add(1),
        lububuAmount.mul(9).div(10),
      ]
    )
  })
  it('60天内70%币销毁', async function () {
    await time.increase(86400 * 30);
    let lpAmount = 0.001;
    let lububuAmount = await getLabubuAmountByLp(lpAmount);
    await expect(removeLiquidity(w[1], lpAmount)).to.changeTokenBalances(
      labubu,
      [w[1], dead],
      [
        lububuAmount.mul(3).div(10).add(1),
        lububuAmount.mul(7).div(10),
      ]
    )
  })
  it('90天内50%币销毁', async function () {
    await time.increase(86400 * 30);
    let lpAmount = 0.001;
    let lububuAmount = await getLabubuAmountByLp(lpAmount);
    await expect(removeLiquidity(w[1], lpAmount)).to.changeTokenBalances(
      labubu,
      [w[1], dead],
      [
        lububuAmount.mul(5).div(10),
        lububuAmount.mul(5).div(10),
      ]
    )
  })
  it('90天后30%币销毁', async function () {
    await time.increase(86400 * 30);
    let lpAmount = 0.001;
    let lububuAmount = await getLabubuAmountByLp(lpAmount);
    await expect(removeLiquidity(w[1], lpAmount)).to.changeTokenBalances(
      labubu,
      [w[1], dead],
      [
        lububuAmount.mul(7).div(10).add(1),
        lububuAmount.mul(3).div(10),
      ]
    )
  })
})

describe("入金", function () {
  before(async () => {
    await initialFixture();
  })
  describe("bnb入金", function () {
    it('最低入金0.1BNB', async function () {
      await expect(deposit(w[0], 0.099)).to.revertedWith('!value')
    })
    // bsc测试
    it('60%用于组建流动性池(LP)', async function () {

    })
    it('10%进入拉盘合约助涨币价')
    it('10%用于NFT节点分红', async function () {
      await expect(deposit(w[3], 0.1)).to.changeEtherBalances(
        [depositFeeAddress, nft],
        [parseEther('0.01'), parseEther('0.01')]
      )
    })
  })
  describe("20%用于布道奖励（10层）", function () {
    before(async () => {
      await initialFixture()
    })
    it('布道奖励发不完，资金回到marketAddress', async function () {
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        marketAddress, parseEther("0.02")
      )
    })
    it("自身绩效不达标无法获取奖励", async function () {
      // 充值
      // await deposit(w[9], 0.1)
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        w[9], 0
      )
    })
    it('1代-5%-直推1个有效用户', async function () {
      // await inviteReferral(w[9], 1)
      await deposit(w[9], 0.1)
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        w[9], parseEther("0.005")
      )
    })
    it('2代-4%-直推3个有效用户', async function () {
      await inviteReferral(w[8], 2)
      await deposit(w[8], 0.1)
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        w[8], parseEther("0.004")
      )
    })
    it('3代-3%-直推5个有效用户', async function () {
      await inviteReferral(w[7], 4)
      await deposit(w[7], 0.1)
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        w[7], parseEther("0.003")
      )
    })
    it('4代-2%-直推7个有效用户', async function () {
      await inviteReferral(w[6], 6)
      await deposit(w[6], 0.1)
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        w[6], parseEther("0.002")
      )
    })
    it('5到10代-1%-直推10个有效用户', async function () {
      for (let i = 5; i >= 0; i--) {
        await inviteReferral(w[i], 9)
        await deposit(w[i], 0.1)
      }
      await expect(deposit(w[10], 0.1)).changeEtherBalances(
        [w[5], w[4], w[3], w[2], w[1], w[0]],
        [
          parseEther("0.001"),
          parseEther("0.001"),
          parseEther("0.001"),
          parseEther("0.001"),
          parseEther("0.001"),
          parseEther("0.001")
        ]
      )
    })
  })
  describe("无法通过pancake入金", function () {
    it("无法买入", async function () {
      await expect(buy(w[0], 1)).to.revertedWith("!buy")
    })
    it("无法添加流动性", async function () {
      await labubuApprove(w[0], router, 10000000000)
      await expect(addLiquidityETH(w[0], 1, 1)).to.revertedWith("!add")
    })
  })
})

describe("通缩", function () {
  before(async () => {
    await initialFixture();
  })
  it("burnAndMintSwitch不开启不通缩", async function () {
    await time.increase(86400);
    await expect(triggerDailyBurnAndMint()).to.changeTokenBalances(
      labubu,
      [dead, deflationAddress],
      [0, 0]
    )
  })
  it("一次最多通缩2%")
  it("每天1%分币")
  it("每天1%销毁", async function () {
    await setBurnAndMintSwitch(true);
    await time.increase(86400 * 4);
    await expect(triggerDailyBurnAndMint()).to.changeTokenBalances(
      labubu,
      [dead, deflationAddress, await getPair()],
      [
        parseEther('1000000'),
        parseEther('1000000'),
        parseEther('2000000').mul(-1)
      ]
    )
  })
})

describe("白名单", function () {
  before(async () => {
    await initialFixture();
  })
  it("交易无手续费")
})

describe("发行", function () {
  before(async () => {
    await initialFixture();
  })
  it('总量2100亿', async function () {
    expect(await totalSupply()).to.eq(parseEther("210000000000"))
  })
})
