// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ICollateralRegistry.sol";

interface IAeroManager {
    function stakedAmounts(address gauge) external view returns (uint256);
    function setAeroTokenAddress(address _aeroTokenAddress) external;
    function addActivePool(address activePool) external;
    // function stake(address gauge, address token, uint256 amount) external;
    // function withdraw(address gauge, address token, uint256 amount) external;
    // function claim(address gauge) external;
    function claimTroveEmissions(address activePool, uint256 maxIterations, uint256 startIndex) external;
    function receiveAeroRewards(address gauge, uint256 amount) external;
    function aeroTokenAddress() external view returns (address);
    function currentEpochs(address gauge) external view returns (uint256);
    function epochClosed(address gauge, uint256 epoch) external view returns (bool);
    function setAddresses(ICollateralRegistry _collateralRegistry) external;
    function governor() external view returns (address);
}