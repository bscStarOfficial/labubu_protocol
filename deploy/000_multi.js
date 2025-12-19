const {parseEther} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const {AddressZero} = ethers.constants

module.exports = async ({getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) => {
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId()
  if (chainId == 31337) return;
  await deploy('Multicall', {
    contract: 'Multicall',
    from: deployer,
    args: [],
    log: true,
  });
};
module.exports.tags = ['multi'];
