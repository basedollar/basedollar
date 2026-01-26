// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "src/PriceFeeds/AeroLPTokenPriceFeed.sol";

contract AeroLPTokenPriceFeedTester is AeroLPTokenPriceFeed {
    constructor(
        address borrowerOperations_,
        IAeroGauge gauge_,
        address token0UsdOracle_,
        address token1UsdOracle_,
        uint256 token0UsdStalenessThreshold_,
        uint256 token1UsdStalenessThreshold_,
        uint256 poolStalenessThreshold_
    )
        AeroLPTokenPriceFeed(
            borrowerOperations_,
            gauge_,
            token0UsdOracle_,
            token1UsdOracle_,
            token0UsdStalenessThreshold_,
            token1UsdStalenessThreshold_,
            poolStalenessThreshold_
        )
    {}

    function i_getCumulativePrices() external view returns (uint256 token0Price, uint256 token1Price, bool isStale) {
        return _getCumulativePrices();
    }
}