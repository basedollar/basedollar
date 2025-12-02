// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "./Interfaces/IActivePool.sol";
import "./Interfaces/ICollateralRegistry.sol";
import "./Interfaces/IAeroManager.sol";

contract AeroManager is IAeroManager {

    ICollateralRegistry public immutable collateralRegistry;
    address public aeroTokenAddress;
    address public governor;

    event AeroTokenAddressUpdated(address _aeroTokenAddress);
    event GovernorUpdated(address _governor);
    event AeroGaugeAddressUpdated(address _activePoolAddress, address _aeroGaugeAddress);

    constructor(ICollateralRegistry _collateralRegistry, address _aeroTokenAddress, address _governor) {
        collateralRegistry = _collateralRegistry;
        aeroTokenAddress = _aeroTokenAddress;
        governor = _governor;
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

    //require functions
    modifier onlyGovernor() {
        require(msg.sender == governor, "AeroManager: Caller is not the governor");
        _;
    }

    //TODO vote with AERO tokens on any gauges that governance chooses.
}