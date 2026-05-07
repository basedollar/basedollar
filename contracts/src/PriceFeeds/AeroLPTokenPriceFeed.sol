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

        _deployed = true;

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
        // If branch is live and the primary oracle setup has been working, try to use it
        if (priceSource == PriceSource.primary) return _fetchPricePrimary(true);

        // Otherwise if branch is shut down and already using the lastGoodPrice, continue with it
        assert(priceSource == PriceSource.lastGoodPrice);
        return (lastGoodPrice, false);
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
        ExchangeRate memory twapExchangeRate = _getTwapExchangeRates();
        if (twapExchangeRate.isDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(pool)), true);
        }

        if (twapExchangeRate.token1PerToken0 == 0 || twapExchangeRate.token0PerToken1 == 0) {
            return (_shutDownAndSwitchToLastGoodPrice(address(pool)), true);
        }

        PoolState memory poolState = _getPoolState();
        if (poolState.isDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(pool)), true);
        }

        // 3. Get LP token price using TWAP and Chainlink oracle prices
        return _getLPPrice(
            token0OraclePrice, 
            token1OraclePrice, 
            twapExchangeRate,
            poolState,
            _isRedemption
        );
    }

    /// @dev Get LP token price via TWAP and Oracle
    function _getLPPrice(
        uint256 token0OraclePrice,
        uint256 token1OraclePrice,
        ExchangeRate memory twapExchangeRate,
        PoolState memory poolState,
        bool _isRedemption
    ) internal returns (uint256 price, bool isDown) {
        // Derive market prices for each token from TWAP exchange rate
        // If 1 token0 = X token1 (TWAP), and token0 = $Y (Chainlink)
        // Then token1 market price = $Y / X
        uint256 token0MarketPrice = token1OraclePrice * 1e18 / twapExchangeRate.token0PerToken1;
        uint256 token1MarketPrice = token0OraclePrice * 1e18 / twapExchangeRate.token1PerToken0;

        // Calculate LP token price using TWAP market prices
        uint256 priceViaTWAP = _calculateLPTokenPrice(
            poolState.reserve0, 
            poolState.reserve1, 
            poolState.lpTotalSupply, 
            token0MarketPrice,
            token1MarketPrice
        );
        // Calculate LP token price using Chainlink oracle prices
        uint256 priceViaOracle = _calculateLPTokenPrice(
            poolState.reserve0, 
            poolState.reserve1, 
            poolState.lpTotalSupply, 
            token0OraclePrice, 
            token1OraclePrice
        );

        if (_isRedemption && _withinDeviationThreshold(priceViaTWAP, priceViaOracle, TOKEN_PRICE_DEVIATION_THRESHOLD)) {
            // For redemption within threshold: maximize LP value
            price = LiquityMath._max(priceViaTWAP, priceViaOracle);
        } else {
            // For borrows and when outside threshold
            // Assumes TWAP price manipulation and defaults to fair price via Chainlink oracle prices
            price = priceViaOracle;
        }

        lastGoodPrice = price;
        return (price, false);
    }
}


