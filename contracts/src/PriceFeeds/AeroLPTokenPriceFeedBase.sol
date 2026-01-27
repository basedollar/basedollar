// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../Dependencies/AggregatorV3Interface.sol";
import "../BorrowerOperations.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/IAeroPool.sol";
import "../Interfaces/IAeroGauge.sol";
import "../Dependencies/Constants.sol";
import "../Dependencies/LiquityMath.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// import "forge-std/console2.sol";

abstract contract AeroLPTokenPriceFeedBase is IPriceFeed {
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
    IAeroGauge public immutable gauge;

    Oracle public token0UsdOracle;
    Oracle public token1UsdOracle;

    uint8 public token0PoolDecimals;
    uint8 public token1PoolDecimals;

    uint256 public constant TOKEN_PRICE_DEVIATION_THRESHOLD = 2e16; // 2%
    uint256 public constant TWAP_GRANULARITY = 8; // 8 periods × 30 min = 4 hours
    
    constructor(
        address _borrowerOperationsAddress, 
        IAeroGauge _gauge, 
        address _token0UsdOracleAddress,
        address _token1UsdOracleAddress,
        uint256 _token0UsdStalenessThreshold,
        uint256 _token1UsdStalenessThreshold
    ) {
        borrowerOperations = IBorrowerOperations(_borrowerOperationsAddress);
        gauge = _gauge;
        pool = IAeroPool(gauge.stakingToken());

        token0PoolDecimals = IERC20Metadata(pool.token0()).decimals();
        token1PoolDecimals = IERC20Metadata(pool.token1()).decimals();

        token0UsdOracle.aggregator = AggregatorV3Interface(_token0UsdOracleAddress);
        token0UsdOracle.stalenessThreshold = _token0UsdStalenessThreshold;
        token0UsdOracle.decimals = token0UsdOracle.aggregator.decimals();

        token1UsdOracle.aggregator = AggregatorV3Interface(_token1UsdOracleAddress);
        token1UsdOracle.stalenessThreshold = _token1UsdStalenessThreshold;
        token1UsdOracle.decimals = token1UsdOracle.aggregator.decimals();
    }

    /// @notice Get TWAP-based exchange rate: how many token1 for 1 token0
    /// @return token1PerToken0 Exchange rate scaled to 18 decimals
    /// @return isDown True if the call failed
    function _getTwapExchangeRate() internal view returns (uint256 token1PerToken0, bool isDown) {
        uint256 gasBefore = gasleft();
        
        try pool.quote(pool.token0(), 10 ** token0PoolDecimals, TWAP_GRANULARITY) 
            returns (uint256 amountOut) 
        {
            // amountOut is in token1 decimals - scale to 18
            token1PerToken0 = amountOut * 10 ** (18 - token1PoolDecimals);
            isDown = false;
        } catch {
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();
            return (0, true);
        }
    }

    /// @notice Get pool reserves and LP total supply
    /// @return reserve0 Amount of token0 in pool
    /// @return reserve1 Amount of token1 in pool
    /// @return lpTotalSupply Total LP tokens outstanding
    /// @return isDown True if calls failed or total supply is zero
    function _getPoolState() internal view returns (
        uint256 reserve0, 
        uint256 reserve1, 
        uint256 lpTotalSupply,
        bool isDown
    ) {
        uint256 gasBefore = gasleft();
        
        try pool.getReserves() returns (uint256 r0, uint256 r1, uint256) {
            reserve0 = r0;
            reserve1 = r1;
        } catch {
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();
            return (0, 0, 0, true);
        }
        
        gasBefore = gasleft();
        try IERC20(address(pool)).totalSupply() returns (uint256 supply) {
            lpTotalSupply = supply;
            isDown = (supply == 0);
        } catch {
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();
            return (0, 0, 0, true);
        }
    }

    /// @notice Calculate LP token price given reserves, supply, and token prices
    /// @param reserve0 Amount of token0 in pool
    /// @param reserve1 Amount of token1 in pool  
    /// @param lpTotalSupply Total LP tokens outstanding
    /// @param token0Price USD price of token0 (18 decimals)
    /// @param token1Price USD price of token1 (18 decimals)
    /// @return LP token price in USD (18 decimals)
    function _calculateLPTokenPrice(
        uint256 reserve0,
        uint256 reserve1,
        uint256 lpTotalSupply,
        uint256 token0Price,
        uint256 token1Price
    ) internal view returns (uint256) {
        // Scale reserves to 18 decimals
        uint256 reserve0Scaled = reserve0 * 10 ** (18 - token0PoolDecimals);
        uint256 reserve1Scaled = reserve1 * 10 ** (18 - token1PoolDecimals);
        
        // Total value in USD = (reserve0 * price0) + (reserve1 * price1)
        // Both reserves and prices are 18 decimals, so divide by 1e18
        uint256 totalValueUsd = (reserve0Scaled * token0Price / 1e18) 
                              + (reserve1Scaled * token1Price / 1e18);
        
        // LP token price = total value / total supply
        // totalValueUsd is 18 decimals, lpTotalSupply is 18 decimals
        // Result is 18 decimals
        return totalValueUsd * 1e18 / lpTotalSupply;
    }

    function _shutDownAndSwitchToLastGoodPrice(address _failedOracleAddr) internal returns (uint256) {
        // Shut down the branch
        borrowerOperations.shutdownFromOracleFailure();

        priceSource = PriceSource.lastGoodPrice;

        emit ShutDownFromOracleFailure(_failedOracleAddr);
        return lastGoodPrice;
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
