const {expect} = require("chai");
const {ethers, deployments} = require("hardhat");
const common = require("./util/common");
const {loadFixture, time} = require("@nomicfoundation/hardhat-network-helpers");
const {nftInit, sendTransaction, balanceOf, totalSupply, safeMint, setMaxTokenId, transferFrom, sendReward, pendingProfit, claim, availableReward} = require("./util/nft");
const {parseEther} = require("ethers/lib/utils");
const {labubuTransfer} = require("./util/oracle");

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

describe("推荐关系", function () {
  before(async () => {
    await initialFixture();
  })

  it("不绑定推荐关系不可推新用户", async function () {
    await expect(labubuTransfer(B, A, 1)).to.revertedWith("referrer does not existed")
  })
  it("不绑定推荐关系不可入金", async function () {

  })
  it('新地址向任意地址转账1 LABUBU后绑定推荐关系', async function () {
    await labubuTransfer(B, A, 1);
    expect(await referrer(B)).to.eq(A)
  });
})

async function referrer(account) {
  return await registerV2.referrers(account)
}
