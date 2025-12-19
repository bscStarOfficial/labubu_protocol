module.exports = {
  hardhat: {
    // deploy: ['*-deploy/'],
    mining: {
      auto: true,
      // interval: 2000
    }
  },
  bsc: {
    url: 'https://bsc-dataseed.bnbchain.org',
    // url: 'https://bsc-mainnet.core.chainstack.com/fb89443d044ec0368a0b305e4fc983f1',
    accounts: [process.env.PRIVATE_KEY_BSC],
    chainId: 56,
    gasPrice: 1 * 100000000, // 0.1Gwei
    timeout: 60 * 1000
  },
  arb: {
    url: "https://rpc.ankr.com/arbitrum/36d9e96e6b56e9eb728e29268f596780647330f462d1329d3ed73d3a07dd5d31",
    accounts: [process.env.PRIVATE_KEY_BSC],
    chainId: 42161,
    // gasPrice: 0.1 * 1000000000, // 6Gwei
    timeout: 60 * 1000
  },
  opBnb: {
    url: 'https://opbnb-mainnet-rpc.bnbchain.org',
    accounts: [process.env.PRIVATE_KEY_BSC],
    chainId: 204,
    gas: 5000000,
    timeout: 60 * 1000
  },
  test: {
    url: "https://bsc-testnet.publicnode.com",
    // url: "https://bsc-testnet.public.blastapi.io",
    // url: "https://data-seed-prebsc-2-s3.binance.org:8545",
    accounts:
      process.env.PRIVATE_KEY_TEST !== undefined ? [process.env.PRIVATE_KEY_TEST] : [],
    chainId: 97,
    gasPrice: 5 * 1000000000, // 5Gwei
    timeout: 60 * 1000,
  },
  opTest: {
    url: "https://opbnb-testnet-rpc.bnbchain.org",
    accounts:
      process.env.PRIVATE_KEY_TEST !== undefined ? [process.env.PRIVATE_KEY_TEST] : [],
    chainId: 5611,
  }
}
