const {ethers} = require("hardhat");
const {Wallet} = require("ethers");
const {setBalance} = require("@nomicfoundation/hardhat-network-helpers");
const {parseEther} = require("ethers/lib/utils");
const {toFNumber, toF12Number} = require("./common");
const BigNumber = require("bignumber.js");

async function getDecline() {
  let oracle = await ethers.getContract("LabubuOracle");
  return await oracle.getDecline();
}

async function getLabubuPrice() {
  let oracle = await ethers.getContract("LabubuOracle");
  let price = await oracle.getLabubuPrice();
  return toF12Number(price);
}

async function setOpenPrice() {
  let oracle = await ethers.getContract("LabubuOracle");
  return await oracle.setOpenPrice();
}

async function getOpenPrice() {
  let oracle = await ethers.getContract("LabubuOracle");
  let res = await oracle.getOpenPrice();
  return [
    res[0],
    toF12Number(res[1]),
    res[2],
  ];
}

async function setOpenPriceByAdmin(price) {
  let oracle = await ethers.getContract("LabubuOracle");
  return await oracle.setOpenPriceByAdmin(price);
}

module.exports = {
  getDecline,
  getLabubuPrice,
  setOpenPrice,
  setOpenPriceByAdmin,
  getOpenPrice
}
