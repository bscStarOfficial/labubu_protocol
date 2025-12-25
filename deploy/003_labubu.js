const {ethers} = require("hardhat");
const {parseEther, parseUnits, keccak256, toUtf8Bytes, getContractAddress} = require("ethers/lib/utils");
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


  while (true) {
    // 获取即将部署点合约地址, +1因为先部署imp
    let nonce = await ethers.provider.getTransactionCount(deployer) + 1
    let addressPredict = getContractAddress({
      from: deployer, nonce
    })
    console.log({nonce, addressPredict});
    // 如果不匹配，自动增加nonce
    if (addressPredict.toLowerCase() > wbnb.toLowerCase()) {
      console.log(addressPredict.toLowerCase(), wbnb.toLowerCase())
      break;
    }
    let tx = await ethers.provider.getSigner(deployer).sendTransaction({
      from: deployer,
      to: deployer,
      value: '0'
    });
    await tx.wait()
  }

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

  let roles = [
    ['SKY_LABUBU', labubu.address],
    ['TaxExempt', labubu.address],
    ['TaxExempt', deployer],
    ['TaxExempt', await labubu.SWAP_MIDDLEWARE()],
    ['TaxExempt', marketAddress],
    ['TaxExempt', minter],
    ['TaxExempt', sellFeeAddress],
    ['TaxExempt', deflationAddress],
  ];

  for (let item of roles) {
    let role = keccak256(toUtf8Bytes(item[0]));
    let account = item[1];
    if (!await manager.hasRole(role, account)) {
      let tx = await manager.grantRole(role, account);
      console.log(`grant role ${item[0]} ${account}`)
      await tx.wait();
    }
  }

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
module.exports.tags = ['labubu'];
