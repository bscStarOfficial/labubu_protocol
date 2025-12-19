const {ethers} = require("hardhat");
const {parseEther, parseUnits, keccak256, toUtf8Bytes} = require("ethers/lib/utils");
const accounts = require("../config/account")
module.exports = async ({getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) => {
  const {deploy} = deployments;
  let {deployer, root, minter, sellFeeAddress, deflationAddress} = await getNamedAccounts();
  const chainId = await getChainId()

  let wbnb = (await ethers.getContract("WBNB")).address;
  let router = (await ethers.getContract("UniswapV2Router02")).address;
  // NFT
  let nft;


  await deploy('LABUBU3', {
    from: deployer,
    gasLimit: 30000000,
    args: [wbnb, router, root, minter, nft, sellFeeAddress, deflationAddress],
    log: true,
  });

};
module.exports.tags = ['ava'];
