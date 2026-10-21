// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IAddressesRegistry} from "./Interfaces/IAddressesRegistry.sol";
import {TroveManager} from "./TroveManager.sol";
import {COLL_GAS_COMPENSATION_DIVISOR, COLL_GAS_COMPENSATION_CAP_AERO} from "./Dependencies/Constants.sol";
import "./Dependencies/LiquityBase.sol";

/// @notice TroveManager for the AERO token branch, with a cap denominated in AERO.
contract AeroTroveManager is TroveManager {
    constructor(IAddressesRegistry _addressesRegistry) TroveManager(_addressesRegistry) {}

    /// @dev Override collateral reward cap for AERO due to its significantly lower USD price compared to ETH
    function _getCollGasCompensation(uint256 _coll) internal pure override returns (uint256) {
        // _entireDebt should never be zero, but we add the condition defensively to avoid an unexpected revert
        return LiquityMath._min(_coll / COLL_GAS_COMPENSATION_DIVISOR, COLL_GAS_COMPENSATION_CAP_AERO);
    }
}
