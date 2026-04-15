// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "src/PriceFeeds/cbBTCPriceFeed.sol";
import "src/Interfaces/IMainnetPriceFeed.sol";

import "./PriceFeedTestHelpers.sol";
import "../TestContracts/ChainlinkOracleMock.sol";

contract cbBTCPriceFeedTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ChainlinkOracleMock internal cbBtcUsd;
    ChainlinkOracleMock internal btcUsd;
    cbBTCPriceFeed internal feed;

    function setUp() public {
        vm.warp(200_000);
        borrowerOperations = new BorrowerOperationsMock();
        cbBtcUsd = new ChainlinkOracleMock();
        cbBtcUsd.setDecimals(8);
        cbBtcUsd.setPrice(100_000e8);
        cbBtcUsd.setUpdatedAt(block.timestamp);

        btcUsd = new ChainlinkOracleMock();
        btcUsd.setDecimals(8);
        btcUsd.setPrice(100_500e8); // +0.5% vs cbBTC — within 2% for redemption comparison
        btcUsd.setUpdatedAt(block.timestamp);

        feed = new cbBTCPriceFeed(
            address(borrowerOperations),
            address(cbBtcUsd),
            address(btcUsd),
            1 days,
            1 days
        );
    }

    function test_fetchPrice_nonRedemption_takesMin() public {
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        assertEq(p, 100_000e18);
    }

    function test_fetchRedemptionPrice_withinDeviation_takesMax() public {
        (uint256 p, bool failed) = feed.fetchRedemptionPrice();
        assertFalse(failed);
        assertEq(p, 100_500e18);
    }

    function test_cbBtcOracleDown_shutsDown() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        cbBtcUsd.setUpdatedAt(block.timestamp - 2 days);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
    }

    function test_btcOracleDown_shutsDown() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        btcUsd.setUpdatedAt(block.timestamp - 2 days);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
    }

    function test_afterShutdown_fetchPrice_returnsLastGood() public {
        feed.fetchPrice();
        btcUsd.setUpdatedAt(block.timestamp - 2 days);
        feed.fetchPrice();
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        assertEq(p, feed.lastGoodPrice());
    }
}
