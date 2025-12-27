const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const common = require("./common");
const {Wallet} = require("ethers");
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {grantRole} = require("./common");

let labubu;

async function labubuInit() {
  [labubu] = await common.getContractByNames(["SkyLabubu"]);
}

function labubuTransfer(account, to, amount) {
  return labubu.connect(account).transfer(to.address, parseEther(amount.toString()))
}

async function labubuBalance(account) {
  return await labubu.balanceOf(account.address)
}

async function accountSales(account) {
  return await labubu.accountSales(account.address)
}

async function directTeamSales(account) {
  return await labubu.directTeamSales(account.address)
}

async function addLiquidityUnlockTime(account) {
  return await labubu.addLiquidityUnlockTime(account.address)
}

async function totalSupply() {
  return await labubu.totalSupply()
}

async function inviteReferral(account, count) {
  let provider = ethers.provider;
  let minter = await common.getWallet("minter");
  for (let i = 0; i < count; i++) {
    let wallet = Wallet.createRandom().connect(provider);
    await setBalance(wallet.address, parseEther('10000'));

    await labubuTransfer(minter, wallet, 1);
    // 绑定推荐关系
    await labubuTransfer(wallet, account, 1);
    // 白名单入金
    await grantRole('Deposit_Whitelist', wallet);
    await deposit(wallet, 0.1)
  }
}

async function setMaxAmount(amount) {
  await labubu.setMaxAmount(parseEther(amount.toString()));
}

function deposit(account, bnbAmount) {
  return labubu.connect(account).deposit({
    value: parseEther(bnbAmount.toString()),
  })
}

module.exports = {
  labubuInit,
  labubuTransfer,
  labubuBalance,
  accountSales,
  directTeamSales,
  addLiquidityUnlockTime,
  totalSupply,
  deposit,
  inviteReferral,
  setMaxAmount
}
