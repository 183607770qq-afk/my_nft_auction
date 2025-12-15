// 第一步：加载.env文件（必须放在文件开头）
require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("@openzeppelin/hardhat-upgrades");
require("solidity-coverage");
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      { version: "0.8.27" }, // 适配OpenZeppelin和Chainlink合约的编译器版本
    ],
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL, // 替换为你的Infura API Key
      accounts: [process.env.PRIVATE_KEY], // 替换为你的测试网私钥（记得保管好，不要提交到代码仓库）
      chainId: 11155111,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0, // 默认第一个账户为部署者
    },
  },
  gasReporter: {
    enabled: true, // 开启gas消耗统计
    currency: "USD",
  },
//   etherscan: {
//     apiKey: "YOUR_ETHERSCAN_API_KEY", // 替换为你的Etherscan API Key（用于验证合约）
//   },
};