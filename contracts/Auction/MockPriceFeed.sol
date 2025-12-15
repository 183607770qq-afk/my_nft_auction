// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockPriceFeed is AggregatorV3Interface {
    int256 private _price; // 存储价格
    uint8 public override decimals;

    constructor(int256 _initialPrice, uint8 _decimals) {
        _price = _initialPrice;
        decimals = _decimals;
    }

    // 实现接口的description函数
    function description() external pure override returns (string memory) {
        return "Mock ETH/USD Price Feed";
    }

    // 实现接口的getRoundData函数
    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, block.timestamp, block.timestamp, _roundId);
    }

    // 实现接口的latestRoundData函数（核心价格返回逻辑）
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (1, _price, block.timestamp, block.timestamp, 1);
    }

    // 实现接口的version函数
    function version() external pure override returns (uint256) {
        return 1;
    }

    // 修改价格的函数（本地测试用）
    function setPrice(int256 _newPrice) external {
        _price = _newPrice;
    }
}