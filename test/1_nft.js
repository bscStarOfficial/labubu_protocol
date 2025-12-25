const {expect} = require("chai");
const {ethers, deployments} = require("hardhat");
const common = require("./util/common");
const {loadFixture, time} = require("@nomicfoundation/hardhat-network-helpers");
const {nftInit, sendTransaction, balanceOf, totalSupply, safeMint, setMaxTokenId, transferFrom, sendReward, pendingProfit, claim, availableReward} = require("./util/nft");
const {parseEther} = require("ethers/lib/utils");

let deployer, reserve, A, B, C, D, E, F, G;
let manager, nft;

async function initialFixture() {
  await deployments.fixture();
  await nftInit();

  [nft, manager] = await common.getContractByNames(["LabubuNFT", 'Manager']);
  [deployer, reserve, A, B, C, D, E, F, G] = await common.getAccounts(
    ["deployer", "reserve", "A", "B", "C", "D", "E", "F", "G"]
  );
}

describe("NFT购买", function () {
  before(async () => {
    await initialFixture();
    await nft.setOnlyAA(false);
  })
  it('转账bnb直接购买，钱转到合约地址', async function () {
    await expect(sendTransaction(A)).to.changeEtherBalance(
      reserve, parseEther("0.6")
    )
    expect(await balanceOf(A)).to.eq(1)
    expect(await totalSupply()).to.eq(1)
  });
  it("一个地址只能买一个", async function () {
    await expect(safeMint(A)).to.revertedWith("one")
  })
  it("截止批次后，无法购买", async function () {
    await setMaxTokenId(0)
    await expect(safeMint(B)).to.revertedWith("!max")
    await setMaxTokenId(100)
  })
  it("金额不对", async function () {
    await expect(safeMint(A, 0.59)).to.revertedWith("!price")
  })
  it('nft不让转账', async () => {
    await expect(transferFrom(A, B, 0)).to.revertedWith('!transfer')
  })
  it("only AA", async function () {
    await nft.setOnlyAA(true);
    await expect(safeMint(C)).to.revertedWith("onlyAA")
  })
})

describe("NFT分红", function () {
  before(async () => {
    await initialFixture();
    await nft.setOnlyAA(false);
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

// TODO 测试合约升级
