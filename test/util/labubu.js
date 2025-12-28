const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const common = require("./common");
const {Wallet} = require("ethers");
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {grantRole, to, toFNumber} = require("./common");

let labubu, pair;

async function labubuInit() {
  [labubu] = await common.getContractByNames(["SkyLabubu"]);
  pair = await labubu.pancakePair();
}

function labubuTransfer(account, to, amount) {
  return labubu.connect(account).transfer(to.address, parseEther(amount.toString()))
}

function labubuApprove(account, to, amount) {
  return labubu.connect(account).approve(to.address, parseEther(amount.toString()))
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

async function accountLpAmount(account) {
  let lpAmount = await labubu.accountLpAmount(account.address);
  return toFNumber(lpAmount);
}

function deposit(account, bnbAmount) {
  return labubu.connect(account).deposit({
    value: parseEther(bnbAmount.toString()),
  })
}

async function mockDeposit(account, bnbAmount) {
  let lpAmount = await labubu.connect(account).callStatic.deposit({
    value: parseEther(bnbAmount.toString()),
  })
  return toFNumber(lpAmount)
}

function sell(account, amount) {
  return labubu.connect(account).transfer(
    '0x0000000000000000000000000000000000000001',
    parseEther(amount.toString()),
  )
}

function triggerDailyBurnAndMint() {
  return labubu.triggerDailyBurnAndMint();
}

function setBurnAndMintSwitch(b) {
  return labubu.setBurnAndMintSwitch(b);
}

module.exports = {
  labubuInit,
  labubuTransfer,
  labubuApprove,
  labubuBalance,
  accountSales,
  directTeamSales,
  addLiquidityUnlockTime,
  totalSupply,
  deposit,
  inviteReferral,
  setMaxAmount,
  mockDeposit,
  accountLpAmount,
  sell,
  triggerDailyBurnAndMint,
  setBurnAndMintSwitch
}
