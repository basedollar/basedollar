// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {AeroManager} from "src/AeroManager.sol";
import {IAeroManager} from "src/Interfaces/IAeroManager.sol";
import {InvariantsTestHandler} from "./InvariantsTestHandler.t.sol";
import {BaseMultiCollateralTest} from "./BaseMultiCollateralTest.sol";
import {TestDeployer} from "./Deployment.t.sol";
import {StringFormatting} from "../Utils/StringFormatting.sol";

/**
 * @title AeroLPInvariantsTestHandler
 * @notice Handler for Aero LP invariant testing that extends InvariantsTestHandler
 * @dev Inherits all the rigorous testing from InvariantsTestHandler (trove operations,
 *      batch management, liquidations, redemptions, SP operations, etc.) and adds 
 *      Aero LP-specific state tracking and view functions for invariant checks
 */
contract AeroLPInvariantsTestHandler is InvariantsTestHandler {
    using Strings for uint256;
    using StringFormatting for *;

    // ============ Aero LP-Specific State ============
    
    /// @notice Track if a branch is an Aero LP branch
    mapping(uint256 branchIndex => bool) public isAeroLPBranch;
    
    /// @notice Track gauge address per branch
    mapping(uint256 branchIndex => address) public branchGauge;
    
    /// @notice Index of the primary Aero LP branch
    uint256 public aeroLPBranchIndex;
    
    /// @notice Gauge address for the primary Aero LP branch
    address public gauge;

    // ============ Constructor ============
    
    constructor(
        Contracts memory contracts,
        bool assumeNoExpectedFailures,
        address _gauge,
        uint256 _aeroLPBranchIndex
    ) InvariantsTestHandler(contracts, assumeNoExpectedFailures) {
        gauge = _gauge;
        aeroLPBranchIndex = _aeroLPBranchIndex;
        
        // Initialize Aero LP branch tracking
        for (uint256 i = 0; i < branches.length; i++) {
            bool isAeroLP = branches[i].activePool.isAeroLPCollateral();
            isAeroLPBranch[i] = isAeroLP;
            if (isAeroLP) {
                branchGauge[i] = _gauge;
            }
        }
    }

    // ============ Aero LP-Specific View Functions for Invariant Checks ============
    
    /**
     * @notice Get the actual staked amount from AeroManager for a gauge
     */
    function getStakedAmount(address _gauge) external view returns (uint256) {
        return AeroManager(address(aeroManager)).stakedAmounts(_gauge);
    }
    
    /**
     * @notice Get the gauge balance held by AeroManager
     */
    function getGaugeBalance(address _gauge) external view returns (uint256) {
        return IERC20(_gauge).balanceOf(address(aeroManager));
    }
    
    /**
     * @notice Get ActivePool collateral balance for a branch
     */
    function getActivePoolCollBalance(uint256 branchIdx) external view returns (uint256) {
        return branches[branchIdx].activePool.getCollBalance();
    }
    
    /**
     * @notice Get collateral token balance directly in ActivePool (should be 0 for Aero LP)
     */
    function getCollTokenInActivePool(uint256 branchIdx) external view returns (uint256) {
        return branches[branchIdx].collToken.balanceOf(address(branches[branchIdx].activePool));
    }

    /**
     * @notice Check if a branch's ActivePool is registered as Aero LP collateral
     */
    function isActivePoolAeroLP(uint256 branchIdx) external view returns (bool) {
        return branches[branchIdx].activePool.isAeroLPCollateral();
    }

    /**
     * @notice Get the total collateral in default pool for a branch
     */
    function getDefaultPoolCollBalance(uint256 branchIdx) external view returns (uint256) {
        return branches[branchIdx].pools.defaultPool.getCollBalance();
    }

    /**
     * @notice Get the AeroManager address
     */
    function getAeroManagerAddress() external view returns (address) {
        return address(aeroManager);
    }

    /**
     * @notice Get number of Aero LP branches
     */
    function getNumAeroLPBranches() external view returns (uint256 count) {
        for (uint256 i = 0; i < branches.length; i++) {
            if (isAeroLPBranch[i]) count++;
        }
    }

    /**
     * @notice Get total collateral across all troves on a branch (from ghost state)
     * @dev This uses the inherited getTrove function from InvariantsTestHandler
     */
    function getTotalTroveCollateral(uint256 branchIdx) external view returns (uint256 totalColl) {
        uint256 n = numTroves(branchIdx);
        for (uint256 j = 0; j < n; ++j) {
            // getTrove returns: troveId, coll, debt, status, batchManager, totalCollRedist_, totalDebtRedist_
            (, uint256 coll,,,,,) = this.getTrove(branchIdx, j);
            totalColl += coll;
        }
    }
}
