# NFT Auction Market
基于Hardhat的NFT拍卖市场，支持ETH/ERC20出价、Chainlink价格转换、UUPS合约升级。

## 项目结构
- `contracts/`: 智能合约（NFT、Auction、MockERC20）
- `deploy/`: 部署脚本
- `test/`: 测试用例
- `hardhat.config.js`: Hardhat配置

## 功能说明
1. **NFT合约**：支持铸造、转移ERC721 NFT。
2. **拍卖合约**：
   - 创建拍卖：将NFT上架拍卖，支持ETH/ERC20支付。
   - 出价：用户可以ETH或ERC20出价，自动转换为美元比较。
   - 结束拍卖：NFT转移给最高出价者，资金转移给卖家。
   - 取消拍卖：卖家可在无出价时取消拍卖。
3. **Chainlink预言机**：获取ETH/ERC20的美元价格，实现跨币种价格比较。
4. **UUPS升级**：支持合约逻辑升级，不改变合约地址。

## 部署步骤
### 1. 环境准备
- 安装Node.js（v16+）和npm。
- 配置`.env`文件，填写Sepolia RPC URL和钱包私钥。

### 2. 安装依赖
```bash
npm install