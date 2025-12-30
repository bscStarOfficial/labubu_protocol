const {expect} = require("chai");
const {ethers, deployments} = require("hardhat");
const common = require("./util/common");
const {loadFixture, time, setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {nftInit, safeMint, sendReward, pendingProfit, claim, availableReward} = require("./util/nft");
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
  })

  it('设置权重', async () => {
    await safeMint(A)
    await safeMint(B)
    expect(await totalSupply()).to.eq(2)
  })
  it('发送奖励', async () => {
    await sendReward(1)
  })
  it('按权重分配', async () => {
    expect(await pendingProfit(A)).to.eq(0.5)
    expect(await pendingProfit(B)).to.eq(0.5)
  })
  it('提取奖励,收益归0', async () => {
    await expect(claim(A)).to.changeEtherBalance(
      A, parseEther('0.5')
    );
    expect(await availableReward(A)).to.eq(0)
  })
  it('新用户加入，没有收益', async () => {
    await safeMint(C)
    await safeMint(D)
    expect(await availableReward(C)).to.eq(0)
  })
  it('一天后再发送奖励', async () => {
    await sendReward(1)
  })
  it('按权重分配', async () => {
    expect(await pendingProfit(A)).to.eq(0.25)
    expect(await pendingProfit(B)).to.eq(0.75)
    expect(await pendingProfit(C)).to.eq(0.25)
    expect(await pendingProfit(D)).to.eq(0.25)
  })
  it('提取奖励,收益归0', async () => {
    await expect(claim(B)).to.changeEtherBalance(
      B, parseEther('0.75')
    );
    expect(await availableReward(B)).to.eq(0)
  })
})
