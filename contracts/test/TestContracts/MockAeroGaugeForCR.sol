// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./MockAeroVoter.sol";

/// @dev Minimal gauge stub for branch validation, including AeroManager's voter-based reward token lookup.
contract MockAeroGaugeForCR {
    address public immutable stakingToken;
    address public immutable rewardTokenAddr;
    MockAeroVoter public immutable aeroVoter;

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = _stakingToken;
        rewardTokenAddr = _rewardToken;
        aeroVoter = new MockAeroVoter();
        aeroVoter.setRewardToken(_rewardToken);
    }

    function voter() external view returns (address) {
        return address(aeroVoter);
    }

    function rewardToken() external view returns (address) {
        return rewardTokenAddr;
    }
}
