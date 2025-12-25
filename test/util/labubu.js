const {parseEther, formatEther, parseUnits} = require("ethers/lib/utils");
const common = require("./common");

let oracle;

async function oracleInit() {
  [oracle] = await common.getContractByNames(["SkyLabubu"]);
}

async function getDecline() {
  return await oracle.getDecline()
}

async function getLabubuPrice() {
  return await oracle.getLabubuPrice()
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
