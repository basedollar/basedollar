// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Shared fixtures for fork-free price feed unit tests. These tests exercise `src/PriceFeeds/*`
///      with `ChainlinkOracleMock` so `forge test` / `forge coverage` do not require `MAINNET_RPC_URL`.
///      [OracleMainnet.t.sol](../OracleMainnet.t.sol) remains optional fork integration.

import "src/Dependencies/AggregatorV3Interface.sol";
import "src/Interfaces/IWSTETH.sol";

/// @dev Same pattern as `aeroLPTokenPriceFeed.t.sol` — no-op shutdown hook for price feed tests.
contract BorrowerOperationsMock {
    function shutdownFromOracleFailure() external {}
}

/// @dev `latestRoundData` always reverts (enough gas path → oracle treated as down, not InsufficientGas).
contract RevertingAggregator is AggregatorV3Interface {
    uint8 internal immutable _decimals;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        pure
        returns (uint80, int256, uint256, uint256, uint80)
    {
        revert();
    }
}

/// @dev Mutable `stEthPerToken()` for [WSTETHPriceFeed.t.sol](WSTETHPriceFeed.t.sol); production tests use mainnet fork.
contract WSTETHRateMock is IWSTETH {
    uint256 public stEthPerTokenVal = 1.15e18;

    function setStEthPerToken(uint256 v) external {
        stEthPerTokenVal = v;
    }

    function stEthPerToken() external view returns (uint256) {
        return stEthPerTokenVal;
    }

    function wrap(uint256 _stETHAmount) external pure returns (uint256) {
        return _stETHAmount;
    }

    function unwrap(uint256 _wstETHAmount) external pure returns (uint256) {
        return _wstETHAmount;
    }

    function getWstETHByStETH(uint256 _stETHAmount) external pure returns (uint256) {
        return _stETHAmount;
    }

    function getStETHByWstETH(uint256 _wstETHAmount) external pure returns (uint256) {
        return _wstETHAmount;
    }

    function tokensPerStEth() external pure returns (uint256) {
        return 0;
    }
}
