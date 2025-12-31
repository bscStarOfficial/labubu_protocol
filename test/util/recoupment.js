const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const common = require("./common");
const {toFNumber} = require("./common");
const BigNumber = require("bignumber.js");

let recoupment;

async function recoupmentInit() {
  [recoupment] = await common.getContractByNames(["LabubuRecoupment"]);
}

function sendTransaction(account) {
  return account.sendTransaction({
    from: account.address,
    to: recoupment.address,
  });
}

function setPayee(account, share) {
  return recoupment.setPayee(account.address, parseEther(share.toString()));
}

async function payees(account) {
  let res = await recoupment.payees(account.address);
  return {
    share: toFNumber(res.share),
    claimed: toFNumber(res.claimed),
    available: toFNumber(res.available)
  }
}

async function recoupments(account) {
  let res = await recoupment.recoupments(account.address);
  return {
    deposit: toFNumber(res.deposit),
    quota: toFNumber(res.quota),
    claimed: toFNumber(res.claimed),
  }
}

async function total() {
  let res = await recoupment.statistic();
  return toFNumber(res.total);
}

function claim(account) {
  return recoupment.claim(account.address);
}

async function sendReward(amount) {
  let minter = await common.getWallet('minter');
  return await recoupment.connect(minter).sendReward(
    parseEther(amount.toString())
  );
}

async function pendingReward(account) {
  let pending = await recoupment.pendingReward(account.address);
  return toFNumber(pending);
}

async function availableReward(account) {
  let reward = await recoupment.availableReward(account.address);
  return toFNumber(reward);
}

async function setQuota(account, quota) {
  let res = await recoupments(account);
  quota = new BigNumber(res.claimed).plus(quota).toNumber();
  await recoupment.setQuota(
    account.address,
    new BigNumber(quota.toString()).multipliedBy(1e18).toFixed()
  );
}

async function setAvailable(account, available) {
  await recoupment.setAvailableTest(account.address, parseEther(available.toString()));
}

async function getLeftQuota(account) {
  let leftQuota = await recoupment.getLeftQuota(account.address);
  return toFNumber(leftQuota);
}

module.exports = {
  recoupmentInit,
  sendTransaction,
  setPayee,
  claim,
  pendingReward,
  availableReward,
  payees,
  sendReward,
  total,
  setQuota,
  recoupments,
  getLeftQuota,
  setAvailable
}
