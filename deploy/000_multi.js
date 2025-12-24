const {parseEther} = require("ethers/lib/utils");
const {ethers} = require("hardhat");
const {AddressZero} = ethers.constants

module.exports = async ({getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) => {
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId()
  if (chainId === "31337") return;

  let owners = [
    '0x8aEc273d79e15A4E7eE562e46f64DC4715C06c50',
    '0xf7c092D115742807ceb61981b4B57b741E045Fa0',
    '0xE5Df796595cb5fa1CbAFE588Fa2097eBf74E90d4',
    '0x7473c3309dc1c6c82F2f2a1447bF3b2e55D993C4',
    '0xB8E0Ed7cADBD868Cf1ea22b617ceB896643cC13b'
  ];
  let requirement = 3;
  await deploy('MultiSigBank01', {
    contract: 'MultiSigBank',
    from: deployer,
    args: [owners, requirement],
    log: true,
  });


  await deploy('Multicall', {
    contract: 'Multicall',
    from: deployer,
    args: [],
    log: true,
  });
};
module.exports.tags = ['multi'];
