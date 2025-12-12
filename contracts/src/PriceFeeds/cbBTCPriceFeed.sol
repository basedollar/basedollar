// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;
 
import "./CompositePriceFeed.sol";


contract cbBTCPriceFeed is CompositePriceFeed {
    Oracle public btcUsdOracle;
    Oracle public cbBTCUsdOracle;

    uint256 public constant BTC_cbBTC_DEVIATION_THRESHOLD = 2e16; // 2%

    constructor(
        address _borrowerOperationsAddress, 
        address _cbBTCUsdOracleAddress, 
        address _btcUsdOracleAddress,
        uint256 _cbBTCUsdStalenessThreshold,
        uint256 _btcUsdStalenessThreshold
    ) CompositePriceFeed(_cbBTCUsdOracleAddress, _btcUsdOracleAddress, _cbBTCUsdStalenessThreshold, _borrowerOperationsAddress)
    {
        // Store BTC-USD oracle
        btcUsdOracle.aggregator = AggregatorV3Interface(_btcUsdOracleAddress);
        btcUsdOracle.stalenessThreshold = _btcUsdStalenessThreshold;
        btcUsdOracle.decimals = btcUsdOracle.aggregator.decimals();

        // Store cbBTC-USD oracle
        cbBTCUsdOracle.aggregator = AggregatorV3Interface(_cbBTCUsdOracleAddress);
        cbBTCUsdOracle.stalenessThreshold = _cbBTCUsdStalenessThreshold;
        cbBTCUsdOracle.decimals = cbBTCUsdOracle.aggregator.decimals();

        _fetchPricePrimary(false);

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    function _fetchPricePrimary(bool _isRedemption) internal override returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        (uint256 cbbtcUsdPrice, bool cbbtcUsdOracleDown) = _getOracleAnswer(cbBTCUsdOracle);
        (uint256 btcUsdPrice, bool btcOracleDown) = _getOracleAnswer(btcUsdOracle);
        
        // cbBTC oracle is down or invalid answer
        if (cbbtcUsdOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(cbBTCUsdOracle.aggregator)), true);
        }

        // BTC oracle is down or invalid answer
        if (btcOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(btcUsdOracle.aggregator)), true);
        }

        // Otherwise, use the primary price calculation:
        if (_isRedemption && _withinDeviationThreshold(cbbtcUsdPrice, btcUsdPrice, BTC_cbBTC_DEVIATION_THRESHOLD)) {
            // If it's a redemption and within 2%, take the max of (cbBTC-USD, BTC-USD) to prevent value leakage and convert to cbBTC-USD
            cbbtcUsdPrice = LiquityMath._max(cbbtcUsdPrice, btcUsdPrice);
        }else{
            // Take the minimum of (market, canonical) in order to mitigate against upward market price manipulation.
            cbbtcUsdPrice = LiquityMath._min(cbbtcUsdPrice, btcUsdPrice);
        }

        // Otherwise, just use cbBTC-USD price: USD_per_cbBTC.
        lastGoodPrice = cbbtcUsdPrice;
        return (cbbtcUsdPrice, false);
    }

    function _getCanonicalRate() internal view override returns (uint256, bool) {
        return (1 * 10 ** 18, false); // always return 1 BTC per cbBTC by default.
    }
}   


