// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {BatchId} from "src/Types/BatchId.sol";
import {LatestBatchData} from "src/Types/LatestBatchData.sol";
import {LatestTroveData} from "src/Types/LatestTroveData.sol";
import {ISortedTroves} from "src/Interfaces/ISortedTroves.sol";
import {IStabilityPool} from "src/Interfaces/IStabilityPool.sol";
import {ITroveManager} from "src/Interfaces/ITroveManager.sol";
import {IWETH} from "src/Interfaces/IWETH.sol";
import {AeroManager} from "src/AeroManager.sol";
import {Logging} from "./Utils/Logging.sol";
import {StringFormatting} from "./Utils/StringFormatting.sol";
import {ITroveManagerTester} from "./TestContracts/Interfaces/ITroveManagerTester.sol";
import {Assertions} from "./TestContracts/Assertions.sol";
import {BaseInvariantTest} from "./TestContracts/BaseInvariantTest.sol";
import {BaseMultiCollateralTest} from "./TestContracts/BaseMultiCollateralTest.sol";
import {TestDeployer} from "./TestContracts/Deployment.t.sol";
import {AeroLPInvariantsTestHandler} from "./TestContracts/AeroLPInvariantsTestHandler.t.sol";
import {AeroGaugeTester, MockAeroToken} from "./TestContracts/AeroGaugeTester.sol";
import {WETHTester} from "./TestContracts/WETHTester.sol";

/**
 * @title AeroLPInvariants
 * @notice Invariant tests for Aero LP collateral
 * @dev Extends InvariantsTestHandler with Aero LP-specific invariants.
 *      Tests all standard protocol invariants PLUS Aero LP-specific:
 *      - Collateral staking accounting
 *      - Gauge balance consistency
 *      - AeroManager state tracking
 */
contract AeroLPInvariants is Assertions, Logging, BaseInvariantTest, BaseMultiCollateralTest {
    using Strings for uint256;
    using StringFormatting for uint256;

    // Aero LP specific
    AeroGaugeTester internal gauge;
    MockAeroToken internal aeroToken;
    
    // Handler (inherits from InvariantsTestHandler)
    AeroLPInvariantsTestHandler handler;

    // Constants
    uint256 constant AERO_LP_BRANCH_INDEX = 0;

    function setUp() public override {
        super.setUp();

        // Start tests at a non-zero timestamp
        vm.warp(block.timestamp + 600);

        TestDeployer deployer = new TestDeployer();

        // Create WETHTester first - this will be branch 0's collateral (Aero LP)
        WETHTester wethTester = new WETHTester(100 ether, 1 days);

        // Create gauge with WETHTester as staking token
        gauge = new AeroGaugeTester(address(wethTester), deployer.AERO_TOKEN_ADDRESS());
        aeroToken = MockAeroToken(gauge.rewardToken());

        // Deploy branches: Aero LP + normal branches
        uint256 numBranches = 2;
        TestDeployer.TroveManagerParams[] memory p = new TestDeployer.TroveManagerParams[](numBranches);

        // Branch 0: Aero LP collateral
        p[0] = TestDeployer.TroveManagerParams({
            CCR: 1.5 ether,
            MCR: 1.1 ether,
            BCR: 0.1 ether,
            SCR: 1.1 ether,
            debtLimit: 100_000_000 ether,
            LIQUIDATION_PENALTY_SP: 0.05 ether,
            LIQUIDATION_PENALTY_REDISTRIBUTION: 0.1 ether,
            isAeroLPCollateral: true,
            aeroGaugeAddress: address(gauge)
        });

        // Branch 1: Normal collateral
        p[1] = TestDeployer.TroveManagerParams({
            CCR: 1.5 ether,
            MCR: 1.1 ether,
            BCR: 0.1 ether,
            SCR: 1.1 ether,
            debtLimit: 100_000_000 ether,
            LIQUIDATION_PENALTY_SP: 0.05 ether,
            LIQUIDATION_PENALTY_REDISTRIBUTION: 0.1 ether,
            isAeroLPCollateral: false,
            aeroGaugeAddress: address(0)
        });

        // Deploy contracts using the deployer that accepts WETH
        TestDeployer.DeployAndConnectContractsResults memory result =
            deployer.deployAndConnectContracts(p, IWETH(address(wethTester)));

        // Setup contracts struct for handler and base test
        Contracts memory contracts;
        contracts.branches = result.contractsArray;
        contracts.aeroManager = result.aeroManager;
        contracts.collateralRegistry = result.collateralRegistry;
        contracts.boldToken = result.boldToken;
        contracts.hintHelpers = result.hintHelpers;
        contracts.weth = IWETH(address(wethTester));
        setupContracts(contracts);

        // Create handler with Aero LP support (inherits all InvariantsTestHandler functionality)
        handler = new AeroLPInvariantsTestHandler({
            contracts: contracts,
            assumeNoExpectedFailures: true,
            _gauge: address(gauge),
            _aeroLPBranchIndex: AERO_LP_BRANCH_INDEX
        });
        vm.label(address(handler), "handler");
        targetContract(address(handler));
    }

    // ============ Standard Protocol Invariants (from InvariantsTestHandler) ============

    /**
     * @notice Actors should have empty wallets before handler calls
     */
    function invariant_FundsAreSwept() external view {
        for (uint256 i = 0; i < actors.length; ++i) {
            address actor = actors[i].account;

            assertEqDecimal(boldToken.balanceOf(actor), 0, 18, "Incomplete BOLD sweep");
            assertEqDecimal(weth.balanceOf(actor), 0, 18, "Incomplete WETH sweep");

            for (uint256 j = 0; j < branches.length; ++j) {
                IERC20 collToken = branches[j].collToken;
                address borrowerOperations = address(branches[j].borrowerOperations);

                assertEqDecimal(weth.allowance(actor, borrowerOperations), 0, 18, "WETH allowance != 0");
                assertEqDecimal(collToken.balanceOf(actor), 0, 18, "Incomplete coll sweep");
                assertEqDecimal(collToken.allowance(actor, borrowerOperations), 0, 18, "Coll allowance != 0");
            }
        }
    }

    /**
     * @notice System state should match ghost state from handler
     */
    function invariant_SystemStateMatchesGhostState() external view {
        for (uint256 i = 0; i < branches.length; ++i) {
            TestDeployer.LiquityContractsDev memory c = branches[i];

            assertEq(c.troveManager.getTroveIdsCount(), handler.numTroves(i), "Wrong number of Troves");
            assertEq(c.troveManager.lastZombieTroveId(), handler.designatedVictimId(i), "Wrong designated victim");
            assertEq(c.sortedTroves.getSize(), handler.numTroves(i) - handler.numZombies(i), "Wrong SortedTroves size");
        }
    }

    // ============ Aero LP-Specific Invariants ============

    /**
     * @notice AeroManager stakedAmounts should equal ActivePool collateral balance
     * @dev For Aero LP branches, all collateral is staked in the gauge via AeroManager
     */
    function invariant_StakedEqualsCollBalance() external view {
        uint256 stakedAmount = handler.getStakedAmount(address(gauge));
        uint256 activePoolBalance = handler.getActivePoolCollBalance(AERO_LP_BRANCH_INDEX);

        assertEq(
            stakedAmount,
            activePoolBalance,
            "Aero LP: stakedAmounts should equal ActivePool collateral balance"
        );
    }

    /**
     * @notice Gauge balance should equal AeroManager stakedAmounts
     * @dev The gauge should hold exactly what AeroManager says is staked
     */
    function invariant_GaugeBalanceEqualsStaked() external view {
        uint256 stakedAmount = handler.getStakedAmount(address(gauge));
        uint256 gaugeBalance = handler.getGaugeBalance(address(gauge));

        assertEq(
            gaugeBalance,
            stakedAmount,
            "Aero LP: gauge balance should equal stakedAmounts"
        );
    }

    /**
     * @notice No LP tokens should be stuck in ActivePool for Aero LP branches
     * @dev All collateral should be in the gauge, not in ActivePool directly
     */
    function invariant_NoLPTokensInActivePool() external view {
        uint256 activePoolTokenBalance = handler.getCollTokenInActivePool(AERO_LP_BRANCH_INDEX);

        assertEq(
            activePoolTokenBalance,
            0,
            "Aero LP: No LP tokens should be directly in ActivePool"
        );
    }

    /**
     * @notice Aero LP branch should be registered as such
     */
    function invariant_AeroLPBranchRegistered() external view {
        bool isAeroLP = handler.isActivePoolAeroLP(AERO_LP_BRANCH_INDEX);
        assertTrue(isAeroLP, "Branch 0 should be Aero LP collateral");
    }

    /**
     * @notice Normal branches should NOT be registered as Aero LP
     */
    function invariant_NormalBranchNotAeroLP() external view {
        for (uint256 i = 1; i < branches.length; i++) {
            bool isAeroLP = handler.isActivePoolAeroLP(i);
            assertFalse(isAeroLP, string.concat("Branch ", i.toString(), " should NOT be Aero LP collateral"));
        }
    }

    /**
     * @notice Total system collateral accounting for Aero LP branch
     * @dev Staked amount should equal active pool balance
     */
    function invariant_AeroLPCollateralAccounting() external view {
        uint256 stakedAmount = handler.getStakedAmount(address(gauge));
        uint256 activePoolColl = handler.getActivePoolCollBalance(AERO_LP_BRANCH_INDEX);
        uint256 gaugeBalance = handler.getGaugeBalance(address(gauge));

        // Core accounting invariants
        assertEq(stakedAmount, activePoolColl, "Aero LP: Staked should match ActivePool");
        assertEq(gaugeBalance, stakedAmount, "Aero LP: Gauge should hold staked amount");
    }

    // ============ Debug/Logging Invariant ============

    /**
     * @notice Log current state (always passes)
     */
    function invariant_callSummary() external {
        emit log_named_uint("Aero LP branch troves", handler.numTroves(AERO_LP_BRANCH_INDEX));
        emit log_named_uint("Staked amount", handler.getStakedAmount(address(gauge)));
        emit log_named_uint("Gauge balance", handler.getGaugeBalance(address(gauge)));
        emit log_named_uint("ActivePool balance", handler.getActivePoolCollBalance(AERO_LP_BRANCH_INDEX));
    }
}
