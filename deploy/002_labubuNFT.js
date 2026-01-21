const {ethers} = require("hardhat");
module.exports = async ({getNamedAccounts, deployments, getChainId}) => {
  const {deploy} = deployments;
  let {deployer, reserve} = await getNamedAccounts();
  const chainId = await getChainId()

  let manager = await ethers.getContract("Manager");
  if (chainId === "5611") {
    reserve = deployer;
  }

  if (chainId === "56") {
    reserve = (await ethers.getContract("MultiSigBank01")).address;
  }

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
