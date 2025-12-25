const {expect} = require("chai");
const {ethers, deployments} = require("hardhat");
const common = require("./util/common");
const {loadFixture, time} = require("@nomicfoundation/hardhat-network-helpers");
const {nftInit, sendTransaction, balanceOf, totalSupply, safeMint, setMaxTokenId, transferFrom} = require("./util/nft");
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
  })

})

// TODO 测试合约升级
