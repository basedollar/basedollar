// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Minimal gauge stub: `ActivePool` checks `stakingToken` / `rewardToken`; `AeroManager._addActivePool` requires both.
contract MockAeroGaugeForCR {
    address public immutable stakingToken;
    address public immutable rewardTokenAddr;

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = _stakingToken;
        rewardTokenAddr = _rewardToken;
    }

    function rewardToken() external view returns (address) {
        return rewardTokenAddr;
    }
}
