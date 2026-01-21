const {ethers} = require("hardhat");

module.exports = async ({getNamedAccounts, deployments}) => {
  const {deploy} = deployments;
  let {deployer} = await getNamedAccounts();
  let manager = await ethers.getContract("Manager");

  await deploy('RegisterV2', {
    from: deployer,
    args: [],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [manager.address]
        }
      }
    },
    log: true,
  });
};

module.exports.tags = ['register'];
