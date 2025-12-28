module.exports = async ({getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) => {
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await getChainId()
  if (chainId === "31337") return;

  let owners = [
    '0xc172397B7A4c84E71541A2DDF4F403e396d52b4d',
    '0xc0326624EE57Db85270C8083fc3E5B2d18265fE8',
    '0xA2F0Ea9d57914e82a65E47B146aE020Ce56C3955',
    '0xa16Be7DB418479E8441508C7331716D1234Fa0e4',
    '0xcCfef077902333AFb1cF7F8c338E03edfe8bF8da'
  ];
  let requirement = 4;

  await deploy('MultiSigBank02', {
    contract: 'MultiSigBank',
    from: deployer,
    args: [owners, requirement],
    log: true,
  });
};

module.exports.tags = ['multi02'];
