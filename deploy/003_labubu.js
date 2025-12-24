const {ethers} = require("hardhat");
const {parseEther, parseUnits, keccak256, toUtf8Bytes} = require("ethers/lib/utils");
const accounts = require("../config/account")
const {AddressZero} = ethers.constants

module.exports = async ({getNamedAccounts, deployments, getChainId, getUnnamedAccounts}) => {
  const {deploy} = deployments;
  let {deployer, minter, marketAddress, sellFeeAddress, deflationAddress, depositFeeAddress, reserve} = await getNamedAccounts();
  const chainId = await getChainId()

  let wbnb = (await ethers.getContract("WBNB")).address;
  let router = (await ethers.getContract("UniswapV2Router02")).address;

  let manager = await ethers.getContract("Manager");
  let nft = await ethers.getContract("LabubuNFT");

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
  let registerV2 = await ethers.getContract("RegisterV2");


  await deploy('SkyLabubu', {
    from: deployer,
    args: [wbnb, router],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [
            marketAddress,
            minter,
            sellFeeAddress,
            deflationAddress,
            depositFeeAddress,
            nft.address,
            manager.address,
            registerV2.address,
          ]
        }
      }
    },
    log: true,
  });

  let labubu = await ethers.getContract("SkyLabubu");
  let pair = await labubu.pancakePair()

  await deploy('LabubuOracle', {
    from: deployer,
    args: [wbnb, router],
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
module.exports.tags = ['ava'];
