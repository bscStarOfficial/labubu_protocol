const {expect} = require("chai");
const {ethers, deployments} = require("hardhat");
const common = require("./util/common");
const {loadFixture, time} = require("@nomicfoundation/hardhat-network-helpers");
const {nftInit, sendTransaction, balanceOf, totalSupply, safeMint, setMaxTokenId, transferFrom, sendReward, pendingProfit, claim, availableReward} = require("./util/nft");
const {parseEther} = require("ethers/lib/utils");

let deployer, reserve, A, B, C, D, E, F, G;
let labubu, nft, manager, oracle, registerV2;

async function initialFixture() {
  await deployments.fixture();
  await nftInit();

  [labubu, nft, manager, oracle, registerV2] = await common.getContractByNames([
    'SkyLabubu', "LabubuNFT", 'Manager', 'LabubuOracle', 'RegisterV2'
  ]);
  [deployer, marketAddress, minter, sellFeeAddress, deflationAddress, depositFeeAddress, A, B, C, D, E, F, G] = await common.getAccounts(
    ["deployer", "marketAddress", "minter", "sellFeeAddress", "deflationAddress", "depositFeeAddress", "A", "B", "C", "D", "E", "F", "G"]
  );
}

describe("发行", function () {
  before(async () => {
    await initialFixture();
  })
  it('总量2100亿')
  it('2000亿注入薄饼LP池）')
})

describe("入金", function () {
  before(async () => {
    await initialFixture();
  })
  describe("限制", function () {
    it('tokenId限制')
    it('白名单不受限制')
    it('日入金总量限制')
    it('EOA地址限制')
  })
  describe("bnb入金", function () {
    it('最低入金0.1BNB')
    it('60%用于组建流动性池(LP)')
    it('20%用于布道奖励（10层）')
    it('10%进入拉盘合约助涨币价')
    it('10%用于NFT节点分红')
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
