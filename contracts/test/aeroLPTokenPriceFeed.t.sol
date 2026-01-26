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
        pool.setCumulativePrices(1, 1, block.timestamp);

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
            1 days,
            1 hours
        );
    }

    function test_getCumulativePrices_scalesByTokenDecimals() public {
        pool.setCumulativePrices(
            123_456, // token0 cumulative price in token0 decimals
            789, // token1 cumulative price in token1 decimals
            block.timestamp
        );

        (uint256 p0, uint256 p1, bool isStale) = feed.i_getCumulativePrices();

        // _scaleCumulativePriceTo18decimals(_price, _decimals) = _price * 10 ** (18 - _decimals)
        assertEq(p0, 123_456 * 10 ** (18 - 6));
        assertEq(p1, 789 * 10 ** (18 - 18));
        assertFalse(isStale);
    }

    function test_getCumulativePrices_staleWhenTimestampExceedsThreshold() public {
        // poolStalenessThreshold = 1 hour
        vm.warp(10_000);
        pool.setCumulativePrices(1, 1, block.timestamp - 1 hours - 1);

        (, , bool isStale) = feed.i_getCumulativePrices();
        assertTrue(isStale);
    }

    function test_getCumulativePrices_notStaleAtExactThreshold() public {
        vm.warp(10_000);
        pool.setCumulativePrices(1, 1, block.timestamp - 1 hours);

        (, , bool isStale) = feed.i_getCumulativePrices();
        assertFalse(isStale);
    }

    function test_getCumulativePrices_returnsZerosOnPoolRevert() public {
        pool.setShouldRevert(true);

        (uint256 p0, uint256 p1, bool isStale) = feed.i_getCumulativePrices();
        assertEq(p0, 0);
        assertEq(p1, 0);
        assertTrue(isStale);
    }

    function test_fetchPrice_shutsDownAndReturnsLastGoodPrice_whenPoolCumulativePriceIsStale() public {
        // First: produce a known lastGoodPrice (healthy path)
        pool.setCumulativePrices(100e6, 200e18, block.timestamp);
        token0UsdOracle.setPrice(100e8);
        token0UsdOracle.setUpdatedAt(block.timestamp);
        token1UsdOracle.setPrice(200e8);
        token1UsdOracle.setUpdatedAt(block.timestamp);

        (uint256 lastGoodBefore, bool newFailureBefore) = feed.fetchPrice();
        assertFalse(newFailureBefore);
        assertEq(lastGoodBefore, feed.lastGoodPrice());
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.primary));

        // Now: make pool stale -> should shut down and return lastGoodPrice
        pool.setCumulativePrices(100e6, 200e18, block.timestamp - 1 hours - 1);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        vm.expectEmit();
        emit AeroLPTokenPriceFeedBase.ShutDownFromOracleFailure(address(pool));
        (uint256 price, bool newFailure) = feed.fetchPrice();

        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
        assertEq(feed.lastGoodPrice(), lastGoodBefore);
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.lastGoodPrice));
    }

    function test_fetchPrice_shutsDownAndReturnsLastGoodPrice_whenToken0OracleIsDown() public {
        // Healthy baseline: set a non-trivial lastGoodPrice
        pool.setCumulativePrices(100e6, 200e18, block.timestamp);
        token0UsdOracle.setPrice(100e8);
        token0UsdOracle.setUpdatedAt(block.timestamp);
        token1UsdOracle.setPrice(200e8);
        token1UsdOracle.setUpdatedAt(block.timestamp);

        (uint256 lastGoodBefore, bool newFailureBefore) = feed.fetchPrice();
        assertFalse(newFailureBefore);
        assertEq(lastGoodBefore, feed.lastGoodPrice());
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.primary));

        // Make token0 oracle stale (down)
        token0UsdOracle.setUpdatedAt(block.timestamp - 2 days);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        vm.expectEmit();
        emit AeroLPTokenPriceFeedBase.ShutDownFromOracleFailure(address(token0UsdOracle));
        (uint256 price, bool newFailure) = feed.fetchPrice();

        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
        assertEq(feed.lastGoodPrice(), lastGoodBefore);
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.lastGoodPrice));
    }

    function test_fetchPrice_shutsDownAndReturnsLastGoodPrice_whenToken1OracleIsDown() public {
        // Healthy baseline: set a non-trivial lastGoodPrice
        pool.setCumulativePrices(100e6, 200e18, block.timestamp);
        token0UsdOracle.setPrice(100e8);
        token0UsdOracle.setUpdatedAt(block.timestamp);
        token1UsdOracle.setPrice(200e8);
        token1UsdOracle.setUpdatedAt(block.timestamp);

        (uint256 lastGoodBefore, bool newFailureBefore) = feed.fetchPrice();
        assertFalse(newFailureBefore);
        assertEq(lastGoodBefore, feed.lastGoodPrice());
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.primary));

        // Make token1 oracle stale (down)
        token1UsdOracle.setUpdatedAt(block.timestamp - 2 days);

        vm.expectCall(address(borrowerOperations), abi.encodeWithSignature("shutdownFromOracleFailure()"));
        vm.expectEmit();
        emit AeroLPTokenPriceFeedBase.ShutDownFromOracleFailure(address(token1UsdOracle));
        (uint256 price, bool newFailure) = feed.fetchPrice();

        assertTrue(newFailure);
        assertEq(price, lastGoodBefore);
        assertEq(feed.lastGoodPrice(), lastGoodBefore);
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.lastGoodPrice));
    }

    function test_fetchRedemptionPrice_withinDeviation_usesMaxMinLogic() public {
        // Pool prices (scaled inside feed):
        // - token0 decimals = 6  => token0Price = token0Cum * 1e12
        // - token1 decimals = 18 => token1Price = token1Cum
        pool.setCumulativePrices(100e6, 200e18, block.timestamp);

        // Oracle prices (8 decimals): scaled to 1e18 inside feed
        // Within 2% deviation for both:
        // - token0 oracle lower than pool (uses MIN on redemption)
        // - token1 oracle higher than pool (uses MAX on redemption)
        token0UsdOracle.setPrice(99e8);
        token0UsdOracle.setUpdatedAt(block.timestamp);
        token1UsdOracle.setPrice(202e8);
        token1UsdOracle.setUpdatedAt(block.timestamp);

        (uint256 price, bool newFailure) = feed.fetchRedemptionPrice();
        assertFalse(newFailure);

        uint256 token0Used = 99e18; // min(100, 99)
        uint256 token1Used = 202e18; // max(200, 202)
        uint256 expected = token1Used * 1e18 / token0Used;

        assertEq(price, expected);
        assertEq(feed.lastGoodPrice(), expected);
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.primary));
    }

    function test_fetchRedemptionPrice_outsideDeviation_usesMinMaxLogic() public {
        pool.setCumulativePrices(100e6, 200e18, block.timestamp);

        // Make token0 deviate >2% => withinPriceDeviationThreshold == false
        token0UsdOracle.setPrice(120e8); // 20% above pool token0 price
        token0UsdOracle.setUpdatedAt(block.timestamp);
        token1UsdOracle.setPrice(198e8); // within 2% but irrelevant due to AND condition
        token1UsdOracle.setUpdatedAt(block.timestamp);

        (uint256 price, bool newFailure) = feed.fetchRedemptionPrice();
        assertFalse(newFailure);

        uint256 token0Used = 120e18; // max(100, 120)
        uint256 token1Used = 198e18; // min(200, 198)
        uint256 expected = token1Used * 1e18 / token0Used;

        assertEq(price, expected);
        assertEq(feed.lastGoodPrice(), expected);
        assertEq(uint8(feed.priceSource()), uint8(AeroLPTokenPriceFeedBase.PriceSource.primary));
    }
}

