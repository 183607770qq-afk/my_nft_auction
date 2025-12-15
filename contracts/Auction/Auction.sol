// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// 注释掉Chainlink的导入（本地测试用），部署时再解开
// import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IPriceFeed.sol";

/**
 * @title Auction
 * @dev 可升级的NFT拍卖合约，支持ETH和ERC20出价，集成Chainlink预言机转换为美元价格
 */
contract Auction is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // 拍卖状态
    enum AuctionStatus {
        Active,
        Ended,
        Cancelled
    }

    // 拍卖信息结构体
    struct AuctionInfo {
        address nftContract; // NFT合约地址
        uint256 tokenId; // NFT的tokenId
        address seller; // 卖家地址
        uint256 startTime; // 拍卖开始时间（时间戳）
        uint256 endTime; // 拍卖结束时间（时间戳）
        AuctionStatus status; // 拍卖状态
        address highestBidder; // 当前最高出价者
        uint256 highestBidAmount; // 当前最高出价金额（原生代币/ERC20）
        uint256 highestBidUsd; // 当前最高出价的美元价值
        address paymentToken; // 出价的代币地址（address(0)表示ETH）
    }

    // 拍卖ID到拍卖信息的映射
    mapping(uint256 => AuctionInfo) public auctions;
    // 拍卖ID计数器
    uint256 private _auctionIdCounter;
    // ========== 新增：测试模式开关 ==========
    bool public isTestMode; // 测试模式：true=使用固定价格，false=使用Chainlink预言机
    // Chainlink ETH/USD价格预言机地址（不同网络地址不同，初始化时传入）
    address public ethUsdPriceFeed;
    // ERC20代币到Chainlink价格预言机的映射
    mapping(address => address) public tokenUsdPriceFeeds;

    // 事件定义
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 startTime,
        uint256 endTime,
        address paymentToken
    );
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 usdAmount
    );
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 amount
    );
    event AuctionCancelled(uint256 indexed auctionId);

    // 初始化函数（替代构造函数，用于可升级合约）
    function initialize(address _ethUsdPriceFeed, bool _isTestMode) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        ethUsdPriceFeed = _ethUsdPriceFeed;
        isTestMode = _isTestMode; // 初始化测试模式
    }

    // UUPS升级授权函数（仅所有者可升级）
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @dev 添加ERC20代币的Chainlink价格预言机地址
     * @param token ERC20代币地址
     * @param priceFeed 对应的价格预言机地址
     */
    function addTokenPriceFeed(address token, address priceFeed)
        external
        onlyOwner
    {
        tokenUsdPriceFeeds[token] = priceFeed;
    }

    /**
     * @dev 创建拍卖，将NFT上架
     * @param nftContract NFT合约地址
     * @param tokenId NFT的tokenId
     * @param endTime 拍卖结束时间（时间戳）
     * @param paymentToken 出价的代币地址（address(0)表示ETH）
     */
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 endTime,
        address paymentToken
    ) external {
        require(endTime > block.timestamp, "Auction: end time must be in future");
        // 检查NFT是否属于调用者，且已授权给合约
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Auction: not NFT owner");
        require(
            nft.isApprovedForAll(msg.sender, address(this)) ||
                nft.getApproved(tokenId) == address(this),
            "Auction: NFT not approved"
        );

        uint256 auctionId = _auctionIdCounter++;
        auctions[auctionId] = AuctionInfo({
            nftContract: nftContract,
            tokenId: tokenId,
            seller: msg.sender,
            startTime: block.timestamp,
            endTime: endTime,
            status: AuctionStatus.Active,
            highestBidder: address(0),
            highestBidAmount: 0,
            highestBidUsd: 0,
            paymentToken: paymentToken
        });

        // 转移NFT到合约（或锁定，这里直接转移）
        nft.transferFrom(msg.sender, address(this), tokenId);

        emit AuctionCreated(
            auctionId,
            nftContract,
            tokenId,
            msg.sender,
            block.timestamp,
            endTime,
            paymentToken
        );
    }

    /**
     * @dev 出价（ETH）
     * @param auctionId 拍卖ID
     */
    function bid(uint256 auctionId) external payable {
        AuctionInfo storage auction = auctions[auctionId];
        require(
            auction.status == AuctionStatus.Active,
            "Auction: auction not active"
        );
        require(block.timestamp < auction.endTime, "Auction: auction ended");
        require(msg.sender != auction.seller, "Auction: seller cannot bid");
        require(auction.paymentToken == address(0), "Auction: use ERC20 bid");
        require(msg.value > 0, "Auction: ETH bid amount must be > 0");

        uint256 bidAmount = msg.value;
        uint256 bidUsd = _convertToUsd(bidAmount, address(0));

        // 检查出价是否高于当前最高出价（美元价值）
        require(
            bidUsd > auction.highestBidUsd,
            "Auction: bid not higher than current highest (USD)"
        );

        // 退还之前最高出价者的资金（简化版，实际项目需处理重入问题）
        if (auction.highestBidder != address(0)) {
            // 退还ETH
            (bool success, ) = auction.highestBidder.call{
                value: auction.highestBidAmount
            }("");
            require(success, "Auction: ETH refund failed");
        }

        // 更新最高出价信息
        auction.highestBidder = msg.sender;
        auction.highestBidAmount = bidAmount;
        auction.highestBidUsd = bidUsd;

        emit BidPlaced(auctionId, msg.sender, bidAmount, bidUsd);
    }

    /**
     * @dev 出价（ERC20）
     * @param auctionId 拍卖ID
     * @param bidAmount ERC20出价金额
     */
    function bid(uint256 auctionId, uint256 bidAmount) external {
        AuctionInfo storage auction = auctions[auctionId];
        require(
            auction.status == AuctionStatus.Active,
            "Auction: auction not active"
        );
        require(block.timestamp < auction.endTime, "Auction: auction ended");
        require(msg.sender != auction.seller, "Auction: seller cannot bid");
        require(auction.paymentToken != address(0), "Auction: use ETH bid");
        require(bidAmount > 0, "Auction: ERC20 bid amount must be > 0");

        // 转移ERC20代币到合约
        IERC20 token = IERC20(auction.paymentToken);
        require(
            token.transferFrom(msg.sender, address(this), bidAmount),
            "Auction: ERC20 transfer failed"
        );

        // 计算美元价值
        uint256 bidUsd = _convertToUsd(bidAmount, auction.paymentToken);

        // 检查出价是否高于当前最高出价（美元价值）
        require(
            bidUsd > auction.highestBidUsd,
            "Auction: bid not higher than current highest (USD)"
        );

        // 退还之前最高出价者的资金
        if (auction.highestBidder != address(0)) {
            IERC20(auction.paymentToken).transfer(
                auction.highestBidder,
                auction.highestBidAmount
            );
        }

        // 更新最高出价信息
        auction.highestBidder = msg.sender;
        auction.highestBidAmount = bidAmount;
        auction.highestBidUsd = bidUsd;

        emit BidPlaced(auctionId, msg.sender, bidAmount, bidUsd);
    }

    /**
     * @dev 结束拍卖，转移NFT和资金
     * @param auctionId 拍卖ID
     */
    function endAuction(uint256 auctionId) external {
        AuctionInfo storage auction = auctions[auctionId];
        require(
            auction.status == AuctionStatus.Active,
            "Auction: auction not active"
        );
        require(block.timestamp >= auction.endTime, "Auction: auction not ended");

        // 更新拍卖状态
        auction.status = AuctionStatus.Ended;

        if (auction.highestBidder != address(0)) {
            // 转移NFT给最高出价者
            IERC721(auction.nftContract).transferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );

            // 转移资金给卖家
            if (auction.paymentToken == address(0)) {
                // 转移ETH
                (bool success, ) = auction.seller.call{
                    value: auction.highestBidAmount
                }("");
                require(success, "Auction: ETH transfer to seller failed");
            } else {
                // 转移ERC20
                IERC20(auction.paymentToken).transfer(
                    auction.seller,
                    auction.highestBidAmount
                );
            }

            emit AuctionEnded(
                auctionId,
                auction.highestBidder,
                auction.highestBidAmount
            );
        } else {
            // 没有出价，返还NFT给卖家
            IERC721(auction.nftContract).transferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }

    /**
     * @dev 取消拍卖（仅卖家）
     * @param auctionId 拍卖ID
     */
    function cancelAuction(uint256 auctionId) external {
        AuctionInfo storage auction = auctions[auctionId];
        require(
            auction.status == AuctionStatus.Active,
            "Auction: auction not active"
        );
        require(msg.sender == auction.seller, "Auction: not seller");

        // 更新拍卖状态
        auction.status = AuctionStatus.Cancelled;

        // 返还NFT给卖家
        IERC721(auction.nftContract).transferFrom(
            address(this),
            auction.seller,
            auction.tokenId
        );

        emit AuctionCancelled(auctionId);
    }

    /**
     * @dev 将代币金额转换为美元价值
     * @param amount 代币金额
     * @param token 代币地址（address(0)表示ETH）
     * @return 美元价值（单位：wei）
     */
    function _convertToUsd(uint256 amount, address token)
        internal
        view
        returns (uint256)
    {
        // ========== 核心修改：测试模式使用固定价格 ==========
        if (isTestMode) {
            // 本地测试：1 ETH = 2000 USD，1 ERC20 = 1 USD（简化）
            return token == address(0) ? amount * 2000 : amount;
        }

        // 生产模式：使用Chainlink预言机（部署时启用）
        address priceFeedAddress = token == address(0)
            ? ethUsdPriceFeed
            : tokenUsdPriceFeeds[token];
        require(
            priceFeedAddress != address(0),
            "Auction: no price feed for token"
        );

        // 重新导入Chainlink接口后，取消注释以下代码
        // AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        // (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        // require(price > 0, "Auction: invalid price feed data");
        // require(updatedAt > 0, "Auction: price feed not updated");
        // require(roundId == answeredInRound, "Auction: stale price feed");

        // uint8 priceDecimals = priceFeed.decimals();
        // uint8 tokenDecimals = 18;
        // uint256 amountInWei = amount * (10 ** tokenDecimals);
        // uint256 usdAmount = (amountInWei * uint256(price)) / (10 ** priceDecimals);

        // 临时返回固定值（部署时替换为上面的计算）
        uint256 usdAmount = amount * 2000;
        return usdAmount;
    }

    // 接收ETH的函数（用于ETH出价）
    receive() external payable {}
}