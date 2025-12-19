const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const common = require("./common");
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {BigNumber} = require("bignumber.js");

let ava, usdt, router;

async function dexInit() {
  [ava, usdt, router] = await common.getContractByNames(["AVA", 'USDT', 'UniswapV2Router02']);
}

async function getAmountsOut(amountIn, contractAddresses = []) {
  let res = await router.getAmountsOut(amountIn, contractAddresses);
  return Number(formatEther(res[res.length - 1]));
}

async function getAmountsIn(amountOut, contractAddresses = []) {
  let res = await router.getAmountsIn(amountOut, contractAddresses);
  return Number(formatEther(res[0]));
}

async function addLiquidity(account, avaAmount, usdtAmount) {
  await router.connect(account).addLiquidity(
    ava.address,
    usdt.address,
    parseEther(usdtAmount.toString()),
    parseEther(avaAmount.toString()),
    0,
    0,
    account.address, 9999999999
  );
}

function swapExactTokensForTokensSupportingFeeOnTransferTokens(
  amountIn, path, account,
) {
  let pathAddr = [path[0].address, path[1].address];
  return router.connect(account).swapExactTokensForTokensSupportingFeeOnTransferTokens(
    parseEther(amountIn.toString()),
    0,
    pathAddr,
    account.address,
    9999999999
  );
}


module.exports = {
  dexInit,
  getAmountsOut,
  getAmountsIn,
  addLiquidity,
  swapE2T: swapExactTokensForTokensSupportingFeeOnTransferTokens,
}
