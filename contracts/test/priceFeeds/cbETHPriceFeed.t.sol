// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "src/PriceFeeds/cbETHPriceFeed.sol";
import "src/Interfaces/IMainnetPriceFeed.sol";

import "./PriceFeedTestHelpers.sol";
import "../TestContracts/ChainlinkOracleMock.sol";

contract cbETHPriceFeedTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ChainlinkOracleMock internal ethUsd;
    ChainlinkOracleMock internal cbEthEth;
    cbETHPriceFeed internal feed;

    function setUp() public {
        vm.warp(200_000);
        borrowerOperations = new BorrowerOperationsMock();
        ethUsd = new ChainlinkOracleMock();
        ethUsd.setDecimals(8);
        ethUsd.setPrice(2000e8);
        ethUsd.setUpdatedAt(block.timestamp);

        cbEthEth = new ChainlinkOracleMock();
        cbEthEth.setDecimals(8);
        cbEthEth.setPrice(1.05e8); // 1.05 ETH per cbETH
        cbEthEth.setUpdatedAt(block.timestamp);

        feed = new cbETHPriceFeed(
            address(borrowerOperations),
            address(ethUsd),
            address(cbEthEth),
            1 days,
            1 days
        );
    }

    function test_fetchPrice_product() public {
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        // 2000e18 * 1.05e18 / 1e18 = 2100e18
        assertEq(p, 2100e18);
        assertEq(feed.lastGoodPrice(), p);
    }

    function test_fetchRedemptionPrice_matches_fetchPrice() public {
        (uint256 a,) = feed.fetchPrice();
        (uint256 b,) = feed.fetchRedemptionPrice();
        assertEq(a, b);
    }

    function test_constructor_revertsIfCbEthEthDecimalsNot8() public {
        ChainlinkOracleMock badDec = new ChainlinkOracleMock();
        badDec.setDecimals(18);
        badDec.setPrice(1.05e18);
        badDec.setUpdatedAt(block.timestamp);

        vm.expectRevert(bytes("cbETHPriceFeed: cbETH-ETH oracle must have 8 decimals"));
        new cbETHPriceFeed(
            address(borrowerOperations),
            address(ethUsd),
            address(badDec),
            1 days,
            1 days
        );
    }

    function test_cbEthEthOracleDown_shutsDown() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        cbEthEth.setUpdatedAt(block.timestamp - 2 days);
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
    }
}
