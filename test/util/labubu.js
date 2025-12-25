const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const common = require("./common");

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


function deposit(account, bnbAmount) {
  return account.sendTransaction({
    from: account.address,
    to: labubu.address,
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
  deposit
}
