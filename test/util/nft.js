const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const common = require("./common");

let nft;

async function nftInit() {
  [nft] = await common.getContractByNames(["LabubuNFT"]);
}

function sendTransaction(account) {
  return account.sendTransaction({
    from: account.address,
    to: nft.address,
    value: parseEther('0.6')
  });
}

function safeMint(account, value = 0.6) {
  return nft.connect(account).safeMint(account.address, {
    value: parseEther(value.toString()),
  });
}

function claim(account) {
  return nft.claim(account.address);
}

function setMaxDepositId(id) {
  return nft.setMaxDepositId(id);
}

function sendReward(amount) {
  return nft.sendReward({value: parseEther(amount.toString())});
}

function setDepositCheckTokenId(b) {
  return nft.setDepositCheckTokenId(b);
}

function setMaxTokenId(id) {
  return nft.setMaxTokenId(id);
}

async function maxTokenId() {
  return await nft.maxTokenId()
}

async function totalSupply() {
  return await nft.totalSupply()
}

async function balanceOf(account) {
  return await nft.balanceOf(account.address)
}

function canDeposit(account, value) {
  return nft.canDeposit(account.address, parseEther(value.toString()))
}

function transferFrom(from, to, tokenId) {
  return nft.transferFrom(from.address, to.address, tokenId);
}

async function pendingProfit(account) {
  let pending = await nft.pendingProfit(account.address);
  return Number(formatEther(pending));
}

async function availableReward(account) {
  let reward = await nft.availableReward(account.address);
  return Number(formatEther(reward));
}

module.exports = {
  nftInit,
  sendTransaction,
  safeMint,
  claim,
  sendReward,
  setMaxTokenId,
  maxTokenId,
  totalSupply,
  balanceOf,
  transferFrom,
  pendingProfit,
  availableReward,
  setMaxDepositId,
  canDeposit,
  setDepositCheckTokenId
}
