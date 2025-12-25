const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const common = require("./common");
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {BigNumber} = require("bignumber.js");

let labubu, wbnb, router;

async function dexInit() {
  [labubu, wbnb, router] = await common.getContractByNames(["SkyLabubu", 'WBNB', 'UniswapV2Router02']);
}

async function getAmountsOut(amountIn, contractAddresses = []) {
  let res = await router.getAmountsOut(amountIn, contractAddresses);
  return Number(formatEther(res[res.length - 1]));
}

async function getAmountsIn(amountOut, contractAddresses = []) {
  let res = await router.getAmountsIn(amountOut, contractAddresses);
  return Number(formatEther(res[0]));
}

// async function addLiquidity(account, avaAmount, usdtAmount) {
//   await router.connect(account).addLiquidity(
//     ava.address,
//     usdt.address,
//     parseEther(usdtAmount.toString()),
//     parseEther(avaAmount.toString()),
//     0,
//     0,
//     account.address, 9999999999
//   );
// }

function addLiquidityETH(account, labubuAmount, bnbAmount) {
  return router.connect(account).addLiquidityETH(
    labubu.address,
    parseEther(labubuAmount.toString()),
    0,
    0,
    account.address, 9999999999, {
      value: parseEther(bnbAmount.toString()),
    }
  );
}

function swapExactETHForTokensSupportingFeeOnTransferTokens(account, bnbAmount) {
  return router.connect(account).swapExactETHForTokensSupportingFeeOnTransferTokens(
    0,
    [wbnb.address, labubu.address],
    account.address,
    9999999999, {
      value: parseEther(bnbAmount.toString()),
    }
  );
}


function swapExactTokensForETHSupportingFeeOnTransferTokens(account, labubuAmount) {
  return router.connect(account).swapExactETHForTokensSupportingFeeOnTransferTokens(
    labubuAmount,
    0,
    [labubu.address, wbnb.address],
    account.address,
    9999999999
  );
}


module.exports = {
  dexInit,
  getAmountsOut,
  getAmountsIn,
  addLiquidityETH,
  buy: swapExactETHForTokensSupportingFeeOnTransferTokens,
  sell: swapExactTokensForETHSupportingFeeOnTransferTokens
}
