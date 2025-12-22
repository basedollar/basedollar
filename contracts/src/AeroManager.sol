// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "./Interfaces/IActivePool.sol";
import "./Interfaces/ICollateralRegistry.sol";
import "./Interfaces/IAeroManager.sol";

contract AeroManager is IAeroManager {

    ICollateralRegistry public immutable collateralRegistry;
    address public aeroTokenAddress;
    address public governor;

    address public rewardManager; // can send claimed AERO to people using offchain data

    event RewardManagerUpdated(address _oldRewardManager, address _newRewardManager);

    constructor(ICollateralRegistry _collateralRegistry, address _aeroTokenAddress, address _governor, address _rewardManager) {
        collateralRegistry = _collateralRegistry;
        aeroTokenAddress = _aeroTokenAddress;
        governor = _governor;
        rewardManager = _rewardManager;
    }
    //Manage Aero, Interact with gauges, anything else we need to do here.

    //admin functions
    function setAeroTokenAddress(address _aeroTokenAddress) external onlyGovernor {
        aeroTokenAddress = _aeroTokenAddress;
        emit AeroTokenAddressUpdated(_aeroTokenAddress);
    }

    function setGovernor(address _governor) external onlyGovernor {
        governor = _governor;
        emit GovernorUpdated(_governor);
    }

    function setRewardManager(address _rewardManager) external onlyGovernor {
        require(_rewardManager != rewardManager, "AeroManager: Reward manager is already set");
        address oldRewardManager = rewardManager;
        rewardManager = _rewardManager;
        emit RewardManagerUpdated(oldRewardManager, _rewardManager);
    }

    //require functions
    modifier onlyGovernor() {
        require(msg.sender == governor, "AeroManager: Caller is not the governor");
        _;
    }

    //TODO vote with AERO tokens on any gauges that governance chooses.

    function requireCallerIsRewardManager() internal view {
        require(msg.sender == rewardManager, "AeroManager: Caller is not the reward manager");
        _;
    }
}