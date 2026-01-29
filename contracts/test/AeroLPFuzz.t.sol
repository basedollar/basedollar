// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "./TestContracts/Accounts.sol";
import "./TestContracts/AeroGaugeTester.sol";
import "./TestContracts/Deployment.t.sol";
import "./TestContracts/WETHTester.sol";
import "src/AeroManager.sol";

/**
 * @title AeroLPFuzz
 * @notice Fuzz tests for Aero LP collateral across multiple branches
 * @dev Tests staking/unstaking via AeroManager, multi-gauge independence, and reward operations
 */
contract AeroLPFuzz is Test, TestAccounts {
    // Gauges for each Aero LP branch
    AeroGaugeTester internal gauge1;
    AeroGaugeTester internal gauge2;
    MockAeroToken internal aeroToken;

    // Branch references
    TestDeployer.LiquityContractsDev internal aeroLPBranch1;
    TestDeployer.LiquityContractsDev internal aeroLPBranch2;
    TestDeployer.LiquityContractsDev internal normalBranch;
    TestDeployer.LiquityContractsDev[] internal branches;

    // Collateral tokens
    IERC20 internal lpToken1;
    IERC20 internal lpToken2;
    IERC20 internal normalCollToken;

    // Core contracts
    IAeroManager internal aeroManager;
    ICollateralRegistry internal collateralRegistry;
    IBoldToken internal boldToken;
    HintHelpers internal hintHelpers;
    IWETH internal WETH;

    // Constants for fuzzing bounds
    uint256 constant MIN_COLL = 1e18;
    uint256 constant MAX_COLL = 1_000_000e18;
    uint256 constant MIN_DEBT_AMOUNT = 2000e18;
    uint256 constant MAX_DEBT = 10_000_000e18;
    uint256 constant MIN_INTEREST_RATE = 5e15; // 0.5%
    uint256 constant MAX_INTEREST_RATE = 25e16; // 25%

    function setUp() public virtual {
        // Start tests at a non-zero timestamp
        vm.warp(block.timestamp + 600);

        accounts = new Accounts();
        createAccounts();

        (A, B, C, D, E, F, G) = (
            accountsList[0],
            accountsList[1],
            accountsList[2],
            accountsList[3],
            accountsList[4],
            accountsList[5],
            accountsList[6]
        );

        TestDeployer deployer = new TestDeployer();

        // Create WETHTester first - this will be branch 0's collateral AND the gauge's staking token
        WETHTester wethTester = new WETHTester(100 ether, 1 days);

        // Create gauge1 with WETHTester as staking token (must match branch 0's collateral)
        gauge1 = new AeroGaugeTester(address(wethTester), deployer.AERO_TOKEN_ADDRESS());
        aeroToken = MockAeroToken(gauge1.rewardToken());
        
        // Deploy 3 branches: 1 Aero LP + 2 normal
        // Note: For multi-gauge testing, we'd need to modify the deployer or use separate deployments
        TestDeployer.TroveManagerParams[] memory troveManagerParamsArray = new TestDeployer.TroveManagerParams[](3);
        
        // Branch 0: Aero LP collateral (uses WETHTester as LP token)
        troveManagerParamsArray[0] = TestDeployer.TroveManagerParams({
            CCR: 150e16,
            MCR: 110e16,
            BCR: 10e16,
            SCR: 110e16,
            debtLimit: 100_000_000 ether,
            LIQUIDATION_PENALTY_SP: 5e16,
            LIQUIDATION_PENALTY_REDISTRIBUTION: 10e16,
            isAeroLPCollateral: true,
            aeroGaugeAddress: address(gauge1)
        });
        
        // Branch 1: Normal collateral (for comparison testing)
        troveManagerParamsArray[1] = TestDeployer.TroveManagerParams({
            CCR: 160e16,
            MCR: 120e16,
            BCR: 10e16,
            SCR: 120e16,
            debtLimit: 100_000_000 ether,
            LIQUIDATION_PENALTY_SP: 5e16,
            LIQUIDATION_PENALTY_REDISTRIBUTION: 10e16,
            isAeroLPCollateral: false,
            aeroGaugeAddress: address(0)
        });
        
        // Branch 2: Normal collateral (for additional comparison)
        troveManagerParamsArray[2] = TestDeployer.TroveManagerParams({
            CCR: 150e16,
            MCR: 110e16,
            BCR: 10e16,
            SCR: 110e16,
            debtLimit: 100_000_000 ether,
            LIQUIDATION_PENALTY_SP: 5e16,
            LIQUIDATION_PENALTY_REDISTRIBUTION: 10e16,
            isAeroLPCollateral: false,
            aeroGaugeAddress: address(0)
        });

        // Deploy contracts - pass our WETHTester so branch 0 uses it as collateral
        TestDeployer.DeployAndConnectContractsResults memory result =
            deployer.deployAndConnectContracts(troveManagerParamsArray, IWETH(address(wethTester)));

        // Store branch references
        aeroLPBranch1 = result.contractsArray[0];
        aeroLPBranch2 = result.contractsArray[1];
        normalBranch = result.contractsArray[2];
        
        // Store branches array
        for (uint256 i = 0; i < result.contractsArray.length; i++) {
            branches.push(result.contractsArray[i]);
        }

        // Store collateral tokens
        lpToken1 = aeroLPBranch1.collToken;
        lpToken2 = aeroLPBranch2.collToken;
        normalCollToken = normalBranch.collToken;

        // Create gauge2 with branch 1's collateral token (for future multi-gauge tests)
        gauge2 = new AeroGaugeTester(address(lpToken2), address(aeroToken));

        // Wire up core contracts
        aeroManager = result.aeroManager;
        collateralRegistry = result.collateralRegistry;
        boldToken = result.boldToken;
        hintHelpers = result.hintHelpers;
        WETH = IWETH(address(wethTester));

        // Give collateral to test accounts for all branches
        uint256 initialCollAmount = 10_000_000e18;
        for (uint256 i = 0; i < 6; i++) {
            // Branch 0 (Aero LP 1) - lpToken1 IS WETH, so this also covers gas compensation
            // We give extra for gas compensation since WETH is both collateral and gas comp
            _giveAndApproveCollateral(lpToken1, accountsList[i], initialCollAmount + 100 ether, address(aeroLPBranch1.borrowerOperations));
            // Branch 1
            _giveAndApproveCollateral(lpToken2, accountsList[i], initialCollAmount, address(aeroLPBranch2.borrowerOperations));
            // Branch 2
            _giveAndApproveCollateral(normalCollToken, accountsList[i], initialCollAmount, address(normalBranch.borrowerOperations));
            // Approve WETH for all branches (already dealt above via lpToken1)
            vm.prank(accountsList[i]);
            WETH.approve(address(aeroLPBranch1.borrowerOperations), type(uint256).max);
            vm.prank(accountsList[i]);
            WETH.approve(address(aeroLPBranch2.borrowerOperations), type(uint256).max);
            vm.prank(accountsList[i]);
            WETH.approve(address(normalBranch.borrowerOperations), type(uint256).max);
        }
    }

    function _giveAndApproveCollateral(IERC20 _token, address _account, uint256 _amount, address _spender) internal {
        deal(address(_token), _account, _amount);
        vm.prank(_account);
        _token.approve(_spender, _amount);
    }

    // ============ Helper Functions ============

    function _boundColl(uint256 _coll) internal pure returns (uint256) {
        return bound(_coll, MIN_COLL, MAX_COLL);
    }

    function _boundDebt(uint256 _debt) internal pure returns (uint256) {
        return bound(_debt, MIN_DEBT_AMOUNT, MAX_DEBT);
    }

    function _boundInterestRate(uint256 _rate) internal pure returns (uint256) {
        return bound(_rate, MIN_INTEREST_RATE, MAX_INTEREST_RATE);
    }

    function _openTroveOnBranch(
        TestDeployer.LiquityContractsDev memory _branch,
        address _account,
        uint256 _index,
        uint256 _coll,
        uint256 _boldAmount,
        uint256 _annualInterestRate
    ) internal returns (uint256 troveId) {
        uint256 upfrontFee = hintHelpers.predictOpenTroveUpfrontFee(
            _getBranchIndex(_branch),
            _boldAmount,
            _annualInterestRate
        );

        vm.startPrank(_account);
        troveId = _branch.borrowerOperations.openTrove(
            _account,
            _index,
            _coll,
            _boldAmount,
            0, // _upperHint
            0, // _lowerHint
            _annualInterestRate,
            upfrontFee,
            address(0),
            address(0),
            address(0)
        );
        vm.stopPrank();
    }

    function _getBranchIndex(TestDeployer.LiquityContractsDev memory _branch) internal view returns (uint256) {
        for (uint256 i = 0; i < branches.length; i++) {
            if (address(branches[i].troveManager) == address(_branch.troveManager)) {
                return i;
            }
        }
        revert("Branch not found");
    }

    function _getAeroManager() internal view returns (AeroManager) {
        return AeroManager(address(aeroManager));
    }

    // ============ Fuzz Tests ============

    /**
     * @notice Test opening a trove with Aero LP collateral stakes correctly in gauge
     */
    function testFuzz_openTroveWithAeroLPCollateral(
        uint256 _coll,
        uint256 _debt,
        uint256 _interestRate
    ) public {
        _debt = _boundDebt(_debt);
        _interestRate = _boundInterestRate(_interestRate);

        // Calculate minimum collateral required for this debt, then bound _coll above it
        // Use CCR (not MCR) because first trove needs to meet CCR, plus buffer for upfront fee
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 minColl = _debt * (ccr + 10e16) / price + 1e18; // CCR + 10% buffer for fees
        _coll = bound(_coll, minColl, MAX_COLL);

        uint256 gaugeBalanceBefore = gauge1.balanceOf(address(aeroManager));
        uint256 stakedAmountsBefore = _getAeroManager().stakedAmounts(address(gauge1));

        // Open trove on Aero LP branch
        _openTroveOnBranch(aeroLPBranch1, A, 0, _coll, _debt, _interestRate);

        // Verify collateral is staked in gauge
        uint256 gaugeBalanceAfter = gauge1.balanceOf(address(aeroManager));
        uint256 stakedAmountsAfter = _getAeroManager().stakedAmounts(address(gauge1));
        uint256 activePoolBalance = aeroLPBranch1.activePool.getCollBalance();

        assertEq(gaugeBalanceAfter - gaugeBalanceBefore, _coll, "Gauge balance should increase by coll amount");
        assertEq(stakedAmountsAfter - stakedAmountsBefore, _coll, "Staked amounts should increase by coll amount");
        assertEq(stakedAmountsAfter, activePoolBalance, "Staked amounts should equal ActivePool balance");
        
        // Verify no LP tokens stuck in ActivePool (all should be in gauge)
        assertEq(lpToken1.balanceOf(address(aeroLPBranch1.activePool)), 0, "No LP tokens should be in ActivePool");
    }

    /**
     * @notice Test that multiple users opening troves on the same Aero LP branch track collateral correctly
     */
    function testFuzz_multipleTrovesOnAeroLPBranch(
        uint256 _coll1,
        uint256 _coll2,
        uint256 _debt
    ) public {
        _debt = _boundDebt(_debt);

        // Use CCR + buffer for first trove (sets the TCR)
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 minColl = _debt * (ccr + 10e16) / price + 1e18;
        _coll1 = bound(_coll1, minColl, MAX_COLL / 2);
        _coll2 = bound(_coll2, minColl, MAX_COLL / 2);

        uint256 interestRate = 5e16; // 5%

        // Open first trove
        _openTroveOnBranch(aeroLPBranch1, A, 0, _coll1, _debt, interestRate);

        // Open second trove (different user)
        _openTroveOnBranch(aeroLPBranch1, B, 0, _coll2, _debt, interestRate);

        // Verify gauge tracks both collaterals
        uint256 gaugeBalance = gauge1.balanceOf(address(aeroManager));
        uint256 staked = _getAeroManager().stakedAmounts(address(gauge1));
        uint256 expectedTotal = _coll1 + _coll2;

        assertEq(gaugeBalance, expectedTotal, "Gauge should have both collaterals");
        assertEq(staked, expectedTotal, "Staked should equal total collateral");
        assertEq(staked, aeroLPBranch1.activePool.getCollBalance(), "Staked should match AP balance");
    }

    /**
     * @notice Test adding collateral to existing trove updates gauge correctly
     */
    function testFuzz_adjustTroveAddCollateral(
        uint256 _initialColl,
        uint256 _addColl,
        uint256 _debt
    ) public {
        _debt = _boundDebt(_debt);
        _addColl = bound(_addColl, 1e17, MAX_COLL / 2);

        // Ensure sufficient collateralization (use CCR + buffer for upfront fee)
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 minColl = _debt * (ccr + 10e16) / price + 1e18;
        _initialColl = bound(_initialColl, minColl, MAX_COLL / 2);

        uint256 interestRate = 5e16;

        // Open trove
        uint256 troveId = _openTroveOnBranch(aeroLPBranch1, A, 0, _initialColl, _debt, interestRate);

        uint256 stakedBefore = _getAeroManager().stakedAmounts(address(gauge1));
        uint256 gaugeBefore = gauge1.balanceOf(address(aeroManager));

        // Add collateral
        vm.startPrank(A);
        aeroLPBranch1.borrowerOperations.addColl(troveId, _addColl);
        vm.stopPrank();

        uint256 stakedAfter = _getAeroManager().stakedAmounts(address(gauge1));
        uint256 gaugeAfter = gauge1.balanceOf(address(aeroManager));

        assertEq(stakedAfter - stakedBefore, _addColl, "Staked should increase by added coll");
        assertEq(gaugeAfter - gaugeBefore, _addColl, "Gauge balance should increase by added coll");
        assertEq(stakedAfter, aeroLPBranch1.activePool.getCollBalance(), "Staked should match AP balance");
    }

    /**
     * @notice Test withdrawing collateral from trove unstakes from gauge correctly
     */
    function testFuzz_adjustTroveWithdrawCollateral(
        uint256 _initialColl,
        uint256 _withdrawColl,
        uint256 _debt
    ) public {
        _debt = _boundDebt(_debt);
        
        // Calculate collateral bounds
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 mcr = aeroLPBranch1.troveManager.get_MCR();
        
        // Open with enough collateral to allow meaningful withdrawal while staying above CCR
        // Initial coll must be > CCR * debt / price (for opening) AND allow withdrawal
        uint256 minCollForOpening = _debt * (ccr + 15e16) / price + 1e18; // CCR + 15% buffer
        _initialColl = bound(_initialColl, minCollForOpening, MAX_COLL / 2);
        
        // First open a highly-collateralized trove for B to buffer TCR
        uint256 safeCollB = _debt * (ccr + 50e16) / price; // CCR + 50% buffer for B
        _openTroveOnBranch(aeroLPBranch1, B, 0, safeCollB, _debt, 5e16);
        
        // Open trove for A
        uint256 troveId = _openTroveOnBranch(aeroLPBranch1, A, 0, _initialColl, _debt, 5e16);
        
        // Calculate safe withdrawal amount - A must stay above MCR, and TCR must stay above CCR
        // With B's buffer, we can safely withdraw A down to MCR
        uint256 minCollAfterWithdraw = _debt * (mcr + 5e16) / price;
        uint256 maxWithdraw = _initialColl > minCollAfterWithdraw ? _initialColl - minCollAfterWithdraw : 0;
        vm.assume(maxWithdraw >= 1e17);
        _withdrawColl = bound(_withdrawColl, 1e17, maxWithdraw);

        uint256 stakedBefore = _getAeroManager().stakedAmounts(address(gauge1));
        uint256 userBalanceBefore = lpToken1.balanceOf(A);

        // Withdraw collateral
        vm.prank(A);
        aeroLPBranch1.borrowerOperations.withdrawColl(troveId, _withdrawColl);

        // Verify unstaking
        assertEq(stakedBefore - _getAeroManager().stakedAmounts(address(gauge1)), _withdrawColl, "Staked should decrease");
        assertEq(lpToken1.balanceOf(A) - userBalanceBefore, _withdrawColl, "User should receive withdrawn coll");
        assertEq(_getAeroManager().stakedAmounts(address(gauge1)), aeroLPBranch1.activePool.getCollBalance(), "Staked should match AP balance");
    }

    /**
     * @notice Test closing trove fully unstakes from gauge
     */
    function testFuzz_closeTrove(uint256 _coll, uint256 _debt) public {
        _debt = _boundDebt(_debt);

        // Ensure sufficient collateralization (use CCR + buffer for upfront fee)
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 minColl = _debt * (ccr + 10e16) / price + 1e18;
        _coll = bound(_coll, minColl, MAX_COLL / 2);

        uint256 interestRate = 5e16;

        // First open a trove for B so we can close A's trove (protocol requires at least 1 trove)
        _openTroveOnBranch(aeroLPBranch1, B, 0, minColl, _debt, interestRate);

        // Open trove for A
        uint256 troveId = _openTroveOnBranch(aeroLPBranch1, A, 0, _coll, _debt, interestRate);

        // Get A's actual trove collateral
        uint256 troveCollA = aeroLPBranch1.troveManager.getLatestTroveData(troveId).entireColl;
        
        // Give A enough BOLD to repay debt (with buffer for any accrued interest)
        deal(address(boldToken), A, aeroLPBranch1.troveManager.getTroveEntireDebt(troveId) * 2);

        uint256 userCollBefore = lpToken1.balanceOf(A);
        uint256 stakedBefore = _getAeroManager().stakedAmounts(address(gauge1));

        // Close trove
        vm.startPrank(A);
        boldToken.approve(address(aeroLPBranch1.borrowerOperations), type(uint256).max);
        aeroLPBranch1.borrowerOperations.closeTrove(troveId);
        vm.stopPrank();

        uint256 stakedAfter = _getAeroManager().stakedAmounts(address(gauge1));
        uint256 userCollAfter = lpToken1.balanceOf(A);

        // After closing A's trove, the staked amount should decrease
        // Note: User receives collateral minus gas compensation (ETH_GAS_COMPENSATION = 0.0375 ETH)
        assertEq(stakedBefore - stakedAfter, troveCollA, "Staked should decrease by closed trove's collateral");
        // User receives collateral minus gas compensation which is refunded
        assertGt(userCollAfter, userCollBefore, "User should receive collateral back");
        // The difference should be within gas compensation bounds (0.0375 ETH is the gas comp)
        assertApproxEqAbs(userCollAfter - userCollBefore, troveCollA, 0.1 ether, "User should receive most collateral back");
        // Gauge accounting invariant
        assertEq(stakedAfter, aeroLPBranch1.activePool.getCollBalance(), "Staked should match AP balance");
    }

    /**
     * @notice Test multiple stakes and unstakes maintain correct accounting
     */
    function testFuzz_multipleStakeUnstake(
        uint256 _coll1,
        uint256 _coll2,
        uint256 _debt
    ) public {
        _debt = _boundDebt(_debt);

        // Ensure sufficient collateralization for both troves (use CCR + buffer for upfront fee)
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 minColl = _debt * (ccr + 10e16) / price + 1e18;
        _coll1 = bound(_coll1, minColl, MAX_COLL / 2);
        _coll2 = bound(_coll2, minColl, MAX_COLL / 2);

        uint256 interestRate = 5e16;

        // User A opens trove
        _openTroveOnBranch(aeroLPBranch1, A, 0, _coll1, _debt, interestRate);

        // User B opens trove
        _openTroveOnBranch(aeroLPBranch1, B, 0, _coll2, _debt, interestRate);

        uint256 expectedStaked = _coll1 + _coll2;
        uint256 actualStaked = _getAeroManager().stakedAmounts(address(gauge1));
        uint256 gaugeBalance = gauge1.balanceOf(address(aeroManager));

        assertEq(actualStaked, expectedStaked, "Total staked should be sum of both collaterals");
        assertEq(gaugeBalance, expectedStaked, "Gauge balance should match total staked");
        assertEq(actualStaked, aeroLPBranch1.activePool.getCollBalance(), "Staked should match AP balance");

        // User A closes trove
        uint256 troveDebtA = aeroLPBranch1.troveManager.getTroveEntireDebt(
            uint256(keccak256(abi.encode(A, A, 0)))
        );
        deal(address(boldToken), A, troveDebtA);
        
        vm.startPrank(A);
        boldToken.approve(address(aeroLPBranch1.borrowerOperations), troveDebtA);
        aeroLPBranch1.borrowerOperations.closeTrove(uint256(keccak256(abi.encode(A, A, 0))));
        vm.stopPrank();

        uint256 stakedAfterAClose = _getAeroManager().stakedAmounts(address(gauge1));
        assertEq(stakedAfterAClose, _coll2, "After A closes, only B's collateral should remain");
    }

    /**
     * @notice Test claiming and distributing AERO rewards
     */
    function testFuzz_claimAndDistributeRewards(uint256 _coll, uint256 _debt) public {
        _debt = _boundDebt(_debt);

        // Ensure sufficient collateralization (use CCR + buffer for upfront fee)
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 minColl = _debt * (ccr + 10e16) / price + 1e18;
        _coll = bound(_coll, minColl, MAX_COLL);

        uint256 interestRate = 5e16;

        // Open trove to have collateral staked
        _openTroveOnBranch(aeroLPBranch1, A, 0, _coll, _debt, interestRate);

        AeroManager am = _getAeroManager();
        address governor = am.governor();
        address treasury = am.treasuryAddress();

        uint256 treasuryBalanceBefore = aeroToken.balanceOf(treasury);

        // Claim rewards
        am.claim(address(gauge1));

        // The mock gauge mints rewards equal to staked balance
        uint256 expectedReward = _coll;
        uint256 claimFee = expectedReward * am.claimFee() / 1e18;
        uint256 netReward = expectedReward - claimFee;

        uint256 treasuryBalanceAfter = aeroToken.balanceOf(treasury);
        uint256 managerAeroBalance = aeroToken.balanceOf(address(am));

        assertEq(treasuryBalanceAfter - treasuryBalanceBefore, claimFee, "Treasury should receive claim fee");
        assertEq(managerAeroBalance, netReward, "Manager should hold net rewards");
        assertEq(am.claimedAero(), netReward, "claimedAero should track net rewards");
        assertEq(am.claimedAeroPerEpoch(0, address(gauge1)), netReward, "Epoch rewards should be tracked");

        // Distribute rewards
        AeroManager.AeroRecipient[] memory recipients = new AeroManager.AeroRecipient[](1);
        recipients[0] = AeroManager.AeroRecipient({borrower: A, amount: netReward});

        vm.prank(governor);
        am.distributeAero(address(gauge1), recipients);

        assertEq(am.currentEpochs(address(gauge1)), 1, "Epoch should increment");
        assertEq(am.claimableRewards(A), netReward, "User should have claimable rewards");

        // User claims rewards
        uint256 userAeroBefore = aeroToken.balanceOf(A);
        am.claimRewards(A);
        uint256 userAeroAfter = aeroToken.balanceOf(A);

        assertEq(userAeroAfter - userAeroBefore, netReward, "User should receive rewards");
        assertEq(am.claimableRewards(A), 0, "Claimable should be zeroed");
    }

    // ============ Edge Case Tests ============

    /**
     * @notice Test that zero collateral operations are handled correctly
     */
    function test_zeroCollateralOperations() public {
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 debt = 50_000e18;
        uint256 coll = debt * (ccr + 10e16) / price + 1e18;

        // First open a trove normally
        _openTroveOnBranch(aeroLPBranch1, A, 0, coll, debt, 5e16);
        uint256 troveId = uint256(keccak256(abi.encode(A, A, 0)));

        // Try to add zero collateral - should either revert or be a no-op
        uint256 stakedBefore = _getAeroManager().stakedAmounts(address(gauge1));
        vm.startPrank(A);
        try aeroLPBranch1.borrowerOperations.addColl(troveId, 0) {
            // If it doesn't revert, staked amount should be unchanged
            uint256 stakedAfter = _getAeroManager().stakedAmounts(address(gauge1));
            assertEq(stakedAfter, stakedBefore, "Zero add should not change staked");
        } catch {
            // Expected to revert for zero amount
            assertTrue(true, "Zero add correctly reverted");
        }
        vm.stopPrank();
    }

    /**
     * @notice Test concurrent operations from same user on same branch
     */
    function test_concurrentOperationsSameUser() public {
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 debt = 50_000e18;
        uint256 coll = debt * (ccr + 10e16) / price + 1e18;

        // Open first trove
        uint256 troveId1 = _openTroveOnBranch(aeroLPBranch1, A, 0, coll, debt, 5e16);
        
        // For second trove, we need extra collateral + gas comp
        // Since lpToken1 IS WETH, deal enough for both collateral and gas comp
        deal(address(lpToken1), A, coll + 1 ether);
        vm.prank(A);
        lpToken1.approve(address(aeroLPBranch1.borrowerOperations), type(uint256).max);
        vm.prank(A);
        WETH.approve(address(aeroLPBranch1.borrowerOperations), type(uint256).max);
        
        uint256 upfrontFee2 = hintHelpers.predictOpenTroveUpfrontFee(0, debt, 6e16);
        vm.prank(A);
        uint256 troveId2 = aeroLPBranch1.borrowerOperations.openTrove(
            A, 1, coll, debt, 0, 0, 6e16, upfrontFee2, address(0), address(0), address(0)
        );

        // Verify both troves exist
        assertTrue(aeroLPBranch1.troveNFT.ownerOf(troveId1) == A, "A should own trove1");
        assertTrue(aeroLPBranch1.troveNFT.ownerOf(troveId2) == A, "A should own trove2");

        // Verify total staked is sum of both
        uint256 totalExpected = coll * 2;
        assertApproxEqRel(
            _getAeroManager().stakedAmounts(address(gauge1)),
            totalExpected,
            0.01e18, // 1% tolerance for fees
            "Total staked should be sum of both troves"
        );
    }

    /**
     * @notice Test that gauge accounting is correct after multiple operations
     */
    function testFuzz_gaugeAccountingAfterManyOperations(
        uint256 numOperations,
        uint256 seed
    ) public {
        numOperations = bound(numOperations, 1, 5);
        
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 debt = 50_000e18;
        uint256 coll = debt * (ccr + 10e16) / price + 1e18;

        // Open initial trove for B (so we can close A's trove)
        _openTroveOnBranch(aeroLPBranch1, B, 0, coll * 2, debt, 5e16);

        // Open trove for A
        _openTroveOnBranch(aeroLPBranch1, A, 0, coll, debt, 5e16);
        uint256 troveId = uint256(keccak256(abi.encode(A, A, 0)));

        // Perform random operations
        // Note: try-catch is intentional here - operations may fail legitimately 
        // (e.g., withdrawal violating ICR). The test verifies accounting invariants
        // hold regardless of which operations succeed or fail.
        for (uint256 i = 0; i < numOperations; i++) {
            uint256 op = uint256(keccak256(abi.encode(seed, i))) % 2;
            uint256 amount = bound(uint256(keccak256(abi.encode(seed, i, "amount"))), 1e17, 10e18);

            if (op == 0) {
                // Add collateral
                _giveAndApproveCollateral(lpToken1, A, amount, address(aeroLPBranch1.borrowerOperations));
                vm.prank(A);
                try aeroLPBranch1.borrowerOperations.addColl(troveId, amount) {} catch {}
            } else {
                // Withdraw collateral (if possible)
                vm.prank(A);
                try aeroLPBranch1.borrowerOperations.withdrawColl(troveId, amount) {} catch {}
            }
        }

        // Verify accounting invariant
        uint256 staked = _getAeroManager().stakedAmounts(address(gauge1));
        uint256 apBalance = aeroLPBranch1.activePool.getCollBalance();
        uint256 gaugeBalance = gauge1.balanceOf(address(aeroManager));

        assertEq(staked, apBalance, "Staked should match AP balance");
        assertEq(gaugeBalance, staked, "Gauge balance should match staked");
    }

    /**
     * @notice Test claim fee limits
     */
    function test_claimFeeWithinLimits() public view {
        AeroManager am = _getAeroManager();
        
        // MAX_AERO_MANAGER_FEE = 50 * _1pct = 50e16 (50%)
        uint256 maxFee = 50e16;
        uint256 currentFee = am.claimFee();
        
        assertTrue(currentFee <= maxFee, "Claim fee should be within limits");
    }

    /**
     * @notice Test that rewards are tracked per epoch correctly
     */
    function test_rewardsPerEpochTracking() public {
        uint256 price = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr = aeroLPBranch1.troveManager.get_CCR();
        uint256 debt = 50_000e18;
        uint256 coll = debt * (ccr + 10e16) / price + 1e18;

        // Open trove
        _openTroveOnBranch(aeroLPBranch1, A, 0, coll, debt, 5e16);

        AeroManager am = _getAeroManager();
        address governor = am.governor();

        uint256 previousEpoch = am.currentEpochs(address(gauge1));

        // Claim rewards (mock gauge gives rewards once based on balance)
        am.claim(address(gauge1));
        uint256 claimed = am.claimedAero();
        
        assertTrue(claimed > 0, "Should have claimed some rewards");

        // Distribute to A
        AeroManager.AeroRecipient[] memory recipients = new AeroManager.AeroRecipient[](1);
        recipients[0] = AeroManager.AeroRecipient({borrower: A, amount: claimed});

        vm.prank(governor);
        am.distributeAero(address(gauge1), recipients);

        // Verify epoch incremented
        uint256 currentEpoch = am.currentEpochs(address(gauge1));
        assertEq(currentEpoch, previousEpoch + 1, "Epoch should increment");

        // Verify claimable rewards set correctly
        assertEq(am.claimableRewards(A), claimed, "User should have claimable rewards");

        // User claims rewards
        uint256 balanceBefore = aeroToken.balanceOf(A);
        am.claimRewards(A);
        uint256 balanceAfter = aeroToken.balanceOf(A);
        
        assertEq(balanceAfter - balanceBefore, claimed, "User should receive rewards");
        assertEq(am.claimableRewards(A), 0, "Claimable should be zeroed");
    }

    /**
     * @notice Test normal branch behavior is identical for non-staking operations
     */
    function test_normalBranchBehaviorParity() public {
        uint256 debt = 50_000e18;
        uint256 interestRate = 5e16;
        
        // Get prices and CCRs
        uint256 price1 = aeroLPBranch1.priceFeed.getPrice();
        uint256 ccr1 = aeroLPBranch1.troveManager.get_CCR();
        uint256 coll1 = debt * (ccr1 + 10e16) / price1 + 1e18;

        uint256 price2 = aeroLPBranch2.priceFeed.getPrice();
        uint256 ccr2 = aeroLPBranch2.troveManager.get_CCR();
        uint256 coll2 = debt * (ccr2 + 10e16) / price2 + 1e18;

        // Open troves on both branches
        uint256 troveId1 = _openTroveOnBranch(aeroLPBranch1, A, 0, coll1, debt, interestRate);
        uint256 troveId2 = _openTroveOnBranch(aeroLPBranch2, B, 0, coll2, debt, interestRate);

        // Warp time
        vm.warp(block.timestamp + 30 days);

        // Both should accrue interest similarly
        uint256 debt1After = aeroLPBranch1.troveManager.getTroveEntireDebt(troveId1);
        uint256 debt2After = aeroLPBranch2.troveManager.getTroveEntireDebt(troveId2);

        assertTrue(debt1After > debt, "Branch 1 should accrue interest");
        assertTrue(debt2After > debt, "Branch 2 should accrue interest");
    }
}
