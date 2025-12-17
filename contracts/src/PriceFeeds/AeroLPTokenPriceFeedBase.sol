// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "../Dependencies/Ownable.sol";
import "../Dependencies/AggregatorV3Interface.sol";
import "../BorrowerOperations.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/IAeroPool.sol";
import "../Interfaces/IAeroGauge.sol";
import "../Dependencies/Constants.sol";
import "../Dependencies/LiquityMath.sol";

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

    IBorrowerOperations public immutable borrowerOperations;

    IAeroPool public immutable pool;
    IGauge public immutable gauge;

    Oracle public token0UsdOracle;
    Oracle public token1UsdOracle;

    uint8 public token0PoolDecimals;
    uint8 public token1PoolDecimals;
    uint256 public poolStalenessThreshold;

    uint256 public constant TOKEN_PRICE_DEVIATION_THRESHOLD = 2e16; // 2%
    
    constructor(
        address _borrowerOperationsAddress, 
        IGauge _gauge, 
        address _token0UsdOracleAddress,
        address _token1UsdOracleAddress,
        uint256 _token0UsdStalenessThreshold,
        uint256 _token1UsdStalenessThreshold,
        uint256 _poolStalenessThreshold
    ) {
        borrowerOperations = IBorrowerOperations(_borrowerOperationsAddress);
        gauge = _gauge;
        pool = IPool(gauge.stakingToken());

        poolStalenessThreshold = _poolStalenessThreshold;
        token0PoolDecimals = pool.token0().decimals();
        token1PoolDecimals = pool.token1().decimals();

        token0UsdOracle.aggregator = AggregatorV3Interface(_token0UsdOracleAddress);
        token0UsdOracle.stalenessThreshold = _token0UsdStalenessThreshold;
        token0UsdOracle.decimals = token0UsdOracle.aggregator.decimals();

        token1UsdOracle.aggregator = AggregatorV3Interface(_token1UsdOracleAddress);
        token1UsdOracle.stalenessThreshold = _token1UsdStalenessThreshold;
        token1UsdOracle.decimals = token1UsdOracle.aggregator.decimals();
    }

    function _getCumulativePrices() internal view returns (uint256 token0Price, uint256 token1Price, bool isStale) {
        uint256 gasBefore = gasleft();

        // Try to get the price from the pool
        try pool.currentCumulativePrices() returns (uint256 token0CumulativePrice, uint256 token1CumulativePrice, uint256 blockTimestampLast) {
            token0Price = _scaleCumulativePriceTo18decimals(token0CumulativePrice, token0PoolDecimals);
            token1Price = _scaleCumulativePriceTo18decimals(token1CumulativePrice, token1PoolDecimals);
            isStale = block.timestamp - blockTimestampLast > poolStalenessThreshold;
        } catch {
            // Require that enough gas was provided to prevent an OOG revert in the external call
            // causing a shutdown. Instead, just revert. Slightly conservative, as it includes gas used
            // in the check itself.
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();

            // If the call to the pool reverts, return a zero price and true for isDown
            return (0, 0, true);
        }
    }

    function _shutDownAndSwitchToLastGoodPrice(address _failedOracleAddr) internal returns (uint256) {
        // Shut down the branch
        borrowerOperations.shutdownFromOracleFailure();

        priceSource = PriceSource.lastGoodPrice;

        emit ShutDownFromOracleFailure(_failedOracleAddr);
        return lastGoodPrice;
    }

    function _isValidCumulativePriceResponse(uint256 _price0, uint256 _price1, uint256 _lastTimestamp)
        internal
        view
        returns (bool)
    {
        return block.timestamp - _lastTimestamp < poolStalenessThreshold
            && _price0 > 0 && _price1 > 0;
    }

    function _getOracleAnswer(Oracle memory _oracle) internal view returns (uint256, bool) {
        ChainlinkResponse memory chainlinkResponse = _getCurrentChainlinkResponse(_oracle.aggregator);

        uint256 scaledPrice;
        bool oracleIsDown;
        // Check oracle is serving an up-to-date and sensible price. If not, shut down this collateral branch.
        if (!_isValidChainlinkPrice(chainlinkResponse, _oracle.stalenessThreshold)) {
            oracleIsDown = true;
        } else {
            scaledPrice = _scaleChainlinkPriceTo18decimals(chainlinkResponse.answer, _oracle.decimals);
        }

        return (scaledPrice, oracleIsDown);
    }

    function _getCurrentChainlinkResponse(AggregatorV3Interface _aggregator)
        internal
        view
        returns (ChainlinkResponse memory chainlinkResponse)
    {
        uint256 gasBefore = gasleft();

        // Try to get latest price data:
        try _aggregator.latestRoundData() returns (
            uint80 roundId, int256 answer, uint256, /* startedAt */ uint256 updatedAt, uint80 /* answeredInRound */
        ) {
            // If call to Chainlink succeeds, return the response and success = true
            chainlinkResponse.roundId = roundId;
            chainlinkResponse.answer = answer;
            chainlinkResponse.timestamp = updatedAt;
            chainlinkResponse.success = true;

            return chainlinkResponse;
        } catch {
            // Require that enough gas was provided to prevent an OOG revert in the call to Chainlink
            // causing a shutdown. Instead, just revert. Slightly conservative, as it includes gas used
            // in the check itself.
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();

            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }
    }

    // False if:
    // - Call to Chainlink aggregator reverts
    // - price is too stale, i.e. older than the oracle's staleness threshold
    // - Price answer is 0 or negative
    function _isValidChainlinkPrice(ChainlinkResponse memory chainlinkResponse, uint256 _stalenessThreshold)
        internal
        view
        returns (bool)
    {
        return chainlinkResponse.success && block.timestamp - chainlinkResponse.timestamp < _stalenessThreshold
            && chainlinkResponse.answer > 0;
    }

    function _scaleCumulativePriceTo18decimals(uint256 _price, uint256 _decimals) internal pure returns (uint256) {
        return _price * 10 ** (18 - _decimals);
    }

    // Trust assumption: Chainlink won't change the decimal precision on any feed used in v2 after deployment
    function _scaleChainlinkPriceTo18decimals(int256 _price, uint256 _decimals) internal pure returns (uint256) {
        // Scale an int price to a uint with 18 decimals
        return uint256(_price) * 10 ** (18 - _decimals);
    }

    function _withinDeviationThreshold(uint256 _priceToCheck, uint256 _referencePrice, uint256 _deviationThreshold)
        internal
        pure
        returns (bool)
    {
        // Calculate the price deviation of the oracle market price relative to the canonical price
        uint256 max = _referencePrice * (DECIMAL_PRECISION + _deviationThreshold) / 1e18;
        uint256 min = _referencePrice * (DECIMAL_PRECISION - _deviationThreshold) / 1e18;

        return _priceToCheck >= min && _priceToCheck <= max;
    }
}
