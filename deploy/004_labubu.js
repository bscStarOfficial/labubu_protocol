const {ethers} = require("hardhat");
const {keccak256, toUtf8Bytes, getContractAddress} = require("ethers/lib/utils");

module.exports = async ({getNamedAccounts, deployments, getChainId}) => {
  const {deploy} = deployments;
  let {deployer, minter, marketAddress, sellFeeAddress, deflationAddress, depositFeeAddress} = await getNamedAccounts();
  const chainId = await getChainId()

  let wbnb = (await ethers.getContract("WBNB")).address;
  let router = (await ethers.getContract("UniswapV2Router02")).address;
  let manager = await ethers.getContract("Manager");
  let nft = await ethers.getContract("LabubuNFT");
  let registerV2 = await ethers.getContract("RegisterV2");

  while (true) {
    if (chainId !== "31337") return;
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

  if (chainId === "56") {
    minter = '0xcBcd66D419a0599445fe1978Cf8cb448929d7D56';
    sellFeeAddress = '0xC33b69d6ff0a4A4695Ab954f98a4e041656016Da';
    deflationAddress = '0x3B8149d3D0dC633e8519bAA5258F843Bf16cc20D';
    depositFeeAddress = '0x690542DfdCd58c2ae7d2169954e51D345c6F0DCf';
    marketAddress = '0x1074AAD70bbb235B670BA3391975e245624426c1';
  }

  if (chainId === "5611") {
    minter = deployer;
    sellFeeAddress = deployer;
    deflationAddress = deployer;
    depositFeeAddress = deployer;
    marketAddress = deployer;
  }

  await deploy('SkyLabubu', {
    from: deployer,
    args: [wbnb, router],
    proxy: {
      proxyContract: 'UUPS',
      execute: {
        init: {
          methodName: 'initialize',
          args: [
            minter,
            sellFeeAddress,
            deflationAddress,
            depositFeeAddress,
            nft.address,
            registerV2.address,
          ]
        }
      }
    },
    log: true,
  });

  let labubu = await ethers.getContract("SkyLabubu");

  let manageRoles = [
    ['SKY_LABUBU', labubu.address]
  ];
  for (let item of manageRoles) {
    let role = keccak256(toUtf8Bytes(item[0]));
    let account = item[1];
    if (!await manager.hasRole(role, account)) {
      let tx = await manager.grantRole(role, account);
      console.log(`grant role ${item[0]} ${account}`)
      await tx.wait();
    }
  }

  let tokenRoles = [
    ['TaxExempt', labubu.address],
    ['TaxExempt', deployer],
    // ['TaxExempt', await labubu.SELL_MIDDLEWARE()], // 不能白名单，不然无法识别卖出
    ['TaxExempt', await labubu.BUY_MIDDLEWARE()],
    ['TaxExempt', marketAddress],
    ['TaxExempt', minter],
    ['TaxExempt', sellFeeAddress],
    ['TaxExempt', deflationAddress],
  ]
  for (let item of tokenRoles) {
    let role = keccak256(toUtf8Bytes(item[0]));
    let account = item[1];
    if (!await labubu.hasRole(role, account)) {
      let tx = await labubu.grantRole(role, account);
      console.log(`grant role ${item[0]} ${account}`)
      await tx.wait();
    }
  }
};

module.exports.tags = ['labubu'];
