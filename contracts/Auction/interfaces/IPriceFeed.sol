// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IPriceFeed
 * @dev Chainlink价格预言机的接口，用于获取资产的美元价格
 */
interface IPriceFeed {
    function latestAnswer() external view returns (int256);
}