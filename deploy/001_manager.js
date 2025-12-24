const {ethers} = require("hardhat");
const {AddressZero} = ethers.constants

module.exports = async ({getNamedAccounts, deployments, getChainId, getUnnamedAccounts,}) => {
  const {deploy} = deployments;
  let {deployer} = await getNamedAccounts();

  await deploy('Manager', {
    from: deployer,
    args: [],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: []
        }
      }
    },
    log: true,
  });
};
module.exports.tags = ['manager'];
