// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "src/Dependencies/AggregatorV3Interface.sol";
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

    function i_getOracleAnswer(Oracle memory o) external view returns (uint256 scaledPrice, bool oracleIsDown) {
        return _getOracleAnswer(o);
    }

    function i_getCurrentChainlinkResponse(AggregatorV3Interface agg)
        external
        view
        returns (ChainlinkResponse memory chainlinkResponse)
    {
        return _getCurrentChainlinkResponse(agg);
    }

    function i_isValidChainlinkPrice(ChainlinkResponse memory r, uint256 staleness)
        external
        view
        returns (bool)
    {
        return _isValidChainlinkPrice(r, staleness);
    }

    function i_scaleChainlinkPriceTo18decimals(int256 price, uint256 decimals) external pure returns (uint256) {
        return _scaleChainlinkPriceTo18decimals(price, decimals);
    }

    function i_withinDeviationThreshold(uint256 priceToCheck, uint256 referencePrice, uint256 deviationThreshold)
        external
        pure
        returns (bool)
    {
        return _withinDeviationThreshold(priceToCheck, referencePrice, deviationThreshold);
    }
}
