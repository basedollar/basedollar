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

contract AeroLPTokenPriceFeedTest is Test {
    ERC20DecimalsMock internal token0;
    ERC20DecimalsMock internal token1;
    AeroPoolMock internal pool;
    AeroGaugeMock internal gauge;
    ChainlinkOracleMock internal token0UsdOracle;
    ChainlinkOracleMock internal token1UsdOracle;
    AeroLPTokenPriceFeedTester internal feed;

    function setUp() public {
        token0 = new ERC20DecimalsMock("Token0", "T0", 6); // e.g. USDC-like
        token1 = new ERC20DecimalsMock("Token1", "T1", 18); // e.g. WETH-like

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
            address(0xB0),
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
}

