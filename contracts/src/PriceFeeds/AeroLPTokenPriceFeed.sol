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
        uint256 _token1UsdStalenessThreshold
    )
        AeroLPTokenPriceFeedBase(
            _borrowerOperationsAddress, 
            _gauge, 
            _token0UsdOracleAddress, 
            _token1UsdOracleAddress, 
            _token0UsdStalenessThreshold, 
            _token1UsdStalenessThreshold
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
        return _fetchPricePrimary(true);
    }

    //  _fetchPricePrimary returns:
    // - The price (LP token price in USD, 18 decimals)
    // - A bool indicating whether a new oracle failure was detected in the call
    function _fetchPricePrimary(bool _isRedemption) internal virtual returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        
        // 1. Get Chainlink oracle prices (these are our "canonical" prices)
        (uint256 token0OraclePrice, bool token0OracleIsDown) = _getOracleAnswer(token0UsdOracle);
        if (token0OracleIsDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(token0UsdOracle.aggregator)), true);
        }
        
        (uint256 token1OraclePrice, bool token1OracleIsDown) = _getOracleAnswer(token1UsdOracle);
        if (token1OracleIsDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(token1UsdOracle.aggregator)), true);
        }
        
        // 2. Get TWAP exchange rate from pool (how many token1 for 1 token0)
        (uint256 twapToken1PerToken0, bool twapIsDown) = _getTwapExchangeRate();
        if (twapIsDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(pool)), true);
        }
        
        // 3. Derive "market" price for token1 from TWAP and select final prices
        // If 1 token0 = X token1 (TWAP), and token0 = $Y (Chainlink)
        // Then token1 market price = $Y / X
        // Note: token0's "market price" equals its oracle price (we used it as base)
        (uint256 token0Price, uint256 token1Price) = _selectPrices(
            token0OraclePrice,
            token1OraclePrice,
            twapToken1PerToken0,
            _isRedemption
        );
        
        // 4. Get pool state and calculate LP token price
        return _calculateAndReturnLPPrice(token0Price, token1Price);
    }
    
    /// @dev Select token prices based on TWAP validation and operation type
    function _selectPrices(
        uint256 token0OraclePrice,
        uint256 token1OraclePrice,
        uint256 twapToken1PerToken0,
        bool _isRedemption
    ) internal pure returns (uint256 token0Price, uint256 token1Price) {
        // Derive market price for token1 from TWAP
        uint256 token1MarketPrice = token0OraclePrice * 1e18 / twapToken1PerToken0;
        
        // Check if market price is within deviation threshold of oracle price
        // Note: token0 market price = oracle price, so it's always within threshold
        bool withinThreshold = _withinDeviationThreshold(
            token1MarketPrice, 
            token1OraclePrice, 
            TOKEN_PRICE_DEVIATION_THRESHOLD
        );
        
        if (_isRedemption && withinThreshold) {
            // For redemptions within threshold: maximize LP value to prevent value leakage
            // max token1 price, min token0 price -> higher LP value
            token1Price = LiquityMath._max(token1MarketPrice, token1OraclePrice);
            token0Price = token0OraclePrice; // min(oracle, oracle) = oracle
        } else {
            // For borrows (or redemptions outside threshold): minimize LP value
            // Protects against upward manipulation
            // min token1 price, max token0 price -> lower LP value
            token1Price = LiquityMath._min(token1MarketPrice, token1OraclePrice);
            token0Price = token0OraclePrice; // max(oracle, oracle) = oracle
        }
    }
    
    /// @dev Get pool state and calculate final LP token price
    function _calculateAndReturnLPPrice(
        uint256 token0Price, 
        uint256 token1Price
    ) internal returns (uint256, bool) {
        (uint256 reserve0, uint256 reserve1, uint256 lpTotalSupply, bool poolIsDown) = _getPoolState();
        if (poolIsDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(pool)), true);
        }
        
        uint256 price = _calculateLPTokenPrice(
            reserve0,
            reserve1,
            lpTotalSupply,
            token0Price,
            token1Price
        );
        
        lastGoodPrice = price;
        return (price, false);
    }
}


