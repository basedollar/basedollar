// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "src/PriceFeeds/WSTETHPriceFeed.sol";
import "src/Interfaces/IMainnetPriceFeed.sol";

import "./PriceFeedTestHelpers.sol";
import "../TestContracts/ChainlinkOracleMock.sol";

contract WSTETHPriceFeedTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ChainlinkOracleMock internal ethUsd;
    ChainlinkOracleMock internal stEthUsd;
    WSTETHRateMock internal wsteth;
    WSTETHPriceFeed internal feed;

    function setUp() public {
        vm.warp(200_000);
        borrowerOperations = new BorrowerOperationsMock();
        ethUsd = new ChainlinkOracleMock();
        ethUsd.setDecimals(8);
        ethUsd.setPrice(2000e8);
        ethUsd.setUpdatedAt(block.timestamp);

        stEthUsd = new ChainlinkOracleMock();
        stEthUsd.setDecimals(8);
        stEthUsd.setPrice(2005e8);
        stEthUsd.setUpdatedAt(block.timestamp);

        wsteth = new WSTETHRateMock();
        wsteth.setStEthPerToken(1.1e18);

        feed = new WSTETHPriceFeed(
            address(ethUsd),
            address(stEthUsd),
            address(wsteth),
            1 days,
            1 days,
            address(borrowerOperations)
        );
    }

    function test_fetchPrice_nonRedemption_usesStEthTimesRate() public {
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        // 2005e18 * 1.1e18 / 1e18 = 2205.5e18
        assertEq(p, 2005e18 * 11 / 10);
    }

    function test_fetchRedemptionPrice_withinOnePercent_usesMaxThenWrap() public {
        (uint256 p, bool failed) = feed.fetchRedemptionPrice();
        assertFalse(failed);
        // max(2005e18, 2000e18) * 1.1e18 / 1e18
        assertEq(p, 2005e18 * 11 / 10);
    }

    function test_exchangeRateZero_shutsDown() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        wsteth.setStEthPerToken(0);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
    }

    function test_ethUsdDown_shutsDown() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        ethUsd.setUpdatedAt(block.timestamp - 2 days);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
    }

    function test_stEthUsdDown_switchesToETHUSDxCanonical() public {
        feed.fetchPrice();
        stEthUsd.setUpdatedAt(block.timestamp - 2 days);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.ETHUSDxCanonical));
        assertGt(p, 0);
    }

    function test_ETHUSDxCanonical_then_ethStale_movesToLastGood() public {
        feed.fetchPrice();
        stEthUsd.setUpdatedAt(block.timestamp - 2 days);
        feed.fetchPrice();
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.ETHUSDxCanonical));
        // Canonical step sets lastGood to min(ETH_USD * rate, prior lastGood) = min(2200e18, 2205.5e18)
        uint256 lgpAfterCanonical = feed.lastGoodPrice();
        assertEq(lgpAfterCanonical, 2200e18);

        ethUsd.setUpdatedAt(block.timestamp - 2 days);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
        assertEq(p, lgpAfterCanonical);
    }
}
