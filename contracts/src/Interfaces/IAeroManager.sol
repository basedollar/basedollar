// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ICollateralRegistry.sol";

interface IAeroManager {

    event AeroTokenAddressUpdated(address _aeroTokenAddress);
    event GovernorUpdated(address _governor);

    function setAeroTokenAddress(address _aeroTokenAddress) external;
    function setGovernor(address _governor) external;
    function addActivePool(address activePool) external;
    function stake(address gauge, address token, uint256 amount) external;
    function withdraw(address gauge, address token, uint256 amount) external;
    function claim(address gauge) external;
    function setAddresses(ICollateralRegistry _collateralRegistry) external;
}