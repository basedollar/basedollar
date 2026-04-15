// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "src/PriceFeeds/RETHPriceFeed.sol";
import "src/Interfaces/IMainnetPriceFeed.sol";

import "./PriceFeedTestHelpers.sol";
import "../TestContracts/ChainlinkOracleMock.sol";
import "../TestContracts/RETHTokenMock.sol";

/// @dev Lets us flip `getExchangeRate()` to revert after a successful constructor `fetch`.
contract ToggleRethToken {
    bool public fail;
    uint256 public rate = 1e18;

    function setFail(bool f) external {
        fail = f;
    }

    function setRate(uint256 r) external {
        rate = r;
    }

    function getExchangeRate() external view returns (uint256) {
        if (fail) revert();
        return rate;
    }
}

contract RETHPriceFeedTest is Test {
    BorrowerOperationsMock internal borrowerOperations;
    ChainlinkOracleMock internal ethUsd;
    ChainlinkOracleMock internal rEthEth;
    RETHTokenMock internal rethToken;
    RETHPriceFeed internal feed;

    function setUp() public {
        vm.warp(200_000);
        borrowerOperations = new BorrowerOperationsMock();
        ethUsd = new ChainlinkOracleMock();
        ethUsd.setDecimals(8);
        ethUsd.setPrice(2000e8);
        ethUsd.setUpdatedAt(block.timestamp);

        rEthEth = new ChainlinkOracleMock();
        rEthEth.setDecimals(8);
        rEthEth.setPrice(1e8); // 1 ETH per RETH
        rEthEth.setUpdatedAt(block.timestamp);

        rethToken = new RETHTokenMock();
        rethToken.setExchangeRate(1e18);

        feed = new RETHPriceFeed(
            address(ethUsd),
            address(rEthEth),
            address(rethToken),
            1 days,
            1 days,
            address(borrowerOperations)
        );
    }

    function test_fetchPrice_primary_minOfMarketAndCanonical() public {
        rethToken.setExchangeRate(1e18);
        rEthEth.setPrice(1.1e8); // 1.1 ETH per RETH → higher market USD
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        // min(2200e18, 2000e18) = 2000e18
        assertEq(p, 2000e18);
    }

    function test_fetchRedemptionPrice_maxWhenWithinDeviation() public {
        rethToken.setExchangeRate(1e18);
        rEthEth.setPrice(1.005e8); // 0.5% above canonical ETH/RETH
        (uint256 p, bool failed) = feed.fetchRedemptionPrice();
        assertFalse(failed);
        // max(2010e18, 2000e18) = 2010e18
        assertEq(p, 2010e18);
    }

    function test_ethUsdDown_shutsDownToLastGood() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        ethUsd.setUpdatedAt(block.timestamp - 2 days);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
    }

    function test_exchangeRateZero_shutsDown() public {
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        rethToken.setExchangeRate(0);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
    }

    function test_exchangeRateRevert_shutsDown() public {
        ToggleRethToken toggle = new ToggleRethToken();
        feed = new RETHPriceFeed(
            address(ethUsd),
            address(rEthEth),
            address(toggle),
            1 days,
            1 days,
            address(borrowerOperations)
        );
        feed.fetchPrice();
        uint256 lgp = feed.lastGoodPrice();
        toggle.setFail(true);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(p, lgp);
    }

    function test_rEthEthOracleDown_switchesToETHUSDxCanonical() public {
        feed.fetchPrice();
        rEthEth.setUpdatedAt(block.timestamp - 2 days);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertTrue(failed);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.ETHUSDxCanonical));
        assertGt(p, 0);
        // canonical USD/RETH = ethUsd * canonical rate / 1e18 = 2000e18 * 1e18 / 1e18
        assertEq(p, 2000e18);
    }

    function test_ETHUSDxCanonical_then_ethFails_usesLastGood() public {
        feed.fetchPrice();
        uint256 lgpAfterPrimary = feed.lastGoodPrice();
        rEthEth.setUpdatedAt(block.timestamp - 2 days);
        feed.fetchPrice();
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.ETHUSDxCanonical));

        ethUsd.setUpdatedAt(block.timestamp - 2 days);
        (uint256 p, bool failed) = feed.fetchPrice();
        assertFalse(failed);
        assertEq(uint8(feed.priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
        assertEq(p, lgpAfterPrimary);
    }
}
