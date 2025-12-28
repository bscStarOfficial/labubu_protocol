const {ethers, deployments, getNamedAccounts, getUnnamedAccounts} = require("hardhat");
const {formatEther, parseEther, keccak256, toUtf8Bytes} = require("ethers/lib/utils")
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {Wallet} = require("ethers");
const BigNumber = require("bignumber.js");

async function getAccounts(names = []) {
  let accounts = [];
  for (let i in names) {
    accounts.push(await getWallet(names[i]));
  }
  return accounts;
}

async function getContractByNames(names = []) {
  let filters = ["demo"];
  let contracts = [];
  for (let i in names) {
    let name = names[i];
    if (filters.indexOf(name) >= 0) {
      let aaa = await ethers.getContract(name);
      contracts.push(await ethers.getContractAt("Card", aaa.address));
    } else {
      contracts.push(await ethers.getContract(name));
    }
  }
  return contracts;
}

async function multiApprove(token, contracts = []) {
  let accounts = await ethers.getNamedSigners();
  for (let i in accounts) {
    let account = accounts[i];
    for (let j in contracts) {
      let contract = contracts[j];
      await token.connect(account).approve(contract.address, ethers.constants.MaxInt256);
    }
  }
}

async function multiTransfer(token, from, accounts = [], amount) {
  for (let i in accounts) {
    let account = accounts[i];
    await token.connect(from).transfer(account.address, parseEther(amount.toString()));
  }
}

async function getWallet(name) {
  const obj = await getNamedAccounts();
  let wallets = await ethers.getSigners();
  for (let i in wallets) {
    if (wallets[i].address === obj[name]) {
      return wallets[i];
    }
  }
}

async function tokenBalance(token, account) {
  let balance = await token.balanceOf(account.address);
  return Number(formatEther(balance));
}

async function tokenTransfer(token, from, to, amount) {
  amount = parseEther(amount.toString());
  await token.connect(from).transfer(to.address, amount);
}

async function multiRegister() {
  let registerV2 = await ethers.getContract("RegisterV2");
  let [A, B, C, D, E, F, G, H, I, J] = await getAccounts(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]);
  await registerV2.setReferrer(A, await registerV2.ROOT_USER());
  await registerV2.setReferrer(B, A.address);
  await registerV2.setReferrer(C, B.address);
  await registerV2.setReferrer(D, C.address);
  await registerV2.setReferrer(E, D.address);
  await registerV2.setReferrer(F, E.address);
  await registerV2.setReferrer(G, F.address);
  await registerV2.setReferrer(H, G.address);
  await registerV2.setReferrer(I, H.address);
  await registerV2.setReferrer(J, I.address);
}

function toFNumber(number, decimals = 6) {
  let res = new BigNumber(number.toString())
    .dividedBy(1e18)
    .toFixed(decimals, 1);
  return Number(res);
}

function toF12Number(number, decimals = 6) {
  let res = new BigNumber(number.toString())
    .dividedBy(1e12)
    .toFixed(decimals, 1);
  return Number(res);
}


async function grantRole(role, account) {
  let manager = await ethers.getContract("Manager");
  return await manager.grantRole(
    keccak256(toUtf8Bytes(role)),
    account.address
  )
}

module.exports = {
  dead: {
    address: '0x000000000000000000000000000000000000dEaD',
    getAddress() {
      return '0x000000000000000000000000000000000000dEaD'
    }
  },
  getAccounts, getContractByNames, multiApprove, getWallet,
  multiRegister, multiTransfer,
  tokenBalance,
  tokenTransfer,
  toFNumber,
  grantRole,
  toF12Number
}
