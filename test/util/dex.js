const {parseEther, formatEther} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const common = require("./common");
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {BigNumber} = require("bignumber.js");

let labubu, wbnb, router, pair;

async function dexInit() {
  [labubu, wbnb, router] = await common.getContractByNames(["SkyLabubu", 'WBNB', 'UniswapV2Router02']);
  let pairAddress = await labubu.pancakePair();
  pair = await ethers.getContractAt("UniswapV2Pair", pairAddress);
}

async function lpApprove(account, amount = 10000000) {
  await pair.connect(account).approve(
    router.address,
    parseEther(amount.toString())
  )
}

async function lpBalance(account) {
  let res = await pair.balanceOf(account.address);
  return new BigNumber(res.toString()).dividedBy(1e18).toNumber()
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

function removeLiquidityETH(account, lpAmount) {
  return router.connect(account).removeLiquidityETH(
    labubu.address,
    parseEther(lpAmount.toString()),
    0,
    0,
    account.address,
    9999999999
  );
}

function removeLiquidity(account, lpAmount) {
  return router.connect(account).removeLiquidity(
    labubu.address,
    wbnb.address,
    parseEther(lpAmount.toString()),
    0,
    0,
    account.address,
    9999999999
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

async function getLabubuAmountByLp(lpAmount) {
  let pairAddress = await labubu.pancakePair();
  let pair = await ethers.getContractAt("UniswapV2Pair", pairAddress);
  let totalLp = await pair.totalSupply();

  let [_1, rLabubu, _2] = await pair.getReserves();

  return parseEther(lpAmount.toString())
    .mul(rLabubu)
    .div(totalLp);
}

module.exports = {
  dexInit,
  getAmountsOut,
  getAmountsIn,
  addLiquidityETH,
  removeLiquidityETH,
  removeLiquidity,
  buy: swapExactETHForTokensSupportingFeeOnTransferTokens,
  // sell: swapExactTokensForETHSupportingFeeOnTransferTokens,
  getLabubuAmountByLp,
  lpApprove,
  lpBalance
}
