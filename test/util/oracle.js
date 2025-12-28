const {ethers} = require("hardhat");
const {Wallet} = require("ethers");
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {parseEther} = require("ethers/lib/utils");

async function getDecline() {
  let oracle = await ethers.getContract("LabubuOracle");
  return await oracle.getDecline();
}

async function getLabubuPrice() {
  let oracle = await ethers.getContract("LabubuOracle");
  return await oracle.getLabubuPrice();
}

async function setOpenPrice() {
  let oracle = await ethers.getContract("LabubuOracle");
  return await oracle.setOpenPrice();
}

async function setOpenPriceByAdmin(price) {
  let oracle = await ethers.getContract("LabubuOracle");
  return await oracle.setOpenPriceByAdmin(price);
}

module.exports = {
  getDecline,
  getLabubuPrice,
  setOpenPrice,
  setOpenPriceByAdmin
}
