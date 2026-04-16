// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.24;

import "../Dependencies/AggregatorV3Interface.sol";
import "../BorrowerOperations.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/IAeroPool.sol";
import "../Interfaces/IAeroGauge.sol";
import {DECIMAL_PRECISION} from "../Dependencies/Constants.sol";
import "../Dependencies/LiquityMath.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Dependencies/FixedPointMathLib.sol";

// import "forge-std/console2.sol";

abstract contract AeroLPTokenPriceFeedBase is IPriceFeed {
    // Determines where the PriceFeed sources data from. Possible states:
    // - primary: Uses the primary price calculation, which depends on the specific feed
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

    struct ExchangeRate {
        uint256 token1PerToken0;
        uint256 token0PerToken1;
        bool isDown;
    }

    error InsufficientGasForExternalCall();

    event ShutDownFromOracleFailure(address _failedOracleAddr);

    IBorrowerOperations public immutable borrowerOperations;

    IAeroPool public immutable pool;
    IAeroGauge public immutable gauge;

    bool public immutable isStablePair;

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
        require(address(_gauge) != address(0), "Gauge is 0 address");

        pool = IAeroPool(gauge.stakingToken());
        isStablePair = pool.stable();

        token0PoolDecimals = IERC20Metadata(pool.token0()).decimals();
        token1PoolDecimals = IERC20Metadata(pool.token1()).decimals();

        token0UsdOracle.aggregator = AggregatorV3Interface(_token0UsdOracleAddress);
        token0UsdOracle.stalenessThreshold = _token0UsdStalenessThreshold;
        token0UsdOracle.decimals = token0UsdOracle.aggregator.decimals();

        token1UsdOracle.aggregator = AggregatorV3Interface(_token1UsdOracleAddress);
        token1UsdOracle.stalenessThreshold = _token1UsdStalenessThreshold;
        token1UsdOracle.decimals = token1UsdOracle.aggregator.decimals();

        require(token0UsdOracle.decimals == token1UsdOracle.decimals, "Token0 and token1 decimals do not match");
    }

    /// @notice Get TWAP-based exchange rate: how many token1 for 1 token0
    /// @return exchangeRate Exchange rate scaled to 18 decimals
    function _getTwapExchangeRates() internal view returns (ExchangeRate memory exchangeRate) {
        uint256 gasBefore = gasleft();

        address token0 = pool.token0();
        address token1 = pool.token1();
        
        try pool.quote(token0, 10 ** token0PoolDecimals, TWAP_GRANULARITY) 
            returns (uint256 amountOut) 
        {
            // amountOut is in token1 decimals - scale to 18
            exchangeRate.token1PerToken0 = amountOut * 10 ** (18 - token1PoolDecimals);
        } catch {
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();
            exchangeRate.isDown = true;
            return exchangeRate;
        }

        gasBefore = gasleft();
        try pool.quote(token1, 10 ** token1PoolDecimals, TWAP_GRANULARITY) 
            returns (uint256 amountOut) 
        {
            // amountOut is in token0 decimals - scale to 18
            exchangeRate.token0PerToken1 = amountOut * 10 ** (18 - token0PoolDecimals);
        } catch {
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();
            exchangeRate.isDown = true;
            return exchangeRate;
        }

        exchangeRate.isDown = false;
        return exchangeRate;
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
    /// This is used to calculate the fair price based on fair asset reserves of the pool.
    /// Code implementation based on Pessimistic Velodrome LP Oracle from dudesahn: https://github.com/dudesahn/PessimisticVelodromeLPOracle.
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

        if (isStablePair) {
            return _calculate_stable_lp_token_price(lpTotalSupply, token0Price, token1Price, reserve0Scaled, reserve1Scaled);
        } else {
            return _calculate_volatile_lp_token_price(lpTotalSupply, token0Price, token1Price, reserve0Scaled, reserve1Scaled);
        }
    }

    /// @notice Calculate volatile LP token price via fair asset reserves
    /// @param total_supply Total supply of LP tokens
    /// @param price0 Price of token0 in 18 decimals
    /// @param price1 Price of token1 in 18 decimals
    /// @param reserve0 Reserve of token0 in 18 decimals
    /// @param reserve1 Reserve of token1 in 18 decimals
    /// @return LP token price in 18 decimals
    function _calculate_volatile_lp_token_price(
        uint256 total_supply,
        uint256 price0,
        uint256 price1,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256) {
        uint256 k = FixedPointMathLib.sqrt(reserve0 * reserve1); // xy = k, p0r0' = p1r1', this is in 1e18
        uint256 p = FixedPointMathLib.sqrt(price0 * 1e16 * price1); // boost this to 1e16 to give us more precision

        // we want k and total supply to have same number of decimals so price has 18 decimals
        return (2 * p * k) / (1e8 * total_supply);
    }

    /// @notice Calculate stable LP token price via fair asset reserves
    /// @dev Solves for fair reserves of stables where the curve is x^3 * y + y^3 * x = k. 
    ///      Fair reserves math formula author: ksyao2002
    ///      Modified from dudesahn/PessimisticVelodromeLPOracle: https://github.com/dudesahn/PessimisticVelodromeLPOracle/blob/575ac4cd226fae22a69bddb945fb45700c68ee83/contracts/PessimisticVelodromeLPOracle.sol#L459-L498
    /// @param total_supply Total LP token supply (same decimals as pool LP token)
    /// @param price0 USD price of token0 (18 decimals)
    /// @param price1 USD price of token1 (18 decimals)
    /// @param reserve0 Pool reserve of token0 (18 decimals)
    /// @param reserve1 Pool reserve of token1 (18 decimals)
    /// @return USD price of one LP token (18 decimals)
    function _calculate_stable_lp_token_price(
        uint256 total_supply,
        uint256 price0, // must be in 18 decimals
        uint256 price1, // must be in 18 decimals
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256) {
        uint256 k = _getK(reserve0, reserve1);
        //fair_reserves = ( (k * (price0 ** 3) * (price1 ** 3)) )^(1/4) / ((price0 ** 2) + (price1 ** 2));
        uint256 a = FixedPointMathLib.rpow(price0, 3, 1e18); //keep same decimals as chainlink
        uint256 b = FixedPointMathLib.rpow(price1, 3, 1e18);
        uint256 c = FixedPointMathLib.rpow(price0, 2, 1e18);
        uint256 d = FixedPointMathLib.rpow(price1, 2, 1e18);

        uint256 p0 = k * FixedPointMathLib.mulWadDown(a, b); //2*18 decimals

        uint256 fair = p0 / (c + d); // number of decimals is 18

        // each sqrt divides the num decimals by 2. So need to replenish the decimals midway through with another 1e18
        uint256 frth_fair = FixedPointMathLib.sqrt(
            FixedPointMathLib.sqrt(fair * 1e18) * 1e18
        ); // number of decimals is 18

        return 2 * ((frth_fair * 1e18) / total_supply);
    }

    /// @notice Calculates K for the stable invariant x^3 * y + y^3 * x = k
    /// @param x Reserve (or price-scaled reserve) of first asset, 18 decimals
    /// @param y Reserve of second asset, 18 decimals
    /// @return k Invariant term (18 decimals)
    function _getK(uint256 x, uint256 y) internal pure returns (uint256) {
        //x, n, scalar
        uint256 x_cubed = FixedPointMathLib.rpow(x, 3, 1e18);
        uint256 newX = FixedPointMathLib.mulWadDown(x_cubed, y);
        uint256 y_cubed = FixedPointMathLib.rpow(y, 3, 1e18);
        uint256 newY = FixedPointMathLib.mulWadDown(y_cubed, x);

        return newX + newY; //18 decimals
    }

    /// @notice Shut down the collateral branch on oracle failure and pin this feed to `lastGoodPrice`
    /// @param _failedOracleAddr Oracle aggregator that failed validation (emitted for ops)
    /// @return The stored `lastGoodPrice` now used as the feed source
    function _shutDownAndSwitchToLastGoodPrice(address _failedOracleAddr) internal returns (uint256) {
        // Shut down the branch
        borrowerOperations.shutdownFromOracleFailure();

        priceSource = PriceSource.lastGoodPrice;

        emit ShutDownFromOracleFailure(_failedOracleAddr);
        return lastGoodPrice;
    }

    /// @notice Read and validate a Chainlink USD feed configured in `Oracle`
    /// @param _oracle Aggregator, staleness threshold, and reported decimals
    /// @return scaledPrice Answer scaled to 18 decimals when the round is valid; zero if invalid
    /// @return oracleIsDown True when the round fails freshness, positivity, or the aggregator call
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

    /// @notice Wrap `latestRoundData` with try/catch and a gas guard
    /// @dev On revert, returns `success = false` unless remaining gas is at most 1/64 of pre-call gas,
    ///      in which case `InsufficientGasForExternalCall` is thrown to avoid misclassifying OOG as a bad oracle.
    /// @param _aggregator Chainlink AggregatorV3Interface
    /// @return chainlinkResponse Parsed round id, answer, timestamp, and success flag
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

    /// @notice Whether a Chainlink round is usable for pricing
    /// @dev False if:
    /// - Call to Chainlink aggregator reverts
    /// - price is too stale, i.e. older than the oracle's staleness threshold
    /// - Price answer is 0 or negative
    /// @param chainlinkResponse Parsed response from `_getCurrentChainlinkResponse`
    /// @param _stalenessThreshold Max allowed `block.timestamp - updatedAt` (seconds)
    /// @return True if the round is valid
    function _isValidChainlinkPrice(ChainlinkResponse memory chainlinkResponse, uint256 _stalenessThreshold)
        internal
        view
        returns (bool)
    {
        return chainlinkResponse.success && block.timestamp - chainlinkResponse.timestamp < _stalenessThreshold
            && chainlinkResponse.answer > 0;
    }

    /// @notice Scale a Chainlink answer to 18-decimal uint256
    /// @dev Trust assumption: Chainlink won't change the decimal precision on any feed used in v2 after deployment
    /// @param _price Signed integer answer from Chainlink
    /// @param _decimals Reported feed decimals
    /// @return Unsigned price with 18 decimals
    function _scaleChainlinkPriceTo18decimals(int256 _price, uint256 _decimals) internal pure returns (uint256) {
        // Scale an int price to a uint with 18 decimals
        return uint256(_price) * 10 ** (18 - _decimals);
    }

    /// @notice Check whether `_priceToCheck` lies within ±`_deviationThreshold` of `_referencePrice`
    /// @param _priceToCheck Price to test (18 decimals)
    /// @param _referencePrice Canonical reference price (18 decimals)
    /// @param _deviationThreshold Max relative deviation as a WAD fraction of `DECIMAL_PRECISION` (e.g. 2e16 for 2%)
    /// @return True if `_priceToCheck` is in `[reference * (1 - δ), reference * (1 + δ)]`
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
