const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const common = require("./common");
const BigNumber = require("bignumber.js");

let oracle;
async function oracleInit() {
  [oracle] = await common.getContractByNames(["SkyLabubu"]);
}

async function getDecline() {
  let res = await oracle.getDecline()
  return new BigNumber(res.toString()).dividedBy(1e4).toNumber();
}

async function getLabubuPrice() {
  let price = await oracle.getLabubuPrice()
  return new BigNumber(price.toString()).dividedBy(1e6).toNumber();
}

async function setOpenPrice() {
  return await oracle.setOpenPrice()
}

async function setOpenPriceByAdmin(price) {
  return await oracle.setOpenPriceByAdmin(price)
}

module.exports = {
  oracleInit,
  getDecline,
  getLabubuPrice,
  setOpenPrice,
  setOpenPriceByAdmin
}
