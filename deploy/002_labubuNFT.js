const {ethers} = require("hardhat");
const {parseEther, parseUnits, keccak256, toUtf8Bytes} = require("ethers/lib/utils");
const accounts = require("../config/account")
module.exports = async ({getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) => {
  const {deploy} = deployments;
  let {deployer, reserve} = await getNamedAccounts();
  const chainId = await getChainId()

  let manager = await ethers.getContract("Manager");


  await deploy('LabubuNFT', {
    from: deployer,
    args: [],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [manager.address, reserve]
        }
      }
    },
    log: true,
  });

};
module.exports.tags = ['nft'];
