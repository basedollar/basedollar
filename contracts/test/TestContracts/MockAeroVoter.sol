// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Minimal leaf voter and orchestrator stub for AeroManager.
///      When no override is set for a gauge, the gauge is treated as alive (matches a newly deployed gauge).
contract MockAeroVoter {
    address public RECEIPT_TOKEN;
    mapping(address gauge => bool hasOverride) private _hasOverride;
    mapping(address gauge => bool alive) private _alive;

    function setGaugeAlive(address gauge, bool alive) external {
        _hasOverride[gauge] = true;
        _alive[gauge] = alive;
    }

    function isAlive(address gauge) public view returns (bool) {
        if (!_hasOverride[gauge]) return true;
        return _alive[gauge];
    }

    function setRewardToken(address token) external {
        RECEIPT_TOKEN = token;
    }

    function ORCHESTRATOR() external view returns (address) {
        return address(this);
    }

    function ROOT_CHAIN_ID() external pure returns (uint256) {
        return 0;
    }

    function FACTORY_REGISTRY() external view returns (address) {
        return address(this);
    }

    function isActivated(address gauge) external view returns (bool) {
        return isAlive(gauge);
    }

    function emissionCap(address) external pure returns (uint128) {
        return 1;
    }

    function chainStatus() external pure returns (uint8) {
        return 1; // Active
    }

    function emissionsPerVP() external pure returns (uint256) {
        return 1;
    }
}
