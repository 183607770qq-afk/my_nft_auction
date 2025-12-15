# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```
nft-auction-market/
├── contracts/
│   ├── NFT.sol              # ERC721 NFT合约
│   ├── Auction/         # 拍卖合约（UUPS可升级）
│        ├──interfaces/    
                └──IPriceFeed.sol
         └──Aution.sol
         └──MockPriceFeed.sol
├── deploy/                  # 部署脚本（hardhat-deploy）
│   ├── 01_deploy_nft.js
│ 
│   └── 03_deploy_auction.js
├── test/                    # 测试文件
│   └── Auction.test.js
├── hardhat.config.js        # Hardhat配置
├── .env                     # 环境变量（私钥、RPC URL等）
└── README.md                # 项目文档


部署脚本：npx hardhat deploy
测试脚本：npx hardhat test test/Auction.test.js