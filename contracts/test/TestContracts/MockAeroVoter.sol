// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Minimal Aerodrome Voter stub: AeroManager only needs `isAlive(gauge)`.
///      When no override is set for a gauge, the gauge is treated as alive (matches a newly deployed gauge).
contract MockAeroVoter {
    mapping(address gauge => bool hasOverride) private _hasOverride;
    mapping(address gauge => bool alive) private _alive;

    function setGaugeAlive(address gauge, bool alive) external {
        _hasOverride[gauge] = true;
        _alive[gauge] = alive;
    }

    function isAlive(address gauge) external view returns (bool) {
        if (!_hasOverride[gauge]) return true;
        return _alive[gauge];
    }
}
