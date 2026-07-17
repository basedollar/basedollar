// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import "src/Dependencies/AggregatorV3Interface.sol";
import "src/Dependencies/Constants.sol";
import "src/Interfaces/IAeroGauge.sol";
import "src/PriceFeeds/AeroLPTokenPriceFeed.sol";
import "src/PriceFeeds/AeroLPTokenPriceFeedBase.sol";

import "./TestContracts/ChainlinkOracleMock.sol";
import "./TestContracts/AeroGaugeMock.sol";
import "./TestContracts/AeroLPTokenPriceFeedTester.sol";

contract ERC20DecimalsMock is ERC20 {
    uint8 internal immutable _customDecimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _customDecimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _customDecimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BorrowerOperationsMock {
    function shutdownFromOracleFailure() external {}
}

contract AeroLPTokenPriceFeedTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ERC20DecimalsMock internal token0;
    ERC20DecimalsMock internal token1;
    AeroPoolMock internal pool;
    AeroGaugeMock internal gauge;
    ChainlinkOracleMock internal token0UsdOracle;
    ChainlinkOracleMock internal token1UsdOracle;
    AeroLPTokenPriceFeedTester internal feed;

    function setUp() public {
        // Ensure any `block.timestamp - X` arithmetic in tests is safe
        vm.warp(200_000);

        token0 = new ERC20DecimalsMock("Token0", "T0", 6); // e.g. USDC-like
        token1 = new ERC20DecimalsMock("Token1", "T1", 18); // e.g. WETH-like

        borrowerOperations = new BorrowerOperationsMock();

        gauge = new AeroGaugeMock(address(token0), address(token1));
        pool = gauge.pool();
        
        // Set up pool state for LP pricing
        // 1M USDC (6 decimals) and 500 WETH (18 decimals)
        pool.setReserves(1_000_000e6, 500e18);
        pool.setTotalSupply(1000e18); // 1000 LP tokens
        
        // Set TWAP: 1 token0 (USDC) = 0.0005 token1 (WETH) -> 1 WETH = 2000 USDC
        // setQuoteAmounts(token0ToToken1, token1ToToken0)
        // - token0ToToken1: How much WETH for 1 USDC = 0.0005e18 (in WETH decimals)
        // - token1ToToken0: How much USDC for 1 WETH = 2000e6 (in USDC decimals)
        pool.setQuoteAmounts(0.0005e18, 2000e6);

        token0UsdOracle = new ChainlinkOracleMock();
        token0UsdOracle.setDecimals(8);
        token0UsdOracle.setPrice(1e8); // $1 per USDC
        token0UsdOracle.setUpdatedAt(block.timestamp);

        token1UsdOracle = new ChainlinkOracleMock();
        token1UsdOracle.setDecimals(8);
        token1UsdOracle.setPrice(2000e8); // $2000 per WETH
        token1UsdOracle.setUpdatedAt(block.timestamp);

        feed = new AeroLPTokenPriceFeedTester(
            address(borrowerOperations),
            IAeroGauge(address(gauge)),
            address(token0UsdOracle),
            address(token1UsdOracle),
            1 days,
            1 days
        );
    }

    function _setObservations(uint256[] memory durations, uint256[] memory token1PerToken0) internal {
        assertEq(durations.length, token1PerToken0.length);

        AeroPoolMock.Observation[] memory newObservations = new AeroPoolMock.Observation[](durations.length + 1);
        uint256 timestamp;
        uint256 reserve0Cumulative;
        uint256 reserve1Cumulative;
        uint256 reserve0 = 1e6;

        newObservations[0] = AeroPoolMock.Observation({
            timestamp: timestamp, reserve0Cumulative: reserve0Cumulative, reserve1Cumulative: reserve1Cumulative
        });

        for (uint256 i = 0; i < durations.length; i++) {
            timestamp += durations[i];
            reserve0Cumulative += reserve0 * durations[i];
            reserve1Cumulative += token1PerToken0[i] * durations[i];
            newObservations[i + 1] = AeroPoolMock.Observation({
                timestamp: timestamp, reserve0Cumulative: reserve0Cumulative, reserve1Cumulative: reserve1Cumulative
            });
        }

        pool.setObservations(newObservations);
    }

    // ============ TWAP Exchange Rate Tests ============

    function test_constructor_revertsWhenGaugeIsZero() public {
        vm.expectRevert("Gauge is 0 address");
        new AeroLPTokenPriceFeedTester(
            address(borrowerOperations),
            IAeroGauge(address(0)),
            address(token0UsdOracle),
            address(token1UsdOracle),
            1 days,
            1 days
        );
    }

    function test_constructor_revertsWhenOracleDecimalsMismatch() public {
        ChainlinkOracleMock mismatchedOracle = new ChainlinkOracleMock();
        mismatchedOracle.setDecimals(18);
        mismatchedOracle.setPrice(2000e18);
        mismatchedOracle.setUpdatedAt(block.timestamp);

        vm.expectRevert("Token0 and token1 decimals do not match");
        new AeroLPTokenPriceFeedTester(
            address(borrowerOperations),
            IAeroGauge(address(gauge)),
            address(token0UsdOracle),
            address(mismatchedOracle),
            1 days,
            1 days
        );
    }

    function test_getTwapExchangeRate_scalesCorrectly() public {
        // quote returns 0.0005e18 (token1 has 18 decimals)
        // Scaled to 18 decimals: 0.0005e18 * 10^(18-18) = 0.0005e18
        AeroLPTokenPriceFeedBase.ExchangeRate memory exchangeRate = feed.i_getTwapExchangeRates();
        
        assertEq(exchangeRate.token1PerToken0, 0.0005e18);
        assertEq(exchangeRate.token0PerToken1, 2000e18);
        assertFalse(exchangeRate.isDown);
    }

    function test_getExchangeRates_weightsUnequalObservationDurations() public {
        uint256[] memory durations = new uint256[](3);
        durations[0] = 1801;
        durations[1] = 1802;
        durations[2] = 1803;

        uint256[] memory token1PerToken0 = new uint256[](3);
        token1PerToken0[0] = 100e18;
        token1PerToken0[1] = 200e18;
        token1PerToken0[2] = 400e18;
        _setObservations(durations, token1PerToken0);

        (uint256 actualToken1PerToken0, uint256 actualToken0PerToken1) = feed.getExchangeRates(1, 3);

        uint256 totalTimeElapsed = 30 minutes * 3;
        uint256 oldestObservationTimeUsed = totalTimeElapsed - durations[1] - durations[2];
        uint256 expectedToken1PerToken0 =
            (token1PerToken0[0] * oldestObservationTimeUsed
                + token1PerToken0[1] * durations[1]
                + token1PerToken0[2] * durations[2])
                / totalTimeElapsed;
        uint256 expectedToken0PerToken1 =
            ((1e24 / token1PerToken0[0])
                    * oldestObservationTimeUsed
                    + (1e24 / token1PerToken0[1])
                    * durations[1]
                    + (1e24 / token1PerToken0[2])
                    * durations[2]) / totalTimeElapsed;

        assertEq(actualToken1PerToken0, expectedToken1PerToken0);
        assertEq(actualToken0PerToken1, expectedToken0PerToken1);
    }

    function test_getExchangeRates_earlyBreakUsesNewestIntervalsAndIncludesBoundary() public {
        uint256[] memory durations = new uint256[](5);
        durations[0] = 1801;
        durations[1] = 1801;
        durations[2] = 1801;
        durations[3] = 5000;
        durations[4] = 5000;

        uint256[] memory token1PerToken0 = new uint256[](5);
        token1PerToken0[0] = 900e18;
        token1PerToken0[1] = 800e18;
        token1PerToken0[2] = 700e18;
        token1PerToken0[3] = 100e18;
        token1PerToken0[4] = 200e18;
        _setObservations(durations, token1PerToken0);

        (uint256 actualToken1PerToken0, uint256 actualToken0PerToken1) = feed.getExchangeRates(1, 5);

        // The newest two 5,000-second intervals exceed the 9,000-second target.
        // Use all 5,000 seconds of the newest interval and only the newest 4,000
        // seconds represented by the boundary interval. Ignore older intervals.
        uint256 newestDuration = durations[4];
        uint256 boundaryDuration = 30 minutes * 5 - newestDuration;
        uint256 expectedToken1PerToken0 =
            (token1PerToken0[4] * newestDuration + token1PerToken0[3] * boundaryDuration) / (30 minutes * 5);
        uint256 expectedToken0PerToken1 =
            ((1e24 / token1PerToken0[4]) * newestDuration
                + (1e24 / token1PerToken0[3]) * boundaryDuration) / (30 minutes * 5);

        assertEq(actualToken1PerToken0, expectedToken1PerToken0);
        assertEq(actualToken0PerToken1, expectedToken0PerToken1);
    }

    function test_getExchangeRates_exactTargetKeepsEntireBoundaryInterval() public {
        uint256[] memory durations = new uint256[](3);
        durations[0] = 1801;
        durations[1] = 2700;
        durations[2] = 2700;

        uint256[] memory token1PerToken0 = new uint256[](3);
        token1PerToken0[0] = 900e18;
        token1PerToken0[1] = 100e18;
        token1PerToken0[2] = 200e18;
        _setObservations(durations, token1PerToken0);

        (uint256 actualToken1PerToken0, uint256 actualToken0PerToken1) = feed.getExchangeRates(1, 3);

        assertEq(actualToken1PerToken0, 150e18);
        assertEq(actualToken0PerToken1, 7500);
    }

    function testFuzz_getExchangeRates_matchesClippedElapsedTimeReference(
        uint32[8] memory durationSeeds,
        uint96[8] memory priceSeeds,
        uint8 pointsSeed
    ) public {
        uint256 points = bound(uint256(pointsSeed), 1, 8);
        uint256[] memory durations = new uint256[](8);
        uint256[] memory token1PerToken0 = new uint256[](8);

        for (uint256 i = 0; i < 8; i++) {
            durations[i] = bound(uint256(durationSeeds[i]), 1801, 1 days);
            token1PerToken0[i] = bound(uint256(priceSeeds[i]), 1, 1e24);
        }
        _setObservations(durations, token1PerToken0);

        uint256 targetTimeElapsed = 30 minutes * points;
        uint256 expectedWeightedToken1PerToken0;
        uint256 expectedWeightedToken0PerToken1;
        uint256 expectedTotalTimeElapsed;

        for (uint256 offset = 0; offset < points && expectedTotalTimeElapsed < targetTimeElapsed; offset++) {
            uint256 i = 7 - offset;
            uint256 timeUsed = durations[i];
            uint256 timeRemaining = targetTimeElapsed - expectedTotalTimeElapsed;
            if (timeUsed > timeRemaining) timeUsed = timeRemaining;

            expectedWeightedToken1PerToken0 += token1PerToken0[i] * timeUsed;
            expectedWeightedToken0PerToken1 += (1e24 / token1PerToken0[i]) * timeUsed;
            expectedTotalTimeElapsed += timeUsed;
        }

        (uint256 actualToken1PerToken0, uint256 actualToken0PerToken1) = feed.getExchangeRates(1, points);

        assertEq(expectedTotalTimeElapsed, targetTimeElapsed);
        assertEq(actualToken1PerToken0, expectedWeightedToken1PerToken0 / targetTimeElapsed);
        assertEq(actualToken0PerToken1, expectedWeightedToken0PerToken1 / targetTimeElapsed);
    }

    function testFuzz_getExchangeRates_constantPriceUnaffectedByClipping(
        uint32[8] memory durationSeeds,
        uint96 priceSeed,
        uint8 pointsSeed
    ) public {
        uint256 points = bound(uint256(pointsSeed), 1, 8);
        uint256 price = bound(uint256(priceSeed), 1, 1e24);
        uint256[] memory durations = new uint256[](8);
        uint256[] memory token1PerToken0 = new uint256[](8);

        for (uint256 i = 0; i < 8; i++) {
            durations[i] = bound(uint256(durationSeeds[i]), 1801, 1 days);
            token1PerToken0[i] = price;
        }
        _setObservations(durations, token1PerToken0);

        (uint256 actualToken1PerToken0, uint256 actualToken0PerToken1) = feed.getExchangeRates(1, points);

        assertEq(actualToken1PerToken0, price);
        assertEq(actualToken0PerToken1, 1e24 / price);
    }

    function test_getTwapExchangeRate_stablePairCoversBothTokenDirections() public {
        ERC20DecimalsMock s0 = new ERC20DecimalsMock("S0", "S0", 18);
        ERC20DecimalsMock s1 = new ERC20DecimalsMock("S1", "S1", 18);
        AeroGaugeMock g = new AeroGaugeMock(address(s0), address(s1));
        AeroPoolMock p = g.pool();
        p.setStable(true);
        p.setReserves(1_000_000e18, 1_000_000e18);
        p.setTotalSupply(1_000_000e18);

        ChainlinkOracleMock o0 = new ChainlinkOracleMock();
        o0.setDecimals(8);
        o0.setPrice(1e8);
        o0.setUpdatedAt(block.timestamp);
        ChainlinkOracleMock o1 = new ChainlinkOracleMock();
        o1.setDecimals(8);
        o1.setPrice(1e8);
        o1.setUpdatedAt(block.timestamp);

        AeroLPTokenPriceFeedTester stableFeed = new AeroLPTokenPriceFeedTester(
            address(borrowerOperations),
            IAeroGauge(address(g)),
            address(o0),
            address(o1),
            1 days,
            1 days
        );

        AeroLPTokenPriceFeedBase.ExchangeRate memory exchangeRate = stableFeed.i_getTwapExchangeRates();
        assertApproxEqAbs(exchangeRate.token1PerToken0, 1e18, 1);
        assertApproxEqAbs(exchangeRate.token0PerToken1, 1e18, 1);
        assertFalse(exchangeRate.isDown);
    }

    function test_getTwapExchangeRate_returnsDownOnRevert() public {
        pool.setShouldRevert(true);

        AeroLPTokenPriceFeedBase.ExchangeRate memory exchangeRate = feed.i_getTwapExchangeRates();
        assertEq(exchangeRate.token1PerToken0, 0);
        assertEq(exchangeRate.token0PerToken1, 0);
        assertTrue(exchangeRate.isDown);
    }

    function test_getTwapExchangeRate_returnsDownWhenObservationsRevert() public {
        pool.setShouldRevert(true);
        AeroLPTokenPriceFeedBase.ExchangeRate memory exchangeRate = feed.i_getTwapExchangeRates();
        assertTrue(exchangeRate.isDown);
    }

    function test_getTwapExchangeRate_returnsDownWhenFirstSampleHasZeroReserve() public {
        pool.setQuoteAmounts(0, 0);
        AeroLPTokenPriceFeedBase.ExchangeRate memory exchangeRate = feed.i_getTwapExchangeRates();
        assertEq(exchangeRate.token1PerToken0, 0);
        assertTrue(exchangeRate.isDown);
    }

    // ============ Pool State Tests ============

    function test_getPoolState_returnsCorrectValues() public {
        (uint256 r0, uint256 r1, uint256 supply, bool isDown) = feed.i_getPoolState();
        
        assertEq(r0, 1_000_000e6);
        assertEq(r1, 500e18);
        assertEq(supply, 1000e18);
        assertFalse(isDown);
    }

    function test_getPoolState_returnsDownOnZeroSupply() public {
        pool.setTotalSupply(0);

        (, , , bool isDown) = feed.i_getPoolState();
        assertTrue(isDown);
    }

    function test_getPoolState_returnsDownOnRevert() public {
        pool.setShouldRevert(true);

        (, , , bool isDown) = feed.i_getPoolState();
        assertTrue(isDown);
    }

    function test_getPoolState_returnsDownWhenOnlyTotalSupplyReverts() public {
        pool.setFailTotalSupplyOnly(true);
        (, , , bool isDown) = feed.i_getPoolState();
        assertTrue(isDown);
    }

    function test_getPoolState_returnsDownWhenOnlyGetReservesReverts() public {
        pool.setFailGetReservesOnly(true);
        (, , , bool isDown) = feed.i_getPoolState();
        assertTrue(isDown);
    }

    // ============ LP Token Price Calculation Tests ============

    function test_calculateLPTokenPrice_basicCalculation() public {
        // Fair-reserve pricing for volatile pairs is based on sqrt(r0 * r1), so
        // the result is effectively $2000 here, with a 1 wei rounding loss.
        uint256 price = feed.i_calculateLPTokenPrice(
            1_000_000e6,  // reserve0 (USDC)
            500e18,       // reserve1 (WETH)
            1000e18,      // totalSupply
            1e18,         // token0Price ($1)
            2000e18       // token1Price ($2000)
        );

        assertApproxEqAbs(price, 2000e18, 1);
    }

    function test_calculateLPTokenPrice_asymmetricReserves() public {
        // Fair-reserve pricing ignores naive reserve-sum inflation/deflation.
        // Here r0 * p0 == r1 * p1 is unchanged from the balanced setup, so the
        // fair LP value stays near $2000 rather than moving to a naive $2500.
        uint256 price = feed.i_calculateLPTokenPrice(
            2_000_000e6,  // reserve0 (USDC)
            250e18,       // reserve1 (WETH)
            1000e18,      // totalSupply
            1e18,         // token0Price ($1)
            2000e18       // token1Price ($2000)
        );

        assertApproxEqAbs(price, 2000e18, 1);
    }

    function test_calculateLPTokenPrice_differentDecimals() public {
        // Test that decimal scaling works correctly
        // This is implicitly tested by the setup (token0=6 decimals, token1=18 decimals)
        uint256 price = feed.i_calculateLPTokenPrice(
            100e6,        // 100 USDC
            0.05e18,      // 0.05 WETH
            10e18,        // 10 LP tokens
            1e18,         // $1 per USDC
            2000e18       // $2000 per WETH
        );

        assertApproxEqAbs(price, 20e18, 4);
    }

    function test_calculateLPTokenPrice_stablePair() public {
        ERC20DecimalsMock s0 = new ERC20DecimalsMock("S0", "S0", 18);
        ERC20DecimalsMock s1 = new ERC20DecimalsMock("S1", "S1", 18);
        AeroGaugeMock g = new AeroGaugeMock(address(s0), address(s1));
        AeroPoolMock p = g.pool();
        p.setStable(true);
        p.setReserves(1_000_000e18, 1_000_000e18);
        p.setTotalSupply(1_000_000e18);
        p.setQuoteAmounts(1e18, 1e18);

        ChainlinkOracleMock o0 = new ChainlinkOracleMock();
        o0.setDecimals(8);
        o0.setPrice(1e8);
        o0.setUpdatedAt(block.timestamp);
        ChainlinkOracleMock o1 = new ChainlinkOracleMock();
        o1.setDecimals(8);
        o1.setPrice(1e8);
        o1.setUpdatedAt(block.timestamp);

        AeroLPTokenPriceFeedTester stableFeed = new AeroLPTokenPriceFeedTester(
            address(borrowerOperations),
            IAeroGauge(address(g)),
            address(o0),
            address(o1),
            1 days,
            1 days
        );

        uint256 price = stableFeed.i_calculateLPTokenPrice(
            1_000_000e18, 1_000_000e18, 1_000_000e18, 1e18, 1e18
        );
        assertGt(price, 0);
        assertApproxEqAbs(price, 2e18, 10);
    }

    // ============ fetchPrice Tests ============

    function test_fetchPrice_calculatesCorrectLPPrice() public {
        // With setup values:
        // - 1M USDC @ $1 = $1M
        // - 500 WETH @ $2000 = $1M  
        // Fair-reserve volatile pricing returns essentially $2000 here.
        (uint256 price, bool newFailure) = feed.fetchPrice();
        
        assertFalse(newFailure);
        assertApproxEqAbs(price, 2000e18, 1);
        assertApproxEqAbs(feed.lastGoodPrice(), 2000e18, 1);
    }

    function test_fetchPrice_shutsDownOnToken0OracleDown() public {
        // First establish a lastGoodPrice
        (uint256 lastGoodBefore, ) = feed.fetchPrice();
        
        // Make token0 oracle stale
        token0UsdOracle.setUpdatedAt(block.timestamp - 2 days);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        vm.expectEmit();
        emit AeroLPTokenPriceFeedBase.ShutDownFromOracleFailure(address(token0UsdOracle));
        (uint256 price, bool newFailure) = feed.fetchPrice();

        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.lastGoodPrice));
    }

    function test_fetchPrice_shutsDownOnToken1OracleDown() public {
        // First establish a lastGoodPrice
        (uint256 lastGoodBefore, ) = feed.fetchPrice();
        
        // Make token1 oracle stale
        token1UsdOracle.setUpdatedAt(block.timestamp - 2 days);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        vm.expectEmit();
        emit AeroLPTokenPriceFeedBase.ShutDownFromOracleFailure(address(token1UsdOracle));
        (uint256 price, bool newFailure) = feed.fetchPrice();

        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.lastGoodPrice));
    }

    function test_fetchPrice_shutsDownWhenTwapQuoteReturnsZero() public {
        (uint256 lastGoodBefore,) = feed.fetchPrice();
        pool.setQuoteAmounts(0, 0);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        (uint256 price, bool newFailure) = feed.fetchPrice();
        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.lastGoodPrice));
    }

    function test_fetchPrice_shutsDownWhenSecondTwapQuoteReverts() public {
        (uint256 lastGoodBefore,) = feed.fetchPrice();
        pool.setShouldRevert(true);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        (uint256 price, bool newFailure) = feed.fetchPrice();
        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
    }

    function test_fetchPrice_shutsDownWhenTotalSupplyCallReverts() public {
        (uint256 lastGoodBefore,) = feed.fetchPrice();
        pool.setFailTotalSupplyOnly(true);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        (uint256 price, bool newFailure) = feed.fetchPrice();
        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
    }

    function test_fetchPrice_shutsDownOnToken0OracleLatestRoundDataRevert() public {
        (uint256 lastGoodBefore,) = feed.fetchPrice();
        token0UsdOracle.setRevertLatestRoundData(true);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        (uint256 price, bool newFailure) = feed.fetchPrice();
        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
    }

    function test_fetchPrice_shutsDownOnTwapDown() public {
        // First establish a lastGoodPrice
        (uint256 lastGoodBefore, ) = feed.fetchPrice();
        
        // Make pool revert
        pool.setShouldRevert(true);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        vm.expectEmit();
        emit AeroLPTokenPriceFeedBase.ShutDownFromOracleFailure(address(pool));
        (uint256 price, bool newFailure) = feed.fetchPrice();

        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.lastGoodPrice));
    }

    function test_fetchPrice_shutsDownOnZeroTotalSupply() public {
        // First establish a lastGoodPrice
        (uint256 lastGoodBefore, ) = feed.fetchPrice();
        
        // Set zero total supply
        pool.setTotalSupply(0);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        (uint256 price, bool newFailure) = feed.fetchPrice();

        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
    }

    // ============ Min/Max Price Selection Tests ============

    function test_fetchPrice_usesMinMaxLogic_outsideDeviation() public {
        // Set TWAP to deviate from Chainlink by >2%
        // TWAP: 1 USDC = 0.0004 WETH (implies WETH = $2500)
        // Chainlink: WETH = $2000
        // Deviation = 25% > 2%
        // token0ToToken1 = 0.0004e18, token1ToToken0 = 2500e6 (1/0.0004 USDC per WETH)
        pool.setQuoteAmounts(0.0004e18, 2500e6);

        (uint256 price, bool newFailure) = feed.fetchPrice();
        assertFalse(newFailure);

        // For non-redemption (borrow): uses conservative prices
        // token1MarketPrice = $1 / 0.0004 = $2500
        // token0MarketPrice = $2000 / 2500 = $0.80
        // Since deviation > 2%, uses min for token1, max for token0:
        // token1Price = min($2500, $2000) = $2000
        // token0Price = max($0.80, $1) = $1
        // Conservative pricing keeps the fair LP value near the baseline.
        assertApproxEqAbs(price, 2000e18, 1);
    }

    function test_fetchRedemptionPrice_withinDeviation_usesMaxMinLogic() public {
        // Set TWAP within 2% of Chainlink
        // TWAP: 1 USDC = 0.000505 WETH (implies WETH = $1980.20, ~1% below $2000)
        // token0ToToken1 = 0.000505e18, token1ToToken0 ≈ 1980.198e6 (1/0.000505 USDC per WETH)
        pool.setQuoteAmounts(0.000505e18, 1980198019); // ~1980.198 USDC (6 decimals)

        (uint256 price, bool newFailure) = feed.fetchRedemptionPrice();
        assertFalse(newFailure);

        // For redemption within threshold: maximize LP value
        // token1MarketPrice = $1 / 0.000505 ≈ $1980.20
        // token0MarketPrice = $2000 / 1980.198 ≈ $1.01
        // Both within 2% of oracle prices, so use max/min for redemption:
        // token1Price = max($1980.20, $2000) = $2000
        // token0Price = min($1.01, $1) = $1
        assertApproxEqAbs(price, 2000e18, 1);
    }

    function test_fetchRedemptionPrice_outsideDeviation_usesMinMaxLogic() public {
        // Set TWAP to deviate from Chainlink by >2%
        // TWAP: 1 USDC = 0.0004 WETH (implies WETH = $2500, 25% above $2000)
        // token0ToToken1 = 0.0004e18, token1ToToken0 = 2500e6 (1/0.0004 USDC per WETH)
        pool.setQuoteAmounts(0.0004e18, 2500e6);

        (uint256 price, bool newFailure) = feed.fetchRedemptionPrice();
        assertFalse(newFailure);

        // Outside threshold: same as non-redemption (conservative)
        assertApproxEqAbs(price, 2000e18, 1);
    }

    function test_fetchRedemptionPrice_withinDeviation_higherLPValue() public {
        // Set up a scenario where TWAP gives higher token1 price than Chainlink
        // but WITHIN the 2% deviation threshold
        // TWAP: 1 USDC = 0.000495 WETH (implies WETH = $2020.20, ~1% above $2000)
        // Deviation = (2020.20 - 2000) / 2000 = 1.01% < 2%
        // token0ToToken1 = 0.000495e18, token1ToToken0 ≈ 2020.202e6 (1/0.000495 USDC per WETH)
        pool.setQuoteAmounts(0.000495e18, 2020202020); // ~2020.202 USDC (6 decimals)

        (uint256 redemptionPrice, ) = feed.fetchRedemptionPrice();
        
        // Reset quote to get borrow price with same TWAP
        pool.setQuoteAmounts(0.000495e18, 2020202020);
        (uint256 borrowPrice, ) = feed.fetchPrice();

        // Calculate expected values:
        // token1MarketPrice = $1 / 0.000495 = $2020.20
        // token0MarketPrice = $2000 / 2020.202 ≈ $0.99 
        // Both within 2% of oracle prices
        //
        // Redemption (within 2% threshold): 
        //   token1Price = max($2020.20, $2000) = $2020.20
        //   token0Price = min($0.99, $1) = $0.99
        // Borrow: 
        //   token1Price = min($2020.20, $2000) = $2000
        //   token0Price = max($0.99, $1) = $1
        //
        // LP value with reserves (1M USDC, 500 WETH) and 1000 LP tokens:
        // Redemption: (1M * $0.99 + 500 * $2020.20) / 1000 ≈ $2000.10 (higher token1 price wins)
        // Borrow: (1M * $1 + 500 * $2000) / 1000 = $2000
        
        assertGe(redemptionPrice, borrowPrice, "Redemption price should not be lower than borrow price");
    }

    // ============ Edge Cases ============

    function test_fetchPrice_afterShutdown_returnsLastGoodPrice() public {
        // Get initial price
        (uint256 initialPrice, ) = feed.fetchPrice();
        
        // Trigger shutdown
        token0UsdOracle.setUpdatedAt(block.timestamp - 2 days);
        feed.fetchPrice();
        
        // Restore oracle but feed should still use lastGoodPrice
        token0UsdOracle.setUpdatedAt(block.timestamp);
        
        (uint256 price, bool newFailure) = feed.fetchPrice();
        assertFalse(newFailure);
        assertEq(price, initialPrice);
    }

    function test_priceSourceStartsAsPrimary() public {
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.primary));
    }

    // ============ Base helpers (Chainlink / deviation) ============

    function test_i_getCurrentChainlinkResponse_returnsFailureOnRevert() public {
        token0UsdOracle.setRevertLatestRoundData(true);
        AeroLPTokenPriceFeedBase.ChainlinkResponse memory r =
            feed.i_getCurrentChainlinkResponse(AggregatorV3Interface(address(token0UsdOracle)));
        assertFalse(r.success);
    }

    function test_i_getOracleAnswer_marksDownForZeroPrice() public {
        token0UsdOracle.setPrice(0);
        AeroLPTokenPriceFeedBase.Oracle memory o = AeroLPTokenPriceFeedBase.Oracle({
            aggregator: AggregatorV3Interface(address(token0UsdOracle)),
            stalenessThreshold: 1 days,
            decimals: 8
        });
        (uint256 scaled, bool down) = feed.i_getOracleAnswer(o);
        assertTrue(down);
        assertEq(scaled, 0);
    }

    function test_i_getOracleAnswer_marksDownForNegativePrice() public {
        token0UsdOracle.setPrice(-1);
        AeroLPTokenPriceFeedBase.Oracle memory o = AeroLPTokenPriceFeedBase.Oracle({
            aggregator: AggregatorV3Interface(address(token0UsdOracle)),
            stalenessThreshold: 1 days,
            decimals: 8
        });
        (uint256 scaled, bool down) = feed.i_getOracleAnswer(o);
        assertTrue(down);
        assertEq(scaled, 0);
    }

    function test_i_isValidChainlinkPrice_requiresSuccessFreshAndPositive() public {
        AeroLPTokenPriceFeedBase.ChainlinkResponse memory ok = AeroLPTokenPriceFeedBase.ChainlinkResponse({
            roundId: 1,
            answer: 100e8,
            timestamp: block.timestamp,
            success: true
        });
        assertTrue(feed.i_isValidChainlinkPrice(ok, 1 days));

        AeroLPTokenPriceFeedBase.ChainlinkResponse memory badSuccess = ok;
        badSuccess.success = false;
        assertFalse(feed.i_isValidChainlinkPrice(badSuccess, 1 days));

        AeroLPTokenPriceFeedBase.ChainlinkResponse memory stale = ok;
        stale.timestamp = block.timestamp - 2 days;
        assertFalse(feed.i_isValidChainlinkPrice(stale, 1 days));

        AeroLPTokenPriceFeedBase.ChainlinkResponse memory zeroAns = ok;
        zeroAns.answer = 0;
        assertFalse(feed.i_isValidChainlinkPrice(zeroAns, 1 days));
    }

    function test_i_scaleChainlinkPriceTo18decimals_eightDecimals() public {
        assertEq(feed.i_scaleChainlinkPriceTo18decimals(2_000e8, 8), 2000e18);
    }

    function test_i_withinDeviationThreshold_boundaryInclusive() public {
        uint256 ref = 1e18;
        uint256 thr = 2e16;
        uint256 min = ref * (DECIMAL_PRECISION - thr) / 1e18;
        uint256 max = ref * (DECIMAL_PRECISION + thr) / 1e18;
        assertTrue(feed.i_withinDeviationThreshold(min, ref, thr));
        assertTrue(feed.i_withinDeviationThreshold(max, ref, thr));
        assertFalse(feed.i_withinDeviationThreshold(min - 1, ref, thr));
        assertFalse(feed.i_withinDeviationThreshold(max + 1, ref, thr));
    }
}
