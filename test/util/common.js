const {ethers, deployments, getNamedAccounts, getUnnamedAccounts} = require("hardhat");
const {formatEther, parseEther} = require("ethers/lib/utils")
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");

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
  await registerV2.connect(A).register(await registerV2.ROOT_USER());
  await registerV2.connect(B).register(A.address);
  await registerV2.connect(C).register(B.address);
  await registerV2.connect(D).register(C.address);
  await registerV2.connect(E).register(D.address);
  await registerV2.connect(F).register(E.address);
  await registerV2.connect(G).register(F.address);
  await registerV2.connect(H).register(G.address);
  await registerV2.connect(I).register(H.address);
  await registerV2.connect(J).register(I.address);
}

async function multiRegisterV3() {
  let register = await ethers.getContract("RegisterV3");
  let [A, B, C, D, E, F, G, H, I, J] = await getAccounts(["A", "B", "C", "D", "E", "F", "G", "H", "I"]);

  let initAddress = await register.ROOT_USER();
  // 随机生成16个账户，将推荐关系拉长，测试teamYJ
  for (let i = 0; i < 16; i++) {
    let wR = ethers.Wallet.createRandom().connect(ethers.provider);
    await setBalance(wR.address, parseEther('1'));
    await register.connect(wR).register(initAddress)
    initAddress = wR.address;
  }

  await register.connect(A).register(initAddress);
  await register.connect(B).register(A.address);
  await register.connect(C).register(B.address);
  await register.connect(D).register(C.address);
  await register.connect(E).register(D.address);
  await register.connect(F).register(E.address);
  await register.connect(G).register(F.address);
  await register.connect(H).register(G.address);
  await register.connect(I).register(H.address);
}

function toFNumber(number) {
  return Number(formatEther(number));
}

module.exports = {
  dead: {address: '0x000000000000000000000000000000000000dEaD'},
  getAccounts, getContractByNames, multiApprove, getWallet,
  multiRegister, multiRegisterV3, multiTransfer,
  tokenBalance,
  tokenTransfer,
  toFNumber,
}
