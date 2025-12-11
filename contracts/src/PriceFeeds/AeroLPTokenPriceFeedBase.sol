// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "../Dependencies/Ownable.sol";
import "../Dependencies/AggregatorV3Interface.sol";
import "../BorrowerOperations.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/IAeroPool.sol";
import "../Interfaces/IAeroGauge.sol";

// import "forge-std/console2.sol";

abstract contract AeroLPTokenPriceFeedBase is Ownable, IPriceFeed {
    // Determines where the PriceFeed sources data from. Possible states:
    // - primary: Uses the primary price calcuation, which depends on the specific feed
    // - lastGoodPrice: the last good price recorded by this PriceFeed.

     enum PriceSource {
        primary,
        TokenUSDxCanonical,
        lastGoodPrice
    }

    PriceSource public priceSource;

    // Last good price tracker for the derived USD price
    uint256 public lastGoodPrice;

    struct Oracle {
        AggregatorV3Interface aggregator;
        uint256 stalenessThreshold;
        uint8 decimals;
    }

    struct ChainlinkResponse {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        bool success;
    }

    error InsufficientGasForExternalCall();

    event ShutDownFromOracleFailure(address _failedOracleAddr);

    Oracle public tokenUsdOracle;

    IBorrowerOperations immutable borrowerOperations;

    IPool public immutable pool;
    IGauge public immutable gauge;
    uint256 public immutable stalenessThreshold;
    uint8 public immutable decimals;
    
    constructor(address _borrowerOperationsAddress, IGauge _gauge, uint256 _stalenessThreshold) {
        borrowerOperations = IBorrowerOperations(_borrowerOperationsAddress);
        gauge = _gauge;
        pool = IPool(gauge.stakingToken());
        stalenessThreshold = _stalenessThreshold;
        decimals = pool.token0().decimals();
    }

    function _getPrice() internal view returns (uint256 price, bool isDown) {
        uint256 gasBefore = gasleft();

        // Try to get the price from the pool
        try pool.getReserves() returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast) {
            price = (reserve0 * decimals) / reserve1;
            isDown = !_isValidPrice(price, blockTimestampLast);
        } catch {
            // Require that enough gas was provided to prevent an OOG revert in the external call
            // causing a shutdown. Instead, just revert. Slightly conservative, as it includes gas used
            // in the check itself.
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();

            // If the call to the pool reverts, return a zero price and true for isDown
            return (0, true);
        }
    }

    function _shutDownAndSwitchToLastGoodPrice(address _failedOracleAddr) internal returns (uint256) {
        // Shut down the branch
        borrowerOperations.shutdownFromOracleFailure();

        priceSource = PriceSource.lastGoodPrice;

        emit ShutDownFromOracleFailure(_failedOracleAddr);
        return lastGoodPrice;
    }

    function _isValidPrice(uint256 _price, uint256 _lastTimestamp)
        internal
        view
        returns (bool)
    {
        return block.timestamp - _lastTimestamp < stalenessThreshold
            && _price > 0;
    }

    // Trust assumption: Chainlink won't change the decimal precision on any feed used in v2 after deployment
    function _scaleChainlinkPriceTo18decimals(int256 _price, uint256 _decimals) internal pure returns (uint256) {
        // Scale an int price to a uint with 18 decimals
        return uint256(_price) * 10 ** (18 - _decimals);
    }
}
