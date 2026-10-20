// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IAddressesRegistry} from "./Interfaces/IAddressesRegistry.sol";
import {TroveManager} from "./TroveManager.sol";
import {COLL_GAS_COMPENSATION_DIVISOR, COLL_GAS_COMPENSATION_CAP_AERO} from "./Dependencies/Constants.sol";

/// @notice TroveManager for the AERO token branch, with a cap denominated in AERO.
contract AeroTroveManager is TroveManager {
    constructor(IAddressesRegistry _addressesRegistry) TroveManager(_addressesRegistry) {}

    function _getCollGasCompensation(uint256 _coll) internal pure override returns (uint256) {
        uint256 compensation = _coll / COLL_GAS_COMPENSATION_DIVISOR;
        return compensation < COLL_GAS_COMPENSATION_CAP_AERO ? compensation : COLL_GAS_COMPENSATION_CAP_AERO;
    }
}
