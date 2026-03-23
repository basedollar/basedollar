// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./MainnetPriceFeedBase.sol";


contract cbETHPriceFeed is MainnetPriceFeedBase {
     constructor(
        address _borrowerOperationsAddress,
        address _ethUsdOracleAddress,
        address _cbEthEthOracleAddress,
        uint256 _ethUsdStalenessThreshold,
        uint256 _cbEthEthStalenessThreshold
    ) MainnetPriceFeedBase(_ethUsdOracleAddress, _ethUsdStalenessThreshold, _borrowerOperationsAddress) {
        // Store cbETH-ETH oracle
        cbEthEthOracle.aggregator = AggregatorV3Interface(_cbEthEthOracleAddress);
        cbEthEthOracle.stalenessThreshold = _cbEthEthStalenessThreshold;
        cbEthEthOracle.decimals = cbEthEthOracle.aggregator.decimals();
        
        require(cbEthEthOracle.decimals == 8, "cbETHPriceFeed: cbETH-ETH oracle must have 8 decimals");

        _fetchPricePrimary();

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    Oracle public cbEthEthOracle;

    function fetchRedemptionPrice() public returns (uint256, bool) {
        return fetchPrice();
    }

    function fetchPrice() public returns (uint256, bool) {
        // If branch is live and the primary oracle setup has been working, try to use it
        if (priceSource == PriceSource.primary) return _fetchPricePrimary();

        // Otherwise if branch is shut down and already using the lastGoodPrice, continue with it
        assert(priceSource == PriceSource.lastGoodPrice);
        return (lastGoodPrice, false);
    }
    
    //  _fetchPricePrimary returns:
    // - The price
    // - A bool indicating whether a new oracle failure was detected in the call
    function _fetchPricePrimary() internal returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        (uint256 cbEthPrice, bool cbEthOracleDown) = _getOracleAnswer(cbEthEthOracle);
        (uint256 ethUsdPrice, bool ethUsdOracleDown) = _getOracleAnswer(ethUsdOracle);

        // If the ETH-USD Chainlink response was invalid in this transaction, return the last good cbETH-USD price calculated
        if (cbEthOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(cbEthEthOracle.aggregator)), true);
        if (ethUsdOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(ethUsdOracle.aggregator)), true);

        // Calculate the canonical LST-USD price: USD_per_LST = USD_per_ETH * underlying_per_LST
        uint256 cbEthUsdPrice = ethUsdPrice * cbEthPrice / 1e18;

        lastGoodPrice = cbEthUsdPrice;
        return (cbEthUsdPrice, false);
    }
}   


