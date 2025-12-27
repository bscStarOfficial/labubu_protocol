const {expect} = require("chai");
const {ethers, deployments} = require("hardhat");
const common = require("./util/common");
const {loadFixture, time, setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {nftInit, sendTransaction, balanceOf, totalSupply, safeMint, setMaxTokenId, transferFrom, sendReward, pendingProfit, claim, availableReward} = require("./util/nft");
const {parseEther} = require("ethers/lib/utils");
const {multiRegister, grantRole, register18} = require("./util/common");
const {deposit, inviteReferral} = require("./util/labubu");
const {addLiquidityETH} = require("./util/dex");

let deployer, marketAddress, minter, sellFeeAddress, deflationAddress, depositFeeAddress;
let labubu, nft, manager, oracle, registerV2;

let w = [];

async function initialFixture() {
  await deployments.fixture();
  await nftInit();

  [labubu, nft, manager, oracle, registerV2] = await common.getContractByNames([
    'SkyLabubu', "LabubuNFT", 'Manager', 'LabubuOracle', 'RegisterV2'
  ]);
  [deployer, marketAddress, minter, sellFeeAddress, deflationAddress, depositFeeAddress] = await common.getAccounts(
    ["deployer", "marketAddress", "minter", "sellFeeAddress", "deflationAddress", "depositFeeAddress"]
  );

  w = await register18()

  await setBalance(minter, parseEther('10000'))
  await addLiquidityETH(minter, 1000_0000, 1_0000);
}

describe("发行", function () {
  before(async () => {
    await initialFixture();
  })
  it('总量2100亿', async function () {
    expect(await totalSupply()).to.eq(parseEther("210000000000"))
  })
})

describe("入金", function () {
  before(async () => {
    await initialFixture();
    await multiRegister()
    await grantRole('Deposit_Whitelist', A);
  })
  describe("bnb入金", function () {
    it('最低入金0.1BNB', async function () {
      await expect(deposit(w[0], 0.099)).to.revertedWith('!value')
    })
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
    it("自身绩效不达标无法获取奖励", async function () {
      // 充值 deposit(w[9], 0.1)
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        w[9], 0
      )
    })
    it('1代-5%-直推1个有效用户', async function () {
      await inviteReferral(w[9], 1)
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        w[9], parseEther("0.005")
      )
    })
    it('2代-4%-直推3个有效用户', async function () {
      await inviteReferral(w[8], 3)
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        w[8], parseEther("0.004")
      )
    })
    it('3代-3%-直推5个有效用户', async function () {
      await inviteReferral(w[7], 5)
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        w[7], parseEther("0.003")
      )
    })
    it('4代-2%-直推7个有效用户', async function () {
      await inviteReferral(w[6], 7)
      await expect(deposit(w[10], 0.1)).changeEtherBalance(
        w[6], parseEther("0.002")
      )
    })
    it('5到10代-1%-直推10个有效用户', async function () {
      for (let i = 5; i >= 0; i++) {
        await inviteReferral(w[i], 10)
      }
      await expect(deposit(w[10], 0.1)).changeEtherBalances(
        [w[5], w[4], w[3], w[2], w[1], w[0]],
        [
          parseEther("0.001"),
          parseEther("0.001"),
          parseEther("0.001"),
          parseEther("0.001"),
          parseEther("0.001")
        ]
      )
    })
    it('布道奖励发不完，资金回到marketAddress', async function () {

    })
  })
  describe("无法通过pancake入金", function () {
    it("无法买入")
    it("无法添加流动性")
  })
})

describe("出金", function () {
  before(async () => {
    await initialFixture();
  })

  describe("赎回Lp", function () {
    it('30天内90%币销毁')
    it('60天内70%币销毁')
    it('90天内50%币销毁')
    it('90天后30%币销毁')
  })

  describe("卖出", function () {
    it("跌几个点，手续费x2。")
    it("最低5%")
  })
})

describe("通缩", function () {
  before(async () => {
    await initialFixture();
  })
  it("每天1%分币")
  it("每天1%销毁")
})

describe("白名单", function () {
  before(async () => {
    await initialFixture();
  })
  it("交易无手续费")
})
