// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;


import "./AeroLPTokenPriceFeedBase.sol";

contract AeroLPTokenPriceFeed is AeroLPTokenPriceFeedBase {
   constructor(address _borrowerOperationsAddress, IGauge _gauge, uint256 _stalenessThreshold)
        AeroLPTokenPriceFeedBase(_borrowerOperationsAddress, _gauge, _stalenessThreshold)
    {
        _fetchPricePrimary();

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    function fetchPrice() public returns (uint256, bool) {
        // If branch is live and the primary oracle setup has been working, try to use it
        if (priceSource == PriceSource.primary) return _fetchPricePrimary();

        // Otherwise if branch is shut down and already using the lastGoodPrice, continue with it
        assert(priceSource == PriceSource.lastGoodPrice);
        return (lastGoodPrice, false);
    }

    function fetchRedemptionPrice() external returns (uint256, bool) {
        // Use same price for redemption as all other ops in SAGA branch
        return fetchPrice();
    }

    //  _fetchPricePrimary returns:
    // - The price
    // - A bool indicating whether a new oracle failure was detected in the call
    function _fetchPricePrimary(bool /* _isRedemption */ ) internal virtual returns (uint256, bool) {
        return _fetchPricePrimary();
    }

    function _fetchPricePrimary() internal returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        (uint256 price, bool isDown) = _getPrice();

        // If the yETH-USD Chainlink response was invalid in this transaction, return the last good yETH-USD price calculated
        if (isDown) return (_shutDownAndSwitchToLastGoodPrice(address(pool)), true);

        lastGoodPrice = price;
        return (price, false);
    }
}   


