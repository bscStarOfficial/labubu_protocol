const {expect} = require("chai");
const {ethers, deployments} = require("hardhat");
const common = require("./util/common");
const {loadFixture, time, setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {recoupmentInit, sendReward, pendingReward, claim, availableReward, setPayee, total, setQuota} = require("./util/recoupment");
const {parseEther, formatEther} = require("ethers/lib/utils");
const {grantRole, dead} = require("./util/common");
const {deposit, totalSupply, inviteReferral, labubuInit, setMaxAmount, labubuApprove, mockDeposit, accountLpAmount, labubuTransfer, sell, triggerDailyBurnAndMint, setBurnAndMintSwitch, setRemoveLpSwitch} = require("./util/labubu");
const {addLiquidityETH, dexInit, buy, getLabubuAmountByLp, removeLiquidityETH, lpApprove, removeLiquidity, lpBalance, getPair} = require("./util/dex");
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

describe("3倍收益", function () {
  before(async () => {
    await initialFixture();
  })
  it("充值记录deposit和quota")
  it("leftQuota")
  it("直推bnb收益在3倍内")
  it("直推bnb收益超过3倍")
  it("通缩收益在3倍内")
  it("通缩收益超过3倍")
})

describe("通缩分红", function () {
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

describe("提取收益", function () {
  before(async () => {
    await initialFixture();
  })
  it("80%静态")
  it("20%动态")
  it("动态分红算在3倍收益内")
})
