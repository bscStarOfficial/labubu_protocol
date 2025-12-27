const {ethers} = require("hardhat");
const {Wallet} = require("ethers");
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {parseEther} = require("ethers/lib/utils");

async function setReferrer(referral, referrer = "") {
  let registerV2 = await ethers.getContract("RegisterV2");

  if (referrer === "") referrer = {
    address: await registerV2.ROOT_USER()
  };
  await registerV2.setReferrer(referral.address, referrer.address);
}

async function referrer(account) {
  let registerV2 = await ethers.getContract("RegisterV2");
  return await registerV2.referrers(account.address)
}


async function register18() {
  let registerV2 = await ethers.getContract("RegisterV2");
  let wallets = [];
  let root = await registerV2.ROOT_USER();
  let provider = ethers.provider;

  for (let i = 0; i < 18; i++) {
    let wallet = Wallet.createRandom().connect(provider);
    await setBalance(wallet.address, parseEther('10000'));
    let referrer = i === 0 ? root : wallets[i - 1].address;
    await registerV2.setReferrer(wallet.address, referrer);
    wallets.push(wallet);
  }

  return wallets;
}

module.exports = {
  setReferrer,
  referrer,
  register18
}
