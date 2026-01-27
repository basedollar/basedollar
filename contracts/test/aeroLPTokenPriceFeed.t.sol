// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

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
        // quote() returns how many token1 for 1 token0 (in token1 decimals)
        pool.setQuoteAmountOut(0.0005e18); // 0.0005 WETH per USDC

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

    // ============ TWAP Exchange Rate Tests ============

    function test_getTwapExchangeRate_scalesCorrectly() public {
        // quote returns 0.0005e18 (token1 has 18 decimals)
        // Scaled to 18 decimals: 0.0005e18 * 10^(18-18) = 0.0005e18
        (uint256 rate, bool isDown) = feed.i_getTwapExchangeRate();
        
        assertEq(rate, 0.0005e18);
        assertFalse(isDown);
    }

    function test_getTwapExchangeRate_returnsDownOnRevert() public {
        pool.setShouldRevert(true);

        (uint256 rate, bool isDown) = feed.i_getTwapExchangeRate();
        assertEq(rate, 0);
        assertTrue(isDown);
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

    // ============ LP Token Price Calculation Tests ============

    function test_calculateLPTokenPrice_basicCalculation() public {
        // Pool has: 1M USDC @ $1 + 500 WETH @ $2000 = $1M + $1M = $2M total
        // 1000 LP tokens -> each LP = $2000
        uint256 price = feed.i_calculateLPTokenPrice(
            1_000_000e6,  // reserve0 (USDC)
            500e18,       // reserve1 (WETH)
            1000e18,      // totalSupply
            1e18,         // token0Price ($1)
            2000e18       // token1Price ($2000)
        );

        assertEq(price, 2000e18);
    }

    function test_calculateLPTokenPrice_asymmetricReserves() public {
        // Pool has: 2M USDC @ $1 + 250 WETH @ $2000 = $2M + $0.5M = $2.5M total
        // 1000 LP tokens -> each LP = $2500
        uint256 price = feed.i_calculateLPTokenPrice(
            2_000_000e6,  // reserve0 (USDC)
            250e18,       // reserve1 (WETH)
            1000e18,      // totalSupply
            1e18,         // token0Price ($1)
            2000e18       // token1Price ($2000)
        );

        assertEq(price, 2500e18);
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

        // Total value: 100 * $1 + 0.05 * $2000 = $100 + $100 = $200
        // Per LP: $200 / 10 = $20
        assertEq(price, 20e18);
    }

    // ============ fetchPrice Tests ============

    function test_fetchPrice_calculatesCorrectLPPrice() public {
        // With setup values:
        // - 1M USDC @ $1 = $1M
        // - 500 WETH @ $2000 = $1M  
        // - Total = $2M, 1000 LP tokens
        // - LP price = $2000
        (uint256 price, bool newFailure) = feed.fetchPrice();
        
        assertFalse(newFailure);
        assertEq(price, 2000e18);
        assertEq(feed.lastGoodPrice(), 2000e18);
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
        pool.setQuoteAmountOut(0.0004e18);

        (uint256 price, bool newFailure) = feed.fetchPrice();
        assertFalse(newFailure);

        // For non-redemption (borrow): uses conservative prices
        // token0Price = max(market, oracle) = max($1, $1) = $1 (same, since token0 is base)
        // token1MarketPrice = $1 / 0.0004 = $2500
        // token1Price = min(market, oracle) = min($2500, $2000) = $2000
        // LP value = (1M * $1 + 500 * $2000) / 1000 = $2M / 1000 = $2000
        assertEq(price, 2000e18);
    }

    function test_fetchRedemptionPrice_withinDeviation_usesMaxMinLogic() public {
        // Set TWAP within 2% of Chainlink
        // TWAP: 1 USDC = 0.000505 WETH (implies WETH = $1980.20, ~1% below $2000)
        pool.setQuoteAmountOut(0.000505e18);

        (uint256 price, bool newFailure) = feed.fetchRedemptionPrice();
        assertFalse(newFailure);

        // For redemption within threshold: maximize LP value
        // token0Price = min(market, oracle) = min($1, $1) = $1
        // token1MarketPrice = $1 / 0.000505 ≈ $1980.20
        // token1Price = max(market, oracle) = max($1980.20, $2000) = $2000
        // LP value = (1M * $1 + 500 * $2000) / 1000 = $2M / 1000 = $2000
        assertEq(price, 2000e18);
    }

    function test_fetchRedemptionPrice_outsideDeviation_usesMinMaxLogic() public {
        // Set TWAP to deviate from Chainlink by >2%
        // TWAP: 1 USDC = 0.0004 WETH (implies WETH = $2500, 25% above $2000)
        pool.setQuoteAmountOut(0.0004e18);

        (uint256 price, bool newFailure) = feed.fetchRedemptionPrice();
        assertFalse(newFailure);

        // Outside threshold: same as non-redemption (conservative)
        // token1Price = min($2500, $2000) = $2000
        assertEq(price, 2000e18);
    }

    function test_fetchRedemptionPrice_withinDeviation_higherLPValue() public {
        // Set up a scenario where TWAP gives higher token1 price than Chainlink
        // but WITHIN the 2% deviation threshold
        // TWAP: 1 USDC = 0.000495 WETH (implies WETH = $2020.20, ~1% above $2000)
        // Deviation = (2020.20 - 2000) / 2000 = 1.01% < 2%
        pool.setQuoteAmountOut(0.000495e18);

        (uint256 redemptionPrice, ) = feed.fetchRedemptionPrice();
        
        // Reset quote to get borrow price with same TWAP
        pool.setQuoteAmountOut(0.000495e18);
        (uint256 borrowPrice, ) = feed.fetchPrice();

        // Calculate expected values:
        // TWAP-derived token1 market price = $1 / 0.000495 = $2020.20
        // Chainlink token1 price = $2000
        //
        // Redemption (within 2% threshold): max(2020.20, 2000) = 2020.20
        // Borrow: min(2020.20, 2000) = 2000
        //
        // LP value with reserves (1M USDC, 500 WETH) and 1000 LP tokens:
        // Redemption: (1M * $1 + 500 * $2020.20) / 1000 = (1M + 1.0101M) / 1000 = $2010.10
        // Borrow: (1M * $1 + 500 * $2000) / 1000 = (1M + 1M) / 1000 = $2000
        
        assertGt(redemptionPrice, borrowPrice, "Redemption price should be higher than borrow price");
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
}
