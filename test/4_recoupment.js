const {expect} = require("chai");
const {ethers, deployments} = require("hardhat");
const common = require("./util/common");
const {loadFixture, time, setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {recoupmentInit, sendReward, pendingReward, claim, availableReward, setPayee, total, setQuota, recoupments, getLeftQuota, setAvailable} = require("./util/recoupment");
const {parseEther, formatEther} = require("ethers/lib/utils");
const {grantRole, dead} = require("./util/common");
const {deposit, totalSupply, inviteReferral, labubuInit, setMaxAmount, labubuApprove, mockDeposit, accountLpAmount, labubuTransfer, sell, triggerDailyBurnAndMint, setBurnAndMintSwitch, setRemoveLpSwitch} = require("./util/labubu");
const {addLiquidityETH, dexInit} = require("./util/dex");
const {setReferrer, register18} = require("./util/registerV2");
const {setOpenPrice, getLabubuPrice, getOpenPrice, setOpenPriceByAdmin, getDecline} = require("./util/oracle");
const BigNumber = require("bignumber.js");

let deployer, marketAddress, minter, sellFeeAddress, deflationAddress, depositFeeAddress;
let labubu, nft, manager, oracle, recoupment, router;

let w = [];

async function initialFixture() {
  await deployments.fixture();
  await recoupmentInit();
  await dexInit();
  await labubuInit();

  [labubu, nft, manager, oracle, recoupment, router] = await common.getContractByNames([
    'SkyLabubu', "LabubuNFT", 'Manager', 'LabubuOracle', 'LabubuRecoupment', "UniswapV2Router02"
  ]);
  [deployer, marketAddress, minter] = await common.getAccounts(
    ["deployer", "marketAddress", "minter"]
  );

  w = await register18()
  for (let wi of w) {
    await grantRole('Deposit_Whitelist', wi);
  }
  await grantRole('SKY_LABUBU', deployer);
  await setReferrer(minter)

  await common.multiApprove(labubu, [router, recoupment]);
  await setBalance(minter.address, parseEther('100000'))
  await addLiquidityETH(minter, 10000_0000, 1_0000);

  await setMaxAmount(1000);
}

describe("3倍收益-BNB", function () {
  before(async () => {
    await initialFixture();
    await setMaxAmount(100);
  })
  it("充值记录deposit和quota", async function () {
    await deposit(w[0], 0.1);
    let recoup = await recoupments(w[0])
    expect(recoup.deposit).to.equal(100)
    expect(recoup.quota).to.equal(300)
    expect(recoup.claimed).to.equal(0)
  })
  it("leftQuota", async function () {
    expect(await getLeftQuota(w[0])).to.equal(300)
  })
  it("直推bnb收益在3倍内", async function () {
    // 5%直推 = 0.25BNB = 250U
    await expect(deposit(w[1], 5)).to.changeEtherBalance(
      w[0], parseEther('0.25')
    )
    let recoup = await recoupments(w[0])
    expect(recoup.claimed).to.equal(250)
    expect(await getLeftQuota(w[0])).to.equal(50)
  })
  it("直推bnb收益超过3倍", async function () {
    // 5%直推 = 0.25BNB = 250U
    await expect(deposit(w[1], 5)).to.changeEtherBalance(
      w[0], parseEther('0.05')
    )
    let recoup = await recoupments(w[0])
    expect(recoup.claimed).to.equal(300)
    expect(await getLeftQuota(w[0])).to.equal(0)
  })
})

describe("3倍收益-Labubu静态", function () {
  before(async () => {
    await initialFixture();
    await oracle.setLabubuPriceForTest(1e11); // 0.1U
    await labubuTransfer(minter, recoupment, 100000);
  })
  it("通缩收益在3倍内", async function () {
    await deposit(w[0], 0.1) // 额度300
    await setAvailable(w[0], 2999)
    await expect(claim(w[0])).to.changeTokenBalance(
      labubu, w[0], parseEther('2399.2') // 2999 * 0.8 = 2399.2
    )
    expect(await getLeftQuota(w[0])).to.equal(0.1)
  })
  it("通缩收益超过3倍", async function () {
    await setAvailable(w[0], 100)
    await expect(claim(w[0])).to.changeTokenBalance(
      labubu, w[0], parseEther('0.8')
    )
    expect(await getLeftQuota(w[0])).to.equal(0)
  })
})

describe("3倍收益-Labubu动态", function () {
  before(async () => {
    await initialFixture();
    await oracle.setLabubuPriceForTest(1e11); // 0.1U
    await labubuTransfer(minter, recoupment, 100000);

    for (let wi of w) {
      await setQuota(wi, 300); // 300U额度
    }
  })
  it("20%动态");
  it("动态分红算在3倍收益内");
  it('布道奖励发不完，资金回到marketAddress', async function () {
    await setAvailable(w[10], 100)
    await expect(claim(w[10])).changeTokenBalance(
      labubu, marketAddress, parseEther("20")
    )
  })
  it("自身绩效不达标无法获取奖励", async function () {
    await setAvailable(w[10], 100)
    await expect(claim(w[10])).changeTokenBalance(
      labubu, w[9], 0
    )
  })
  it('1代-5%-直推1个有效用户', async function () {
    await setAvailable(w[10], 100)
    await deposit(w[9], 0.1)
    await expect(claim(w[10])).changeTokenBalance(
      labubu,  w[9], parseEther("5")
    )
  })
  it('2代-4%-直推3个有效用户', async function () {
    await setAvailable(w[10], 100)
    await inviteReferral(w[8], 2)
    await deposit(w[8], 0.1)
    await expect(claim(w[10])).changeTokenBalance(
      labubu, w[8], parseEther("4")
    )
  })
  it('3代-3%-直推5个有效用户', async function () {
    await setAvailable(w[10], 100)
    await inviteReferral(w[7], 4)
    await deposit(w[7], 0.1)
    await expect(claim(w[10])).changeTokenBalance(
      labubu,  w[7], parseEther("3")
    )
  })
  it('4代-2%-直推7个有效用户', async function () {
    await setAvailable(w[10], 100)
    await inviteReferral(w[6], 6)
    await deposit(w[6], 0.1)
    await expect(claim(w[10])).changeTokenBalance(
      labubu, w[6], parseEther("2")
    )
  })
  it('5到10代-1%-直推10个有效用户', async function () {
    await setAvailable(w[10], 100)
    for (let i = 5; i >= 0; i--) {
      await inviteReferral(w[i], 9)
      await deposit(w[i], 0.1)
    }
    await expect(claim(w[10])).changeTokenBalances(
      labubu,
      [w[5], w[4], w[3], w[2], w[1], w[0]],
      [
        parseEther("1"),
        parseEther("1"),
        parseEther("1"),
        parseEther("1"),
        parseEther("1"),
        parseEther("1")
      ]
    )
  })
})

describe("权重测试", function () {
  before(async () => {
    await initialFixture();
    for (let wi of w) {
      await setQuota(wi, 100000000);
    }
  })
  it("充值记录share,share=lp")
  it('设置权重', async () => {
    await setPayee(w[0], 1000)
    await setPayee(w[1], 1000)
    expect(await total()).to.eq(2000)
  })
  it('发送奖励', async () => {
    await sendReward(1)
  })
  it('按权重分配', async () => {
    expect(await pendingReward(w[0])).to.eq(0.5)
    expect(await pendingReward(w[1])).to.eq(0.5)
  })
  it('提取奖励,收益归0', async () => {
    await expect(claim(w[0])).to.changeTokenBalance(
      labubu, w[0], parseEther('0.4') // 80%
    );
    expect(await availableReward(w[0])).to.eq(0)
  })
  it('新用户加入，没有收益', async () => {
    await setPayee(w[2], 1000)
    await setPayee(w[3], 1000)
    expect(await availableReward(w[2])).to.eq(0)
  })
  it('一天后再发送奖励', async () => {
    await sendReward(1)
  })
  it('按权重分配', async () => {
    expect(await pendingReward(w[0])).to.eq(0.25)
    expect(await pendingReward(w[1])).to.eq(0.75)
    expect(await pendingReward(w[2])).to.eq(0.25)
    expect(await pendingReward(w[3])).to.eq(0.25)
  })
  it('提取奖励,收益归0', async () => {
    await expect(claim(w[1])).to.changeTokenBalance(
      labubu, w[1], parseEther('0.6')
    );
    expect(await availableReward(w[1])).to.eq(0)
  })
})
