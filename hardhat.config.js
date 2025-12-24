require("dotenv").config();

// require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-chai-matchers")
require("@nomicfoundation/hardhat-verify");
require("@nomiclabs/hardhat-ethers");
require('hardhat-deploy');
require('hardhat-contract-sizer');
require("hardhat-change-network");
require('@primitivefi/hardhat-dodoc');
require('hardhat-abi-exporter');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: require("./config/solidity"),
  networks: require("./config/network"),
  paths: require("./config/paths"),
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  namedAccounts: {
    deployer: 0,
    marketAddress: 1,
    minter: 2,
    sellFeeAddress: 3,
    deflationAddress: 4,
    depositFeeAddress: 5,
    reserve: 6,
    A: 10,
    B: 11,
    C: 12,
    D: 13,
    E: 14,
    F: 15,
    G: 16,
    H: 17,
    I: 18,
    J: 19
  },
  dodoc: {
    include: [
      "Manager",
    ],
    exclude: [
      'node_modules',
      'legacy',
      'libraries',
      'interfaces',
    ],
    runOnCompile: false,
    keepFileStructure: false,
  },
  abiExporter: { // npx hardhat export-abi --no-compile
    path: './docs',
    clear: false,
    flat: true,
    runOnCompile: true,
    only: [
      "Manager",
    ],
    except: [
      'node_modules',
      'libraries',
      'interfaces',
    ]
  },
  gasReporter: {
    excludeContracts: [
      'node_modules',
      'libraries',
      'interfaces',
      'USDT',
      'ERC20',
      'WTRX',
      'LiquidRouter',
      'RegisterV2',
      'BTN',
      'Manager'
    ],
    enabled: process.env.GAS_REPORT==1
  }
};
