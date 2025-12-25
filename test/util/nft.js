const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const common = require("./common");
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {BigNumber} = require("bignumber.js");

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

function sendReward(amount) {
  return nft.sendReward({value: parseEther(amount.toString())});
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

function transferFrom(from, to, tokenId) {
  return nft.transferFrom(from.address, to.address, tokenId);
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
  transferFrom
}
