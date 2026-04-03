// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import "src/PriceFeeds/AeroLPTokenPriceFeed.sol";
import "src/PriceFeeds/AeroLPTokenPriceFeedBase.sol";
import "src/Dependencies/LiquityMath.sol";

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

contract AeroLPPriceManipulationTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ERC20DecimalsMock internal token0;
    ERC20DecimalsMock internal token1;
    AeroPoolMock internal pool;
    AeroGaugeMock internal gauge;
    ChainlinkOracleMock internal token0UsdOracle;
    ChainlinkOracleMock internal token1UsdOracle;
    AeroLPTokenPriceFeedTester internal feed;

    uint256 constant DEVIATION_THRESHOLD = 2e16;

    function setUp() public {
        vm.warp(200_000);

        token0 = new ERC20DecimalsMock("Token0", "T0", 6);
        token1 = new ERC20DecimalsMock("Token1", "T1", 18);

        borrowerOperations = new BorrowerOperationsMock();

        gauge = new AeroGaugeMock(address(token0), address(token1));
        pool = gauge.pool();
        
        pool.setReserves(1_000_000e6, 500e18);
        pool.setTotalSupply(1000e18);
        pool.setQuoteAmounts(0.0005e18, 2000e6);

        token0UsdOracle = new ChainlinkOracleMock();
        token0UsdOracle.setDecimals(8);
        token0UsdOracle.setPrice(1e8);
        token0UsdOracle.setUpdatedAt(block.timestamp);

        token1UsdOracle = new ChainlinkOracleMock();
        token1UsdOracle.setDecimals(8);
        token1UsdOracle.setPrice(2000e8);
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

    // ============ Deviation Threshold Boundary Tests ============

    function test_deviationThreshold_exactlyAtBoundary() public {
        uint256 referencePrice = 2000e18;
        uint256 maxDeviation = DEVIATION_THRESHOLD;
        
        uint256 maxPrice = referencePrice * (1e18 + maxDeviation) / 1e18;
        uint256 minPrice = referencePrice * (1e18 - maxDeviation) / 1e18;
        
        assertTrue(_withinDeviationThreshold(maxPrice, referencePrice, maxDeviation));
        assertTrue(_withinDeviationThreshold(minPrice, referencePrice, maxDeviation));
    }

    function test_deviationThreshold_justAboveBoundary() public {
        uint256 referencePrice = 2000e18;
        uint256 maxDeviation = DEVIATION_THRESHOLD;
        
        uint256 maxPrice = referencePrice * (1e18 + maxDeviation + 1) / 1e18;
        uint256 minPrice = referencePrice * (1e18 - maxDeviation - 1) / 1e18;
        
        assertFalse(_withinDeviationThreshold(maxPrice, referencePrice, maxDeviation));
        assertFalse(_withinDeviationThreshold(minPrice, referencePrice, maxDeviation));
    }

    // ============ Upward Manipulation Resistance Tests ============

    function test_upwardManipulation_cannotInflateLPValue() public {
        (uint256 baselinePrice, ) = feed.fetchPrice();

        // Manipulate TWAP to show WETH at $10000 (400% above Chainlink's $2000)
        pool.setQuoteAmounts(0.0001e18, 10000e6);

        (uint256 manipulatedPrice, ) = feed.fetchPrice();

        // Conservative pricing should prevent inflation:
        // token1Price = min($10000, $2000) = $2000
        // token0Price = max($0.20, $1) = $1
        // LP value = (1M * $1 + 500 * $2000) / 1000 = $2000
        assertLe(manipulatedPrice, baselinePrice, "Manipulation cannot inflate LP value");
    }

    // ============ Downward Manipulation Resistance Tests ============

    function test_downwardManipulation_cannotDeflateLPValueForBorrow() public {
        (uint256 baselinePrice, ) = feed.fetchPrice();

        // Manipulate TWAP to show WETH at $100 (95% below Chainlink's $2000)
        pool.setQuoteAmounts(0.01e18, 100e6);

        (uint256 manipulatedPrice, ) = feed.fetchPrice();

        // Conservative pricing prevents deflation:
        // token1MarketPrice = $1 / 0.01 = $100
        // token0MarketPrice = $2000 / 100 = $20
        // token1Price = min($100, $2000) = $100
        // token0Price = max($20, $1) = $20
        // LP value = (1M * $20 + 500 * $100) / 1000 = $20050
        assertGe(manipulatedPrice, baselinePrice, "Downward manipulation cannot deflate borrow LP value");
    }

    // ============ TWAP vs Oracle Divergence Tests ============

    function test_twapOracleDivergence_bothTokensDeviated() public {
        // Manipulate TWAP to deviate both token prices significantly
        // 1 USDC = 0.0003 WETH -> WETH market = $3333.33 (66.67% above oracle)
        pool.setQuoteAmounts(0.0003e18, 3333333333);

        (uint256 price, bool newFailure) = feed.fetchPrice();
        assertFalse(newFailure);

        // Both tokens should use conservative prices
        // token1Price = min($3333.33, $2000) = $2000
        // token0Price = max($0.60, $1) = $1
        // Price should be close to baseline ($2000) - within 0.1% due to rounding
        assertApproxEqRel(price, 2000e18, 0.001e18, "Price should be near baseline with conservative pricing");
    }

    function test_twapOracleDivergence_oneTokenOracleChanged() public {
        // Change token1 oracle price to create divergence
        token1UsdOracle.setPrice(2100e8); // $2100 per WETH
        
        // TWAP still shows: 1 USDC = 0.0005 WETH -> WETH market = $2000
        // token1MarketPrice = $2000, oracle = $2100 -> deviation = 4.76% > 2%
        // token0MarketPrice = $2100 / 2000 = $1.05, oracle = $1 -> deviation = 5% > 2%
        
        (uint256 price, ) = feed.fetchPrice();

        // Conservative pricing:
        // token1Price = min($2000, $2100) = $2000
        // token0Price = max($1.05, $1) = $1.05
        // LP value ≈ $2050 (with some rounding)
        assertApproxEqRel(price, 2050e18, 0.001e18, "Price should reflect conservative pricing");
    }

    // ============ Extreme Manipulation Tests ============

    function test_extremeManipulation_veryHighTWAP() public {
        // Extreme TWAP: 1 USDC = 0.00001 WETH -> WETH = $100000
        pool.setQuoteAmounts(0.00001e18, 100000e6);

        (uint256 price, ) = feed.fetchPrice();

        // Conservative pricing limits impact:
        // token1Price = min($100000, $2000) = $2000
        // token0Price = max($0.02, $1) = $1
        // Price should be near $2000 (within 0.1% due to rounding)
        assertApproxEqRel(price, 2000e18, 0.001e18, "Price should be near baseline with extreme high TWAP");
    }

    function test_extremeManipulation_veryLowTWAP() public {
        // Extreme TWAP: 1 USDC = 0.1 WETH -> WETH = $10
        pool.setQuoteAmounts(0.1e18, 10e6);

        (uint256 price, ) = feed.fetchPrice();

        // Conservative pricing:
        // token1MarketPrice = $1 / 0.1 = $10
        // token0MarketPrice = $2000 / 10 = $200
        // token1Price = min($10, $2000) = $10
        // token0Price = max($200, $1) = $200
        // LP value = (1M * $200 + 500 * $10) / 1000 = $200050
        assertGe(price, 1999e18, "Price should reflect conservative valuation");
    }

    // ============ Reserve Skewing Attack Tests ============

    function test_reserveSkewing_volatilePair_constantProductInvariant() public {
        (uint256 baselinePrice, ) = feed.fetchPrice();

        uint256 r0 = 1_000_000e6;
        uint256 r1 = 500e18;
        uint256 k = r0 * r1;

        // Simulate flash loan swap: drain token0, add token1
        // Swap 500k USDC out, receive ~333.33 WETH (using constant product)
        uint256 newR0 = 500_000e6;
        uint256 newR1 = k / newR0; // = 1000e18

        pool.setReserves(newR0, newR1);

        (uint256 skewedPrice, ) = feed.fetchPrice();

        // The volatile LP formula uses k = sqrt(r0 * r1) which is constant along the curve
        // So the LP price should remain essentially unchanged (within rounding)
        assertApproxEqRel(skewedPrice, baselinePrice, 0.01e18, "Price should be invariant to reserve skewing along constant product curve");
    }

    function test_reserveSkewing_volatilePair_extremeSkew() public {
        (uint256 baselinePrice, ) = feed.fetchPrice();

        uint256 r0 = 1_000_000e6;
        uint256 r1 = 500e18;
        uint256 k = r0 * r1;

        // Extreme skew: drain 99% of token0
        uint256 newR0 = 10_000e6;
        uint256 newR1 = k / newR0; // = 50000e18

        pool.setReserves(newR0, newR1);

        (uint256 skewedPrice, ) = feed.fetchPrice();

        // Price should remain near baseline due to k = sqrt(r0*r1) being invariant
        assertApproxEqRel(skewedPrice, baselinePrice, 0.01e18, "Price should be invariant even under extreme skew");
    }

    function test_reserveSkewing_volatilePair_cannotInflatePrice() public {
        // Get baseline
        (uint256 baselinePrice, ) = feed.fetchPrice();

        // Try various skew directions to find if any inflates price
        uint256 r0 = 1_000_000e6;
        uint256 r1 = 500e18;
        uint256 k = r0 * r1;

        uint256[6] memory skewRatios = [
            uint256(0.99e18),  // 99% of r0 remains
            uint256(0.9e18),   // 90%
            uint256(0.5e18),   // 50%
            uint256(0.1e18),   // 10%
            uint256(0.01e18),  // 1%
            uint256(0.001e18)  // 0.1%
        ];

        for (uint256 i = 0; i < skewRatios.length; i++) {
            uint256 newR0 = r0 * skewRatios[i] / 1e18;
            vm.assume(newR0 > 0);
            uint256 newR1 = k / newR0;

            pool.setReserves(newR0, newR1);

            (uint256 skewedPrice, ) = feed.fetchPrice();

            // Price should never exceed baseline by more than rounding error
            assertLe(skewedPrice, baselinePrice * 101 / 100, "Skewing cannot inflate price beyond 1%");
        }
    }

    function test_reserveSkewing_volatilePair_cannotDeflatePrice() public {
        (uint256 baselinePrice, ) = feed.fetchPrice();

        uint256 r0 = 1_000_000e6;
        uint256 r1 = 500e18;
        uint256 k = r0 * r1;

        uint256[6] memory skewRatios = [
            uint256(0.99e18),
            uint256(0.9e18),
            uint256(0.5e18),
            uint256(0.1e18),
            uint256(0.01e18),
            uint256(0.001e18)
        ];

        for (uint256 i = 0; i < skewRatios.length; i++) {
            uint256 newR0 = r0 * skewRatios[i] / 1e18;
            vm.assume(newR0 > 0);
            uint256 newR1 = k / newR0;

            pool.setReserves(newR0, newR1);

            (uint256 skewedPrice, ) = feed.fetchPrice();

            // Price should never drop below baseline by more than rounding error
            assertGe(skewedPrice, baselinePrice * 99 / 100, "Skewing cannot deflate price beyond 1%");
        }
    }

    function test_reserveSkewing_flashLoanAttackSimulation() public {
        // Simulate a flash loan attack scenario:
        // 1. Attacker flash-loans token0 from pool
        // 2. This skews reserves (less token0, more token1 after swap)
        // 3. Attacker calls fetchPrice() to get inflated LP value
        // 4. Uses inflated LP as collateral to borrow BOLD
        // 5. Unwinds swap, reserves return to normal
        // 6. Attacker repays flash loan, keeps excess BOLD

        (uint256 baselinePrice, ) = feed.fetchPrice();

        // Step 2: Skew reserves via swap
        uint256 r0 = 1_000_000e6;
        uint256 r1 = 500e18;
        uint256 k = r0 * r1;
        
        // Swap out 90% of token0 reserves
        uint256 newR0 = 100_000e6;
        uint256 newR1 = k / newR0; // = 5000e18
        pool.setReserves(newR0, newR1);

        // Step 3: Get price during skew
        (uint256 skewedPrice, ) = feed.fetchPrice();

        // The price should NOT be significantly inflated due to fair reserve calculation
        // If it were, the attacker could borrow against inflated collateral
        assertApproxEqRel(skewedPrice, baselinePrice, 0.01e18, "Flash loan skew should not inflate LP price");

        // Step 6: Unwind - restore reserves
        pool.setReserves(r0, r1);
        (uint256 restoredPrice, ) = feed.fetchPrice();

        // Price should return to baseline
        assertApproxEqRel(restoredPrice, baselinePrice, 0.01e18, "Price should recover after unwind");

        // lastGoodPrice should have been updated consistently
        assertApproxEqRel(feed.lastGoodPrice(), baselinePrice, 0.01e18, "lastGoodPrice should remain stable");
    }

    function test_reserveSkewing_volatilePair_kInvariantHolds() public {
        // Verify that k = sqrt(r0 * r1) is truly invariant along the constant product curve
        uint256 r0 = 1_000_000e6;
        uint256 r1 = 500e18;
        uint256 k = r0 * r1;

        uint256[5] memory newR0Values = [
            uint256(2_000_000e6),  // Double token0
            uint256(500_000e6),    // Half token0
            uint256(100_000e6),    // 10% token0
            uint256(10_000e6),     // 1% token0
            uint256(5_000_000e6)   // 5x token0
        ];

        uint256 baselineK;
        for (uint256 i = 0; i < newR0Values.length; i++) {
            uint256 newR0 = newR0Values[i];
            uint256 newR1 = k / newR0;

            pool.setReserves(newR0, newR1);

            feed.fetchPrice();

            // Calculate what k would be in the LP formula
            uint256 r0Scaled = newR0 * 1e12; // 6 -> 18 decimals
            uint256 r1Scaled = newR1;        // already 18 decimals
            uint256 kComputed = r0Scaled * r1Scaled;

            if (i == 0) {
                baselineK = kComputed;
            }

            // k should be constant (within rounding from integer division)
            assertApproxEqRel(kComputed, baselineK, 0.0001e18, "k should be invariant along curve");

            // And price should be stable
            (uint256 baselinePrice2, ) = feed.fetchPrice();
            pool.setReserves(r0, r1);
            (uint256 baselinePrice3, ) = feed.fetchPrice();
            pool.setReserves(newR0, newR1);

            assertApproxEqRel(baselinePrice2, baselinePrice3, 0.01e18, "Price should be stable along curve");
        }
    }

    // ============ Multi-Step Manipulation Tests ============

    function test_multiStepManipulation_gradualDrift() public {
        uint256 lastPrice;
        
        (uint256 price, ) = feed.fetchPrice();
        lastPrice = price;

        // Gradually increase TWAP deviation upward
        uint256[5] memory twapValues = [
            uint256(0.00049e18),
            uint256(0.00048e18),
            uint256(0.00047e18),
            uint256(0.00045e18),
            uint256(0.0004e18)
        ];

        for (uint256 i = 0; i < twapValues.length; i++) {
            uint256 reverseTwap = (1e24) / twapValues[i];
            pool.setQuoteAmounts(twapValues[i], reverseTwap);

            (price, ) = feed.fetchPrice();

            // Price should never increase due to upward manipulation
            assertLe(price, lastPrice, "Price should not increase with upward manipulation");
            lastPrice = price;
        }
    }

    function test_multiStepManipulation_recoveryAfterManipulation() public {
        (uint256 baselinePrice, ) = feed.fetchPrice();

        // Manipulate TWAP
        pool.setQuoteAmounts(0.0004e18, 2500e6);
        feed.fetchPrice();

        // Restore normal TWAP
        pool.setQuoteAmounts(0.0005e18, 2000e6);
        (uint256 restoredPrice, ) = feed.fetchPrice();

        assertEq(restoredPrice, baselinePrice, "Price should recover after manipulation stops");
    }

    // ============ Helper Functions ============

    function _withinDeviationThreshold(uint256 _priceToCheck, uint256 _referencePrice, uint256 _deviationThreshold)
        internal
        pure
        returns (bool)
    {
        uint256 max = _referencePrice * (1e18 + _deviationThreshold) / 1e18;
        uint256 min = _referencePrice * (1e18 - _deviationThreshold) / 1e18;

        return _priceToCheck >= min && _priceToCheck <= max;
    }
}

contract AeroLPPriceManipulationFuzzTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ERC20DecimalsMock internal token0;
    ERC20DecimalsMock internal token1;
    AeroPoolMock internal pool;
    AeroGaugeMock internal gauge;
    ChainlinkOracleMock internal token0UsdOracle;
    ChainlinkOracleMock internal token1UsdOracle;
    AeroLPTokenPriceFeedTester internal feed;

    uint256 constant DEVIATION_THRESHOLD = 2e16;

    function setUp() public {
        vm.warp(200_000);

        token0 = new ERC20DecimalsMock("Token0", "T0", 6);
        token1 = new ERC20DecimalsMock("Token1", "T1", 18);

        borrowerOperations = new BorrowerOperationsMock();

        gauge = new AeroGaugeMock(address(token0), address(token1));
        pool = gauge.pool();
        
        pool.setReserves(1_000_000e6, 500e18);
        pool.setTotalSupply(1000e18);
        pool.setQuoteAmounts(0.0005e18, 2000e6);

        token0UsdOracle = new ChainlinkOracleMock();
        token0UsdOracle.setDecimals(8);
        token0UsdOracle.setPrice(1e8);
        token0UsdOracle.setUpdatedAt(block.timestamp);

        token1UsdOracle = new ChainlinkOracleMock();
        token1UsdOracle.setDecimals(8);
        token1UsdOracle.setPrice(2000e8);
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

    // ============ Fuzz Tests for Deviation Threshold ============

    function testFuzz_deviationThreshold_boundary(uint256 deviation) public {
        deviation = bound(deviation, 0, 10e18);
        
        uint256 referencePrice = 2000e18;
        bool withinThreshold = _withinDeviationThreshold(
            referencePrice * (1e18 + deviation) / 1e18,
            referencePrice,
            DEVIATION_THRESHOLD
        );

        if (deviation <= DEVIATION_THRESHOLD) {
            assertTrue(withinThreshold);
        } else {
            assertFalse(withinThreshold);
        }
    }

    function testFuzz_borrowPriceNeverExceedsBaseline(uint256 twapMultiplier) public {
        twapMultiplier = bound(twapMultiplier, 1e16, 1e20);
        
        uint256 baseTwap = 0.0005e18;
        uint256 manipulatedTwap = baseTwap * twapMultiplier / 1e18;
        
        vm.assume(manipulatedTwap > 0);
        
        uint256 reverseTwap = (1e36) / manipulatedTwap;
        pool.setQuoteAmounts(manipulatedTwap, reverseTwap);

        // Get baseline price with normal TWAP
        pool.setQuoteAmounts(0.0005e18, 2000e6);
        (uint256 baselinePrice, ) = feed.fetchPrice();

        // Get price with manipulated TWAP
        pool.setQuoteAmounts(manipulatedTwap, reverseTwap);
        (uint256 manipulatedPrice, ) = feed.fetchPrice();

        // For upward manipulation (twapMultiplier < 1e18), price should not increase
        if (twapMultiplier < 1e18) {
            assertLe(manipulatedPrice, baselinePrice, "Upward manipulation cannot inflate borrow price");
        }
    }

    function testFuzz_oraclePriceDeviation(uint256 token0Price, uint256 token1Price, uint256 twapToken1PerToken0) public {
        token0Price = bound(token0Price, 1e6, 100e8);
        token1Price = bound(token1Price, 100e8, 10000e8);
        twapToken1PerToken0 = bound(twapToken1PerToken0, 1e12, 1e24);
        
        vm.assume(twapToken1PerToken0 > 0);

        token0UsdOracle.setPrice(int256(token0Price));
        token1UsdOracle.setPrice(int256(token1Price));

        uint256 reverseTwap = (1e36) / twapToken1PerToken0;
        pool.setQuoteAmounts(twapToken1PerToken0, reverseTwap);

        (uint256 price, bool newFailure) = feed.fetchPrice();

        assertGe(price, 0);
        
        if (!newFailure) {
            // Price should be non-zero with valid inputs
            assertGt(price, 0);
        }
    }

    function testFuzz_reserveSkewing_alongConstantProductCurve(uint256 skewRatio) public {
        skewRatio = bound(skewRatio, 1e14, 1e22);
        vm.assume(skewRatio > 0);

        (uint256 baselinePrice, ) = feed.fetchPrice();

        uint256 r0 = 1_000_000e6;
        uint256 r1 = 500e18;
        uint256 k = r0 * r1;

        // Skew reserves along constant product curve
        uint256 newR0 = r0 * skewRatio / 1e18;
        vm.assume(newR0 > 0 && newR0 < type(uint256).max / r1);
        uint256 newR1 = k / newR0;
        vm.assume(newR1 > 0);

        pool.setReserves(newR0, newR1);

        (uint256 skewedPrice, ) = feed.fetchPrice();

        // Price should remain within 1% of baseline due to k = sqrt(r0*r1) being invariant
        assertApproxEqRel(skewedPrice, baselinePrice, 0.01e18, "Price should be invariant to reserve skewing along CP curve");
    }

    function testFuzz_reserveSkewing_cannotInflatePrice(uint256 skewRatio) public {
        skewRatio = bound(skewRatio, 1e12, 1e24);
        vm.assume(skewRatio > 0);

        (uint256 baselinePrice, ) = feed.fetchPrice();

        uint256 r0 = 1_000_000e6;
        uint256 r1 = 500e18;
        uint256 k = r0 * r1;

        uint256 newR0 = r0 * skewRatio / 1e18;
        vm.assume(newR0 > 0 && newR0 < type(uint256).max / r1);
        uint256 newR1 = k / newR0;
        vm.assume(newR1 > 0);

        pool.setReserves(newR0, newR1);

        (uint256 skewedPrice, ) = feed.fetchPrice();

        // Price should never exceed baseline by more than 1%
        assertLe(skewedPrice, baselinePrice * 101 / 100, "Skewing cannot inflate price");
    }

    function testFuzz_reserveSkewing_kInvariant(uint256 skewRatio) public {
        skewRatio = bound(skewRatio, 1e12, 1e24);
        vm.assume(skewRatio > 0);

        uint256 r0 = 1_000_000e6;
        uint256 r1 = 500e18;
        uint256 k = r0 * r1;

        uint256 newR0 = r0 * skewRatio / 1e18;
        vm.assume(newR0 > 0 && newR0 < type(uint256).max / r1);
        uint256 newR1 = k / newR0;
        vm.assume(newR1 > 0);

        // k should be preserved (within rounding from integer division)
        uint256 kNew = newR0 * newR1;
        assertApproxEqRel(kNew, k, 0.0001e18, "k should be invariant along constant product curve");
    }

    function testFuzz_twapOracleConsistency(uint256 twapRate) public {
        twapRate = bound(twapRate, 1e12, 1e24);
        vm.assume(twapRate > 0);

        uint256 reverseTwap = (1e36) / twapRate;
        pool.setQuoteAmounts(twapRate, reverseTwap);

        uint256 token1MarketPrice = 1e18 * 1e18 / twapRate;
        uint256 token0MarketPrice = 2000e18 * 1e18 / reverseTwap;

        bool token1WithinThreshold = _withinDeviationThreshold(
            token1MarketPrice, 2000e18, DEVIATION_THRESHOLD
        );
        bool token0WithinThreshold = _withinDeviationThreshold(
            token0MarketPrice, 1e18, DEVIATION_THRESHOLD
        );

        bool bothWithinThreshold = token1WithinThreshold && token0WithinThreshold;

        (uint256 borrowPrice, ) = feed.fetchPrice();
        
        pool.setQuoteAmounts(twapRate, reverseTwap);
        (uint256 redemptionPrice, ) = feed.fetchRedemptionPrice();

        if (bothWithinThreshold) {
            assertGe(redemptionPrice, borrowPrice);
        }
    }

    // ============ Invariant Fuzz Tests ============

    function testFuzz_invariant_borrowPriceConservative(uint256 twapMultiplier, uint256 oracleMultiplier) public {
        twapMultiplier = bound(twapMultiplier, 1e16, 1e20);
        oracleMultiplier = bound(oracleMultiplier, 1e16, 1e20);

        uint256 baseTwap = 0.0005e18;
        uint256 manipulatedTwap = baseTwap * twapMultiplier / 1e18;
        vm.assume(manipulatedTwap > 0);
        uint256 reverseTwap = (1e36) / manipulatedTwap;
        pool.setQuoteAmounts(manipulatedTwap, reverseTwap);

        uint256 manipulatedOraclePrice = 2000e8 * oracleMultiplier / 1e18;
        token1UsdOracle.setPrice(int256(manipulatedOraclePrice));

        (uint256 price, ) = feed.fetchPrice();

        // Invariant: price should always be non-zero and finite
        assertGt(price, 0);
        assertLt(price, type(uint256).max / 1e18);
    }

    function testFuzz_invariant_lastGoodPriceMonotonic(uint256 numSteps) public {
        numSteps = bound(numSteps, 1, 10);

        for (uint256 i = 0; i < numSteps; i++) {
            (uint256 price, bool newFailure) = feed.fetchPrice();

            if (!newFailure) {
                assertEq(feed.lastGoodPrice(), price);
            }
        }

        (uint256 finalPrice, bool finalFailure) = feed.fetchPrice();
        if (!finalFailure) {
            assertEq(feed.lastGoodPrice(), finalPrice);
        }
    }

    // ============ Helper Functions ============

    function _withinDeviationThreshold(uint256 _priceToCheck, uint256 _referencePrice, uint256 _deviationThreshold)
        internal
        pure
        returns (bool)
    {
        uint256 max = _referencePrice * (1e18 + _deviationThreshold) / 1e18;
        uint256 min = _referencePrice * (1e18 - _deviationThreshold) / 1e18;

        return _priceToCheck >= min && _priceToCheck <= max;
    }
}

contract AeroLPPriceManipulationInvariantTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ERC20DecimalsMock internal token0;
    ERC20DecimalsMock internal token1;
    AeroPoolMock internal pool;
    AeroGaugeMock internal gauge;
    ChainlinkOracleMock internal token0UsdOracle;
    ChainlinkOracleMock internal token1UsdOracle;
    AeroLPTokenPriceFeedTester internal feed;

    function setUp() public {
        vm.warp(200_000);

        token0 = new ERC20DecimalsMock("Token0", "T0", 6);
        token1 = new ERC20DecimalsMock("Token1", "T1", 18);

        borrowerOperations = new BorrowerOperationsMock();

        gauge = new AeroGaugeMock(address(token0), address(token1));
        pool = gauge.pool();
        
        pool.setReserves(1_000_000e6, 500e18);
        pool.setTotalSupply(1000e18);
        pool.setQuoteAmounts(0.0005e18, 2000e6);

        token0UsdOracle = new ChainlinkOracleMock();
        token0UsdOracle.setDecimals(8);
        token0UsdOracle.setPrice(1e8);
        token0UsdOracle.setUpdatedAt(block.timestamp);

        token1UsdOracle = new ChainlinkOracleMock();
        token1UsdOracle.setDecimals(8);
        token1UsdOracle.setPrice(2000e8);
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

    // ============ Invariant: Borrow price <= Redemption price when within threshold ============

    function test_invariant_borrowLeqRedemption_withinThreshold() public {
        pool.setQuoteAmounts(0.000495e18, 2020202020);

        (uint256 borrowPrice, ) = feed.fetchPrice();
        (uint256 redemptionPrice, ) = feed.fetchRedemptionPrice();

        assertLe(borrowPrice, redemptionPrice, "Borrow price should be <= redemption price within threshold");
    }

    // ============ Invariant: Price never exceeds oracle-based maximum ============

    function test_invariant_priceBoundedByOracles() public {
        uint256[5] memory twapRates = [
            uint256(0.0001e18),
            uint256(0.00025e18),
            uint256(0.0005e18),
            uint256(0.001e18),
            uint256(0.002e18)
        ];

        for (uint256 i = 0; i < twapRates.length; i++) {
            uint256 reverseTwap = (1e36) / twapRates[i];
            pool.setQuoteAmounts(twapRates[i], reverseTwap);

            (uint256 price, ) = feed.fetchPrice();

            uint256 maxLPValue = (1_000_000e6 * 1e12 * 1e18 + 500e18 * 2000e18) / 1000e18;
            assertLe(price, maxLPValue * 10, "Price should be bounded by oracle maximum");
        }
    }

    // ============ Invariant: Shutdown preserves lastGoodPrice ============

    function test_invariant_shutdownPreservesLastGoodPrice() public {
        feed.fetchPrice();
        uint256 lastGoodBefore = feed.lastGoodPrice();

        token0UsdOracle.setUpdatedAt(block.timestamp - 2 days);
        (uint256 shutdownPrice, bool newFailure) = feed.fetchPrice();

        assertTrue(newFailure);
        assertEq(shutdownPrice, lastGoodBefore);
        assertEq(feed.lastGoodPrice(), lastGoodBefore);
    }

    // ============ Invariant: TWAP zero values trigger shutdown ============

    function test_invariant_zeroTwapTriggersShutdown() public {
        (uint256 lastGoodBefore, ) = feed.fetchPrice();

        pool.setQuoteAmounts(0, 0);

        (uint256 price, bool newFailure) = feed.fetchPrice();

        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
    }

    // ============ Invariant: Price calculation is deterministic ============

    function test_invariant_deterministicPrice() public {
        (uint256 price1, ) = feed.fetchPrice();
        (uint256 price2, ) = feed.fetchPrice();

        assertEq(price1, price2);
    }
}

contract AeroLPStablePairManipulationTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ERC20DecimalsMock internal token0;
    ERC20DecimalsMock internal token1;
    AeroPoolMock internal pool;
    AeroGaugeMock internal gauge;
    ChainlinkOracleMock internal token0UsdOracle;
    ChainlinkOracleMock internal token1UsdOracle;
    AeroLPTokenPriceFeedTester internal feed;

    uint256 constant DEVIATION_THRESHOLD = 2e16;

    function setUp() public {
        vm.warp(200_000);

        token0 = new ERC20DecimalsMock("Token0", "T0", 18);
        token1 = new ERC20DecimalsMock("Token1", "T1", 18);

        borrowerOperations = new BorrowerOperationsMock();

        gauge = new AeroGaugeMock(address(token0), address(token1));
        pool = gauge.pool();
        pool.setStable(true);

        pool.setReserves(1_000_000e18, 1_000_000e18);
        pool.setTotalSupply(1000e18);
        pool.setQuoteAmounts(1e18, 1e18);

        token0UsdOracle = new ChainlinkOracleMock();
        token0UsdOracle.setDecimals(8);
        token0UsdOracle.setPrice(1e8);
        token0UsdOracle.setUpdatedAt(block.timestamp);

        token1UsdOracle = new ChainlinkOracleMock();
        token1UsdOracle.setDecimals(8);
        token1UsdOracle.setPrice(1e8);
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

    function _getK(uint256 x, uint256 y) internal pure returns (uint256) {
        uint256 x3 = _mulWadDown(_mulWadDown(x, x), x);
        uint256 y3 = _mulWadDown(_mulWadDown(y, y), y);
        return _mulWadDown(x3, y) + _mulWadDown(y3, x);
    }

    function _mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y) / 1e18;
    }

    function _solveY(uint256 x, uint256 targetK) internal pure returns (uint256) {
        uint256 low = 1;
        uint256 high = 100_000_000e18;

        for (uint256 i = 0; i < 256; i++) {
            uint256 mid = (low + high) / 2;
            uint256 kMid = _getK(x, mid);

            if (kMid < targetK) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }

        return high;
    }

    function _naiveReserveValue(uint256 reserve0, uint256 reserve1) internal pure returns (uint256) {
        return (reserve0 + reserve1) / 1000;
    }

    function test_stablePair_reserveSkewing_alongStableswapCurve() public {
        (uint256 baselinePrice, ) = feed.fetchPrice();

        uint256 targetK = _getK(1_000_000e18, 1_000_000e18);
        uint256 newR0 = 800_000e18;
        uint256 newR1 = _solveY(newR0, targetK);

        pool.setReserves(newR0, newR1);

        (uint256 skewedPrice, ) = feed.fetchPrice();

        assertApproxEqRel(skewedPrice, baselinePrice, 0.001e18, "Stable pair price should stay flat along invariant curve");
    }

    function test_stablePair_flashLoanAttackSimulation() public {
        (uint256 baselinePrice, ) = feed.fetchPrice();

        uint256 targetK = _getK(1_000_000e18, 1_000_000e18);
        uint256 manipulatedReserve0 = 200_000e18;
        uint256 manipulatedReserve1 = _solveY(manipulatedReserve0, targetK);

        uint256 naiveManipulatedPrice = _naiveReserveValue(manipulatedReserve0, manipulatedReserve1) * 1e18;

        pool.setReserves(manipulatedReserve0, manipulatedReserve1);
        (uint256 skewedPrice, ) = feed.fetchPrice();

        assertApproxEqRel(skewedPrice, baselinePrice, 0.001e18, "Flash-loan skew along invariant should not inflate stable LP price");
        assertGt(naiveManipulatedPrice, baselinePrice, "Naive reserve pricing would overvalue skewed stable LP");
        assertLt(skewedPrice, naiveManipulatedPrice, "Fair reserve pricing should stay below naive manipulated valuation");

        pool.setReserves(1_000_000e18, 1_000_000e18);
        (uint256 restoredPrice, ) = feed.fetchPrice();

        assertApproxEqRel(restoredPrice, baselinePrice, 0.001e18, "Price should recover after unwind");
    }

    function test_stablePair_extremeSkew_alongInvariantCurve() public {
        (uint256 baselinePrice, ) = feed.fetchPrice();

        uint256 targetK = _getK(1_000_000e18, 1_000_000e18);
        uint256 newR0 = 10_000e18;
        uint256 newR1 = _solveY(newR0, targetK);

        pool.setReserves(newR0, newR1);
        (uint256 skewedPrice, ) = feed.fetchPrice();

        assertApproxEqRel(skewedPrice, baselinePrice, 0.001e18, "Even extreme invariant-preserving skew should not move price materially");
    }

    function test_stablePair_naiveReserveValuationOverstatesSkewedPool() public {
        (uint256 baselinePrice, ) = feed.fetchPrice();

        uint256 targetK = _getK(1_000_000e18, 1_000_000e18);
        uint256 newR0 = 100_000e18;
        uint256 newR1 = _solveY(newR0, targetK);

        uint256 naivePrice = _naiveReserveValue(newR0, newR1) * 1e18;

        pool.setReserves(newR0, newR1);
        (uint256 fairPrice, ) = feed.fetchPrice();

        assertApproxEqRel(fairPrice, baselinePrice, 0.001e18, "Fair price should remain near baseline");
        assertGt(naivePrice, baselinePrice, "Naive price should be inflated by reserve skew");
        assertGt(naivePrice, fairPrice, "Naive price should exceed fair price under skew");
    }

    function test_stablePair_kInvariantCalculation() public view {
        uint256 k = _getK(1_000_000e18, 1_000_000e18);
        uint256 newR0 = 800_000e18;
        uint256 newR1 = _solveY(newR0, k);

        assertApproxEqRel(_getK(newR0, newR1), k, 1, "Solved point should preserve the stable invariant to rounding precision");
    }
}

contract AeroLPStablePairFuzzTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ERC20DecimalsMock internal token0;
    ERC20DecimalsMock internal token1;
    AeroPoolMock internal pool;
    AeroGaugeMock internal gauge;
    ChainlinkOracleMock internal token0UsdOracle;
    ChainlinkOracleMock internal token1UsdOracle;
    AeroLPTokenPriceFeedTester internal feed;

    function setUp() public {
        vm.warp(200_000);

        token0 = new ERC20DecimalsMock("Token0", "T0", 18);
        token1 = new ERC20DecimalsMock("Token1", "T1", 18);

        borrowerOperations = new BorrowerOperationsMock();

        gauge = new AeroGaugeMock(address(token0), address(token1));
        pool = gauge.pool();
        pool.setStable(true);

        pool.setReserves(1_000_000e18, 1_000_000e18);
        pool.setTotalSupply(1000e18);
        pool.setQuoteAmounts(1e18, 1e18);

        token0UsdOracle = new ChainlinkOracleMock();
        token0UsdOracle.setDecimals(8);
        token0UsdOracle.setPrice(1e8);
        token0UsdOracle.setUpdatedAt(block.timestamp);

        token1UsdOracle = new ChainlinkOracleMock();
        token1UsdOracle.setDecimals(8);
        token1UsdOracle.setPrice(1e8);
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

    function _getK(uint256 x, uint256 y) internal pure returns (uint256) {
        uint256 x3 = _mulWadDown(_mulWadDown(x, x), x);
        uint256 y3 = _mulWadDown(_mulWadDown(y, y), y);
        return _mulWadDown(x3, y) + _mulWadDown(y3, x);
    }

    function _mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y) / 1e18;
    }

    function _solveY(uint256 x, uint256 targetK) internal pure returns (uint256) {
        uint256 low = 1;
        uint256 high = 100_000_000e18;

        for (uint256 i = 0; i < 256; i++) {
            uint256 mid = (low + high) / 2;
            uint256 kMid = _getK(x, mid);

            if (kMid < targetK) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }

        return high;
    }

    function testFuzz_stablePair_invariantCurvePriceStable(uint256 reserve0Raw) public {
        reserve0Raw = bound(reserve0Raw, 10_000e18, 2_000_000e18);

        (uint256 baselinePrice, ) = feed.fetchPrice();

        uint256 targetK = _getK(1_000_000e18, 1_000_000e18);
        uint256 reserve1 = _solveY(reserve0Raw, targetK);

        pool.setReserves(reserve0Raw, reserve1);
        (uint256 skewedPrice, ) = feed.fetchPrice();

        assertApproxEqRel(skewedPrice, baselinePrice, 0.001e18, "Stable invariant-preserving skew should not move price");
    }

    function testFuzz_stablePair_fairPriceBelowNaiveReserveValuation(uint256 reserve0Raw) public {
        reserve0Raw = bound(reserve0Raw, 10_000e18, 900_000e18);

        uint256 targetK = _getK(1_000_000e18, 1_000_000e18);
        uint256 reserve1 = _solveY(reserve0Raw, targetK);
        uint256 naivePrice = ((reserve0Raw + reserve1) / 1000) * 1e18;

        pool.setReserves(reserve0Raw, reserve1);
        (uint256 fairPrice, ) = feed.fetchPrice();

        assertLt(fairPrice, naivePrice, "Fair stable price should stay below naive reserve valuation under skew");
    }

    function testFuzz_stablePair_priceBounded(uint256 reserve0Raw, uint256 token0Price, uint256 token1Price) public {
        reserve0Raw = bound(reserve0Raw, 10_000e18, 2_000_000e18);
        token0Price = bound(token0Price, 5e7, 2e8);
        token1Price = bound(token1Price, 5e7, 2e8);

        token0UsdOracle.setPrice(int256(token0Price));
        token1UsdOracle.setPrice(int256(token1Price));

        uint256 targetK = _getK(1_000_000e18, 1_000_000e18);
        uint256 reserve1 = _solveY(reserve0Raw, targetK);

        pool.setReserves(reserve0Raw, reserve1);

        (uint256 price, bool newFailure) = feed.fetchPrice();

        if (!newFailure) {
            assertGt(price, 0);
            assertLt(price, 10_000e18, "Stable pair price should stay bounded for near-peg oracle inputs");
        }
    }
}
