const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NFT Auction Market", function () {
    let myNFT;
    let auction;
    let deployer;
    let user1;
    let user2;

    beforeEach(async function () {
        // 获取签名者
        [deployer, user1, user2] = await ethers.getSigners();

        // 1. 部署NFT合约
        const MyNFT = await ethers.getContractFactory("MyNFT");
        myNFT = await MyNFT.deploy();
        await myNFT.waitForDeployment();

        // 2. 部署Auction合约（UUPS代理），启用测试模式（第二个参数为true）
        const Auction = await ethers.getContractFactory("Auction");
        // 测试模式下，第一个参数（预言机地址）可以传任意值（比如零地址）
        auction = await upgrades.deployProxy(Auction, [ethers.ZeroAddress, true], {
            initializer: "initialize",
            kind: "uups",
        });
        await auction.waitForDeployment();

        // 3. 铸造一个NFT给deployer，并授权Auction合约操作
        await myNFT.mint(deployer.address);
        await myNFT.approve(await auction.getAddress(), 0);
    });

    describe("NFT Contract", function () {
        it("Should mint an NFT to deployer", async function () {
            expect(await myNFT.ownerOf(0)).to.equal(deployer.address);
        });
    });

    describe("Auction Contract", function () {
        it("Should create an auction for NFT", async function () {
            const blockTimestamp = await ethers.provider.getBlock("latest").then((block) => block.timestamp);
            const endTime = blockTimestamp + 3600; // 1小时后结束
// 第一步：执行创建拍卖的交易，不监听事件
const tx = await auction.createAuction(
  await myNFT.getAddress(),
  0,
  endTime,
  ethers.ZeroAddress
);
await tx.wait(); // 等待交易上链

            const auctionInfo = await auction.auctions(0);
            expect(auctionInfo.seller).to.equal(deployer.address);
            expect(auctionInfo.status).to.equal(0); // Active
        });

        it("Should allow user to bid with ETH", async function () {
            const blockTimestamp = await ethers.provider.getBlock("latest").then((b) => b.timestamp);
            const endTime = blockTimestamp + 3600;
            await auction.createAuction(
                await myNFT.getAddress(),
                0,
                endTime,
                ethers.ZeroAddress
            );

            const bidAmount = ethers.parseEther("1");
            const expectedUsd = bidAmount * BigInt(2000);

            // 正确调用重载函数
            await expect(
                auction.connect(user1)["bid(uint256)"](0, { value: bidAmount })
            )
                .to.emit(auction, "BidPlaced")
                .withArgs(
                    0,
                    user1.address,
                    bidAmount,
                    expectedUsd// 测试模式下，1 ETH = 2000 USD
                );

            const auctionInfo = await auction.auctions(0);
            expect(auctionInfo.highestBidder).to.equal(user1.address);
            expect(auctionInfo.highestBidAmount).to.equal(bidAmount);
            expect(auctionInfo.highestBidUsd).to.equal(expectedUsd);

            const higherBidAmount = ethers.parseEther("2");
            const expectedUsd2 = higherBidAmount * BigInt(2000);


            await expect(
                auction.connect(user2)["bid(uint256)"](0, { value: higherBidAmount })
            )
                .to.emit(auction, "BidPlaced")
                .withArgs(
                    0,
                    user2.address,
                    higherBidAmount,
                    expectedUsd2
                );

            const updatedAuctionInfo = await auction.auctions(0);
            expect(updatedAuctionInfo.highestBidder).to.equal(user2.address);
            expect(updatedAuctionInfo.highestBidAmount).to.equal(higherBidAmount);
            expect(updatedAuctionInfo.highestBidUsd).to.equal(expectedUsd2);
        });

        it("Should end auction and transfer NFT and funds", async function () {
            const blockTimestamp = await ethers.provider.getBlock("latest").then((b) => b.timestamp);
            const endTime = blockTimestamp + 60; // 1秒后结束
            await auction.createAuction(
                await myNFT.getAddress(),
                0,
                endTime,
                ethers.ZeroAddress
            );

            // User1出价1 ETH
            const bidAmount = ethers.parseEther("1");
            await auction.connect(user1)["bid(uint256)"](0, { value: bidAmount });

            // 增加区块时间，触发拍卖结束
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine", []);

            // 结束拍卖
            await expect(auction.endAuction(0))
                .to.emit(auction, "AuctionEnded")
                .withArgs(0, user1.address, bidAmount);

            // 检查NFT所有权
            expect(await myNFT.ownerOf(0)).to.equal(user1.address);
        });
    });
});