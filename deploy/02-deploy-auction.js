const { network } = require("hardhat");
const { upgrades } = require("hardhat");

// Chainlink ETH/USD Price Feed地址（不同网络）
const PRICE_FEED_ADDRESSES = {
  hardhat: "0x694AA1769357215DE4FAC081bf1f309aDC325306", // Sepolia的ETH/USD地址（hardhat本地测试用这个）
  sepolia: "0x694AA1769357215DE4FAC081bf1f309aDC325306",
};

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  log("----------------------------------------------------");
  log("Deploying Auction Contract (UUPS Upgradeable)...");

  // 获取Chainlink ETH/USD价格预言机地址
  const ethUsdPriceFeed = PRICE_FEED_ADDRESSES[network.name] || PRICE_FEED_ADDRESSES.sepolia;

  // 部署可升级合约的实现合约，并部署代理
  const Auction = await hre.ethers.getContractFactory("Auction");
  const auctionProxy = await upgrades.deployProxy(Auction, [ethUsdPriceFeed], {
    initializer: "initialize",
    kind: "uups",
  });
  await auctionProxy.waitForDeployment();

  const auctionAddress = await auctionProxy.getAddress();
  log(`Auction proxy deployed at: ${auctionAddress}`);

  // （可选）添加一个ERC20代币的价格预言机地址（比如USDC/USD on Sepolia）
  if (network.name !== "hardhat") {
    const usdcAddress = "0x514910771AF9Ca656af840dff83E8264EcF986CA"; // Sepolia USDC地址
    const usdcUsdPriceFeed = "0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E"; // Sepolia USDC/USD价格预言机
    await auctionProxy.addTokenPriceFeed(usdcAddress, usdcUsdPriceFeed);
    log(`Added USDC price feed: ${usdcUsdPriceFeed} for token: ${usdcAddress}`);
  }
};

module.exports.tags = ["all", "auction"];