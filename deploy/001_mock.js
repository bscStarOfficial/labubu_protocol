const {ethers} = require("hardhat");
const {parseEther, parseUnits, keccak256, toUtf8Bytes} = require("ethers/lib/utils");

module.exports = async ({getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) => {
  const {deploy} = deployments;
  let {deployer} = await getNamedAccounts();
  const chainId = await getChainId()
  if (chainId == 56) return;

  await deploy('USDT', {
    from: deployer,
    gasLimit: 30000000,
    args: [],
    log: true,
  });

  await deploy('WBNB', {
    from: deployer,
    gasLimit: 30000000,
    args: [],
    log: true,
  });

  await deploy('UniswapV2Factory', {
    from: deployer,
    gasLimit: 30000000,
    args: [deployer],
    log: true,
  });

  let wbnb = await ethers.getContract("WBNB");
  let factory = await ethers.getContract("UniswapV2Factory");

  await deploy('UniswapV2Router02', {
    from: deployer,
    gasLimit: 30000000,
    args: [factory.address, wbnb.address],
    log: true,
  });

};
module.exports.tags = ['mock'];
