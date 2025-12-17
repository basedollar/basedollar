// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;


import "./AeroLPTokenPriceFeedBase.sol";
import "../Interfaces/IAeroGauge.sol";

contract AeroLPTokenPriceFeed is AeroLPTokenPriceFeedBase {
    constructor(
        address _borrowerOperationsAddress, 
        IAeroGauge _gauge,
        address _token0UsdOracleAddress,
        address _token1UsdOracleAddress,
        uint256 _token0UsdStalenessThreshold,
        uint256 _token1UsdStalenessThreshold,
        uint256 _poolStalenessThreshold
    )
        AeroLPTokenPriceFeedBase(
            _borrowerOperationsAddress, 
            _gauge, 
            _token0UsdOracleAddress, 
            _token1UsdOracleAddress, 
            _token0UsdStalenessThreshold, 
            _token1UsdStalenessThreshold, 
            _poolStalenessThreshold
        )
    {
        _fetchPricePrimary(false);

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    function fetchPrice() public returns (uint256, bool) {
        // If branch is live and the primary oracle setup has been working, try to use it
        if (priceSource == PriceSource.primary) return _fetchPricePrimary(false);

        // Otherwise if branch is shut down and already using the lastGoodPrice, continue with it
        assert(priceSource == PriceSource.lastGoodPrice);
        return (lastGoodPrice, false);
    }

    function fetchRedemptionPrice() external returns (uint256, bool) {
        return fetchPrice();
    }

    //  _fetchPricePrimary returns:
    // - The price
    // - A bool indicating whether a new oracle failure was detected in the call
    function _fetchPricePrimary(bool _isRedemption) internal virtual returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        // (uint256 price, bool isDown) = _getPrice();
        (uint256 token0Price, uint256 token1Price, bool isStale) = _getCumulativePrices();
        (uint256 token0OraclePrice, bool token0OracleIsDown) = _getOracleAnswer(token0UsdOracle);
        (uint256 token1OraclePrice, bool token1OracleIsDown) = _getOracleAnswer(token1UsdOracle);

        // If the token0 or token1 oracle is down, shut down and switch to the last good price
        if (token0OracleIsDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(token0UsdOracle.aggregator)), true);
        }
        if (token1OracleIsDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(token1UsdOracle.aggregator)), true);
        }
        // If the last blocktimestamp of cumulative prices from the pool is stale, shut down and switch to the last good price
        if (isStale) {
            return (_shutDownAndSwitchToLastGoodPrice(address(pool)), true);
        }

        bool withinPriceDeviationThreshold = 
            _withinDeviationThreshold(token0Price, token0OraclePrice, TOKEN_PRICE_DEVIATION_THRESHOLD)
            && _withinDeviationThreshold(token1Price, token1OraclePrice, TOKEN_PRICE_DEVIATION_THRESHOLD);

        // Otherwise, use the primary price calculation:
        if (_isRedemption && withinPriceDeviationThreshold) {
            // If it's a redemption and within 2%, take the max of (token0Price, token1Price) to prevent value leakage and convert to token0Price
            token1Price = LiquityMath._max(token1Price, token1OraclePrice);
            token0Price = LiquityMath._min(token0Price, token0OraclePrice);
        }else{
            // Take the minimum of (market, canonical) in order to mitigate against upward market price manipulation.
            token1Price = LiquityMath._min(token1Price, token1OraclePrice);
            token0Price = LiquityMath._max(token0Price, token0OraclePrice);
        }

        // Calculate the price of the pair
        uint256 price = token1Price * 1e18 / token0Price;

        lastGoodPrice = price;
        return (price, false);
    }
}   


