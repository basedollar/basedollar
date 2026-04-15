// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "src/PriceFeeds/AEROPriceFeed.sol";
import "src/PriceFeeds/TokenPriceFeedBase.sol";

import "./PriceFeedTestHelpers.sol";
import "../TestContracts/ChainlinkOracleMock.sol";

contract AEROPriceFeedTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ChainlinkOracleMock internal tokenUsd;
    AEROPriceFeed internal feed;

    function _deployWithDecimals(uint8 decimals) internal {
        borrowerOperations = new BorrowerOperationsMock();
        tokenUsd = new ChainlinkOracleMock();
        tokenUsd.setDecimals(decimals);
        if (decimals == 8) {
            tokenUsd.setPrice(5e7); // $0.50
        } else {
            tokenUsd.setPrice(5e17); // $0.50 at 18 decimals
        }
        tokenUsd.setUpdatedAt(block.timestamp);
        feed = new AEROPriceFeed(address(borrowerOperations), address(tokenUsd), 1 days);
    }

    function setUp() public {
        vm.warp(200_000);
        _deployWithDecimals(8);
    }

    function test_fetchPrice_happyPath_8decimals() public {
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        assertEq(p, 5e17); // 0.5 USD scaled to 18 decimals
        assertEq(feed.lastGoodPrice(), p);
        assertEq(uint8(feed.priceSource()), uint8(TokenPriceFeedBase.PriceSource.primary));
    }

    function test_fetchPrice_happyPath_18decimals() public {
        _deployWithDecimals(18);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        assertEq(p, 5e17);
    }

    function test_stale_shutsDown() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        tokenUsd.setUpdatedAt(block.timestamp - 2 days);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
        assertEq(uint8(feed.priceSource()), uint8(TokenPriceFeedBase.PriceSource.lastGoodPrice));
    }

    function test_afterShutdown_fetchPrice_returnsLastGood() public {
        feed.fetchPrice();
        tokenUsd.setUpdatedAt(block.timestamp - 2 days);
        feed.fetchPrice();
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        assertEq(p, feed.lastGoodPrice());
    }
}
