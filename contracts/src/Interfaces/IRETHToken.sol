// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

interface IRETHToken {
    // Unusable on Base
    function getExchangeRate() external view returns (uint256);
    
    // RocketOvmPriceOracle interface functions
    // Source: https://github.com/rocket-pool/rocketpool-ovm-oracle

    /// @notice The rETH exchange rate in the form of how much ETH 1 rETH is worth
    function rate() external view returns (uint256);

    /// @notice The timestamp of the block in which the rate was last updated
    function lastUpdated() external view returns (uint256);
}
