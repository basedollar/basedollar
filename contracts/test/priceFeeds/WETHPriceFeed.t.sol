// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "src/PriceFeeds/WETHPriceFeed.sol";
import "src/Interfaces/IMainnetPriceFeed.sol";

import "./PriceFeedTestHelpers.sol";
import "../TestContracts/ChainlinkOracleMock.sol";

contract WETHPriceFeedTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ChainlinkOracleMock internal ethUsd;
    WETHPriceFeed internal feed;

    function setUp() public {
        vm.warp(200_000);
        borrowerOperations = new BorrowerOperationsMock();
        ethUsd = new ChainlinkOracleMock();
        ethUsd.setDecimals(8);
        ethUsd.setPrice(2000e8);
        ethUsd.setUpdatedAt(block.timestamp);

        feed = new WETHPriceFeed(address(ethUsd), 1 days, address(borrowerOperations));
    }

    function test_fetchPrice_happyPath_updatesLastGood() public {
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        assertEq(p, 2000e18);
        assertEq(feed.lastGoodPrice(), 2000e18);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.primary));
    }

    function test_fetchRedemptionPrice_matches_fetchPrice() public {
        (uint256 p1,) = feed.fetchPrice();
        (uint256 p2,) = feed.fetchRedemptionPrice();
        assertEq(p1, p2);
    }

    function test_staleOracle_shutsDown_returnsLastGood() public {
        feed.fetchPrice();
        uint256 beforeLgp = feed.lastGoodPrice();
        assertGt(beforeLgp, 0);

        ethUsd.setUpdatedAt(block.timestamp - 2 days);

        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, beforeLgp);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
    }

    function test_afterShutdown_secondFetch_noNewFailureFlag() public {
        feed.fetchPrice();
        ethUsd.setUpdatedAt(block.timestamp - 2 days);
        feed.fetchPrice();

        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        assertEq(p, feed.lastGoodPrice());
    }

    function test_zeroAnswer_shutsDown() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        ethUsd.setPrice(0);
        ethUsd.setUpdatedAt(block.timestamp);

        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
    }

    function test_negativeAnswer_shutsDown() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        ethUsd.setPrice(-1);
        ethUsd.setUpdatedAt(block.timestamp);

        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
    }

    function test_revertingOracle_shutsDown_afterEtch() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();

        RevertingAggregator bad = new RevertingAggregator(8);
        vm.etch(address(ethUsd), address(bad).code);

        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
    }
}
