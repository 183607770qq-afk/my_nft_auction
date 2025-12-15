const { network } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("----------------------------------------------------");
  log("Deploying MyNFT Contract...");
  const myNFT = await deploy("MyNFT", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  log(`MyNFT deployed at: ${myNFT.address}`);
};

module.exports.tags = ["all", "nft"];