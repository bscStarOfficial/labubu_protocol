const {ethers} = require("hardhat");
const {AddressZero} = ethers.constants

module.exports = async ({getNamedAccounts, deployments, getChainId}) => {
  const {deploy} = deployments;
  let {deployer, marketAddress} = await getNamedAccounts();

  let registerV2 = await ethers.getContract("RegisterV2");
  let manager = await ethers.getContract("Manager");
  let labubu = await ethers.getContract("SkyLabubu");
  let oracle = await ethers.getContract("LabubuOracle");
  let chainId = await getChainId();

  if (chainId === "56") {
    marketAddress = '0x1074AAD70bbb235B670BA3391975e245624426c1';
  }

  if (chainId === "5611") {
    marketAddress = deployer;
  }

  await deploy('LabubuRecoupment', {
    from: deployer,
    args: [],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [
            marketAddress,
            manager.address,
            registerV2.address,
            oracle.address,
            labubu.address
          ]
        }
      }
    },
    log: true,
  });
  let recoupment = await ethers.getContract("LabubuRecoupment");

  if (await labubu.recoupment() === AddressZero) {
    let tx = await labubu.setRecoupment(recoupment.address);
    console.log("labubu.setRecoupment: ", recoupment.address);
    await tx.wait()
  }
};

module.exports.tags = ['recoupment'];
