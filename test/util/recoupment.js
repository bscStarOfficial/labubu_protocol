const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const common = require("./common");
const {toFNumber} = require("./common");

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
  await recoupment.setQuota(account.address, parseEther(quota.toString()));
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
  setQuota
}
