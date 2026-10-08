// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./IAeroGauge.sol";
import "./IAeroManager.sol";

interface ITroveAccount {
    function troveId() external view returns (uint256);
    function activePoolAddress() external view returns (address);
    function collToken() external view returns (IERC20);
    function aeroToken() external view returns (IERC20);
    function gauge() external view returns (IAeroGauge);
    function aeroManager() external view returns (IAeroManager);

    function initialize(uint256 _troveId) external;
    function stake(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function claimEmissions() external;
}
