const {expect} = require("chai");
const {ethers, deployments} = require("hardhat");
const common = require("./util/common");
const {nftInit, sendTransaction, balanceOf, totalSupply, safeMint, setMaxTokenId, transferFrom, sendReward, pendingProfit, claim, availableReward} = require("./util/nft");
const {deposit, labubuTransfer, labubuInit} = require("./util/labubu");
const {keccak256, toUtf8Bytes} = require("ethers/lib/utils");

let deployer, minter, A, B, C, D, E, F, G;
let labubu, nft, manager, oracle, registerV2;

async function initialFixture() {
  await deployments.fixture();
  await labubuInit();

  [labubu, nft, manager, oracle, registerV2] = await common.getContractByNames([
    'SkyLabubu', "LabubuNFT", 'Manager', 'LabubuOracle', 'RegisterV2'
  ]);
  [deployer, minter, A, B, C, D, E, F, G] = await common.getAccounts(
    ["deployer", "minter", "A", "B", "C", "D", "E", "F", "G"]
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
    await manager.grantRole(
      keccak256(toUtf8Bytes('Deposit_Whitelist')),
      B.address
    );
    await expect(deposit(B, 0.1)).to.revertedWith("!registered")
  })
  it('新地址向任意地址转账1 LABUBU后绑定推荐关系', async function () {
    await setReferrer(A, {
      address: await registerV2.ROOT_USER()
    });
    await labubuTransfer(minter, B, 100);
    await labubuTransfer(B, A, 1);
    expect(await referrer(B)).to.eq(A.address)
  });
})

async function referrer(account) {
  return await registerV2.referrers(account.address)
}

async function setReferrer(referral, referrer) {
  return await registerV2.setReferrer(referral.address, referrer.address);
}
