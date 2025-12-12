// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAeroManager {

    event AeroTokenAddressUpdated(address _aeroTokenAddress);
    event GovernorUpdated(address _governor);

    function setAeroTokenAddress(address _aeroTokenAddress) external;
    function setGovernor(address _governor) external;
}