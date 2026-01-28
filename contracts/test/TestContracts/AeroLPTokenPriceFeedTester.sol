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
        uint256 token1UsdStalenessThreshold_
    )
        AeroLPTokenPriceFeed(
            borrowerOperations_,
            gauge_,
            token0UsdOracle_,
            token1UsdOracle_,
            token0UsdStalenessThreshold_,
            token1UsdStalenessThreshold_
        )
    {}

    function i_getTwapExchangeRates() external view returns (ExchangeRate memory exchangeRate) {
        return _getTwapExchangeRates();
    }
    
    function i_getPoolState() external view returns (
        uint256 reserve0, 
        uint256 reserve1, 
        uint256 lpTotalSupply,
        bool isDown
    ) {
        return _getPoolState();
    }
    
    function i_calculateLPTokenPrice(
        uint256 reserve0,
        uint256 reserve1,
        uint256 lpTotalSupply,
        uint256 token0Price,
        uint256 token1Price
    ) external view returns (uint256) {
        return _calculateLPTokenPrice(reserve0, reserve1, lpTotalSupply, token0Price, token1Price);
    }
}
