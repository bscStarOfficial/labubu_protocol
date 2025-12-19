const {expect} = require("chai");
const {ethers, deployments, getNamedAccounts, getUnnamedAccounts} = require("hardhat");
const {parseEther, formatEther, parseUnits, solidityKeccak256} = require("ethers/lib/utils");
const {AddressZero} = ethers.constants
const helpers = require("@nomicfoundation/hardhat-network-helpers");
const common = require("./util/common");
const {loadFixture, time} = require("@nomicfoundation/hardhat-network-helpers");
const {addLiquidity, swapE2T, getAmountsOut, getAmountsIn, dexInit} = require("./util/dex");
const {multiTransfer, multiApprove, tokenBalance, toFNumber, dead} = require("./util/common");

let deployer, marketing, profit, technology, A, B, C, D, E, F, G;
let ava, usdt, router;

async function initialFixture() {
  await deployments.fixture();
  await dexInit();

  [ava, usdt, router] = await common.getContractByNames(["AVA", 'USDT', 'UniswapV2Router02']);
  [deployer, marketing, profit, technology, A, B, C, D, E, F, G] = await common.getAccounts(
    ["deployer", "avaMarketing", "avaProfit", "avaTechnology", "A", "B", "C", "D", "E", "F", "G"]
  );
}

describe("发行", function () {
  before(async () => {
    await initialFixture();
  })
  it('AVA总发行量131万枚', async function () {
    expect(await ava.totalSupply()).to.equal(parseEther('1310000'));
    expect(await ava.balanceOf(deployer.address)).to.equal(parseEther('1110000'));
  });
})

describe("交易", function () {
  let profitFee;
  before(async () => {
    await multiTransfer(ava, deployer, [A, B, C, D], 10000);
    await multiTransfer(usdt, deployer, [A, B, C, D], 10000);
    await multiApprove(ava, [router])
    await multiApprove(usdt, [router])
    // 1U
    await addLiquidity(deployer, 100000, 100000);
  })
  it('未开启预售无法交易', async function () {
    await expect(swapE2T(100, [ava, usdt], A)).to.revertedWith('pre')
    await expect(swapE2T(100, [usdt, ava], A)).to.revertedWith('pre')
  })
  it('黑名单地址无法转账', async function () {
    await ava.multi_bclist([A.address], true);
    await expect(
      ava.connect(A).transfer(B.address, 1)
    ).to.revertedWith('isReward != 0 !')

    await ava.multi_bclist([A.address], false);
  })
  it('开启预售', async function () {
    await ava.setPresale();
    // 15分钟后 marketingFeeRate = 30
    await time.increase(60 * 15);
  })
  it('买入手续费2.5%销毁', async function () {
    let avaAmount = await getAmountsOut(
      parseEther('100'), [usdt.address, ava.address]
    );
    await swapE2T(100, [usdt, ava], B);
    expect(await tokenBalance(ava, dead)).to.closeTo(avaAmount * 0.025, 1e-15);
    expect(toFNumber(await ava.AmountLPFee())).to.closeTo(avaAmount * 0.025, 1e-15);
  })
  it('买入手续费2.5%构建流动性', async function () {

  })
  it('卖出手续费3%进入市场、2%进入技术', async function () {
    // profit fee
    profitFee = await getAmountsOut(
      parseEther('300'), [ava.address, usdt.address]
    );
    await swapE2T(1000, [ava, usdt], A);
    expect(
      toFNumber(await ava.AmountMarketingFee())
    ).to.eq(30);
    expect(
      toFNumber(await ava.TechnologyFee())
    ).to.eq(20);
  })
  it('30%盈利手续费进入profit', async function () {
    // 300
    expect(await tokenBalance(usdt, profit)).to.eq(profitFee);
  })
  it('无手续费地址交易不用手续费')
})

describe('手续费添加流动性', async function () {
  before(async () => {
    await initialFixture();
    await multiTransfer(ava, deployer, [A, B, C, D], 10000);
    await multiTransfer(usdt, deployer, [A, B, C, D], 10000);
    await multiApprove(ava, [router])
    await multiApprove(usdt, [router])
    // 1U
    await addLiquidity(deployer, 100000, 100000);
    await ava.setPresale();
    // 15分钟后 marketingFeeRate = 30
    await time.increase(60 * 15);
  })
  it('买入手续费2.5%构建流动性', async function () {
    await swapE2T(10000, [usdt, ava], A)
  })
  it('触发添加流动性', async function () {
    await ava.swapTokenForFundByOwner();
  })
  // it('usdt用不完，token合约有残留', async function () {
  //   abandonedBalance = await tokenBalance(usdt, ava);
  //   expect(abandonedBalance).to.gt(0)
  // })

  it('claimAbandonedBalance提取残留usdt', async function () {
    await usdt.connect(B).transfer(ava.address, parseEther('10'));
    await expect(ava.claimAbandonedBalance(usdt.address, parseEther('10'))).to.changeTokenBalance(
      usdt, deployer, parseEther('10')
    )
    expect(await tokenBalance(usdt, ava)).to.eq(0);
  })
})

// describe('盈利税', async function () {
//   before(async () => {
//     await initialFixture();
//     await multiTransfer(ava, deployer, [A, B, C, D], 10000);
//     await multiTransfer(usdt, deployer, [A, B, C, D], 10000);
//     await multiApprove(ava, [router])
//     await multiApprove(usdt, [router])
//     // 1U
//     await addLiquidity(deployer, 100000, 100000);
//     await ava.setPresale();
//     // 15分钟后 marketingFeeRate = 30
//     await time.increase(60 * 15);
//   })
//   it('A 30%盈利税 300', async function () {
//     let profitFee = await getAmountsOut(
//       parseEther('300'), [ava.address, usdt.address]
//     );
//     await expect(swapE2T(1000, [ava, usdt], A)).to.changeTokenBalance(
//       usdt, profit, parseEther(profitFee.toString())
//     );
//   })
//   it('B 30%盈利税 30', async function () {
//     await swapE2T(900, [usdt, ava], B);
//     await time.increase(60 * 15);
//     let profitFee = await getAmountsOut(
//       parseEther('100'), [ava.address, usdt.address]
//     );
//     await expect(swapE2T(1000, [ava, usdt], B)).to.changeTokenBalance(
//       usdt, profit, parseEther(profitFee.toString())
//     );
//   })
// })
