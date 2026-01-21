const {ethers} = require("hardhat");
const {AddressZero} = ethers.constants

module.exports = async ({getNamedAccounts, deployments}) => {
  const {deploy} = deployments;
  let {deployer} = await getNamedAccounts();

  let manager = await ethers.getContract("Manager");
  let labubu = await ethers.getContract("SkyLabubu");
  let pair = await labubu.pancakePair()

  await deploy('LabubuOracle', {
    from: deployer,
    args: [],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [
            manager.address,
            pair,
            labubu.address
          ]
        }
      }
    },
    log: true,
  });
  let oracle = await ethers.getContract("LabubuOracle");
  if (await labubu.oracle() === AddressZero) {
    let tx = await labubu.setOracle(oracle.address);
    console.log("labubu.setOracle: ", oracle.address);
    await tx.wait()
  }
};
module.exports.tags = ['oracle'];
