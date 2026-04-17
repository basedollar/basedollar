// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestContracts/DevTestSetup.sol";
import "./TestContracts/AeroGaugeTester.sol";
import "./TestContracts/WETHTester.sol";
import "src/AeroManager.sol";
import "src/Dependencies/Constants.sol";

contract AeroManagerTest is DevTestSetup {
    AeroGaugeTester internal gauge;
    MockAeroToken internal aeroToken;
    IActivePool internal aeroActivePool;
    WETHTester internal weth;
    AeroManager internal aeroManagerImpl;

    address internal governor;
    address internal treasury;
    address internal collateralRegistryAddress;

    function _stakeThroughActivePool(uint256 amount) internal {
        deal(address(weth), address(borrowerOperations), amount);

        // As seen in BorrowerOperations._pullCollAndSendToActivePool(), we need to transfer the collateral to the ActivePool.
        vm.startPrank(address(borrowerOperations));
        weth.transfer(address(aeroActivePool), amount);
        aeroActivePool.accountForReceivedColl(amount);
        vm.stopPrank();
    }

    function setUp() public override {
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

        // Use a single WETH branch, but mark it as Aero LP collateral so ActivePool will stake/withdraw via AeroManager.
        weth = new WETHTester(
            100 ether, // _tapAmount
            1 days // _tapPeriod
        );

        gauge = new AeroGaugeTester(address(weth), deployer.AERO_TOKEN_ADDRESS());
        aeroToken = MockAeroToken(gauge.rewardToken());

        TestDeployer.TroveManagerParams[] memory troveManagerParamsArray = new TestDeployer.TroveManagerParams[](1);
        troveManagerParamsArray[0] = TestDeployer.TroveManagerParams(
            150e16, // CCR
            110e16, // MCR
            10e16, // BCR
            110e16, // SCR
            100_000_000 ether, // debtLimit
            5e16, // LIQUIDATION_PENALTY_SP
            10e16, // LIQUIDATION_PENALTY_REDISTRIBUTION
            true, // isAeroLPCollateral
            address(gauge) // aeroGaugeAddress
        );

        TestDeployer.DeployAndConnectContractsResults memory result =
            deployer.deployAndConnectContracts(troveManagerParamsArray, IWETH(address(weth)));

        // Wire up BaseTest variables (pattern copied from other test files)
        TestDeployer.LiquityContractsDev memory contracts = result.contractsArray[0];

        aeroManager = result.aeroManager;
        collateralRegistry = result.collateralRegistry;
        boldToken = result.boldToken;
        hintHelpers = result.hintHelpers;
        aeroManagerImpl = AeroManager(address(aeroManager));

        addressesRegistry = contracts.addressesRegistry;
        collToken = contracts.collToken;
        activePool = contracts.activePool;
        borrowerOperations = contracts.borrowerOperations;
        collSurplusPool = contracts.pools.collSurplusPool;
        defaultPool = contracts.pools.defaultPool;
        gasPool = contracts.pools.gasPool;
        priceFeed = contracts.priceFeed;
        sortedTroves = contracts.sortedTroves;
        stabilityPool = contracts.stabilityPool;
        troveManager = contracts.troveManager;
        troveNFT = contracts.troveNFT;
        metadataNFT = addressesRegistry.metadataNFT();
        mockInterestRouter = contracts.interestRouter;

        WETH = IWETH(address(weth));

        // Cache commonly used addresses
        governor = aeroManagerImpl.governor();
        treasury = aeroManagerImpl.treasuryAddress();
        collateralRegistryAddress = address(collateralRegistry);
        aeroActivePool = IActivePool(address(activePool));

        // Give some Coll to test accounts, and approve it to BorrowerOperations
        uint256 initialCollAmount = 10_000_000e18;
        for (uint256 i = 0; i < 6; i++) {
            giveAndApproveCollateral(IERC20(address(weth)), accountsList[i], initialCollAmount, address(borrowerOperations));
        }
    }

    function test_addActivePool_revertsIfNotCollateralRegistry() public {
        vm.expectRevert("AeroManager: Caller is not the collateral registry");
        aeroManager.addActivePool(address(aeroActivePool));
    }

    function test_addActivePool_asCollateralRegistry_revertsAlreadyAdded() public {
        // This ActivePool gets auto-added during `aeroManager.setAddresses(...)` in deployment.
        assertTrue(aeroManagerImpl.activePools(address(aeroActivePool)));

        vm.prank(collateralRegistryAddress);
        vm.expectRevert("AeroManager: ActivePool already added");
        aeroManagerImpl.addActivePool(address(aeroActivePool));
    }

    function test_updateClaimFee_revertsIfNotGovernor() public {
        uint256 oldFee = aeroManagerImpl.claimFee();
        uint256 newFee = oldFee - 1e16;
        vm.expectRevert("AeroManager: Caller is not the governor");
        aeroManagerImpl.updateClaimFee(newFee);
    }

    function test_updateClaimFee_lowerUpdatesImmediately() public {
        uint256 oldFee = aeroManagerImpl.claimFee();
        uint256 newFee = oldFee / 2;

        vm.prank(governor);
        aeroManagerImpl.updateClaimFee(newFee);

        assertEq(aeroManagerImpl.claimFee(), newFee);
        assertEq(aeroManagerImpl.pendingNewClaimFee(), 0);
        assertEq(aeroManagerImpl.pendingNewClaimFeeTimestamp(), 0);
    }

    function test_updateClaimFee_higherRequiresDelay_thenAccept() public {
        uint256 oldFee = aeroManagerImpl.claimFee();
        uint256 newFee = oldFee + 1e16;

        vm.prank(governor);
        aeroManagerImpl.updateClaimFee(newFee);

        assertEq(aeroManagerImpl.claimFee(), oldFee);
        assertEq(aeroManagerImpl.pendingNewClaimFee(), newFee);

        vm.prank(governor);
        vm.expectRevert("AeroManager: Claim fee update delay period not passed");
        aeroManagerImpl.acceptClaimFeeUpdate();

        vm.warp(block.timestamp + aeroManagerImpl.claimFeeChangeDelayPeriod());
        vm.prank(governor);
        aeroManagerImpl.acceptClaimFeeUpdate();

        assertEq(aeroManagerImpl.claimFee(), newFee);
        assertEq(aeroManagerImpl.pendingNewClaimFee(), 0);
        assertEq(aeroManagerImpl.pendingNewClaimFeeTimestamp(), 0);
    }

    function test_stake_asActivePool_stakesIntoGaugeAndTracksAmount() public {
        uint256 amount = 10e18;

        // Fund BorrowerOperations and push collateral into ActivePool as BorrowerOperations (ActivePool requirement).
        deal(address(weth), address(borrowerOperations), amount);
        
        // As seen in BorrowerOperations._pullCollAndSendToActivePool(), we need to transfer the collateral to the ActivePool.
        vm.startPrank(address(borrowerOperations));
        weth.transfer(address(aeroActivePool), amount);
        aeroActivePool.accountForReceivedColl(amount);
        vm.stopPrank();

        assertEq(aeroManagerImpl.stakedAmounts(address(gauge)), amount);
        assertEq(weth.balanceOf(address(gauge)), amount);
        assertEq(weth.balanceOf(address(aeroActivePool)), 0);
    }

    function test_withdraw_asActivePool_withdrawsFromGaugeAndReturnsTokens() public {
        uint256 amount = 10e18;
        uint256 withdrawAmount = 4e18;

        // Stake via ActivePool.receiveColl()
        deal(address(weth), address(borrowerOperations), amount);
        
        // As seen in BorrowerOperations._pullCollAndSendToActivePool(), we need to transfer the collateral to the ActivePool.
        vm.startPrank(address(borrowerOperations));
        weth.transfer(address(aeroActivePool), amount);
        aeroActivePool.accountForReceivedColl(amount);
        vm.stopPrank();

        uint256 preRecipient = weth.balanceOf(A);

        // Withdraw is triggered by ActivePool sending collateral out (it calls AeroManager.withdraw internally).
        vm.prank(address(borrowerOperations));
        aeroActivePool.sendColl(A, withdrawAmount);

        assertEq(aeroManagerImpl.stakedAmounts(address(gauge)), amount - withdrawAmount);
        assertEq(weth.balanceOf(A), preRecipient + withdrawAmount);
        assertEq(weth.balanceOf(address(gauge)), amount - withdrawAmount);
    }

    function test_claim_transfersFeeToTreasury_andAccountsRewards() public {
        uint256 amount = 10e18;

        // Stake via ActivePool.receiveColl() so the "caller is ActivePool" path is exercised end-to-end.
        _stakeThroughActivePool(amount);

        uint256 preTreasury = aeroToken.balanceOf(treasury);
        uint256 preManager = aeroToken.balanceOf(address(aeroManager));

        aeroManagerImpl.claim(address(gauge));

        uint256 claimedAmount = amount; // AeroGaugeTester mints reward == deposited balance
        uint256 fee = claimedAmount * aeroManagerImpl.claimFee() / 1e18;
        uint256 rewardAmount = claimedAmount - fee;

        assertEq(aeroToken.balanceOf(treasury), preTreasury + fee);
        assertEq(aeroToken.balanceOf(address(aeroManagerImpl)), preManager + rewardAmount);
        assertEq(aeroManagerImpl.claimedAero(), rewardAmount);
        assertEq(aeroManagerImpl.claimedAeroPerEpoch(0, address(gauge)), rewardAmount);
    }

    function test_distributeAero_incrementsEpoch_setsClaimable_and_userCanClaim() public {
        uint256 amount = 10e18;
        _stakeThroughActivePool(amount);

        // Create rewards for epoch 0
        aeroManagerImpl.claim(address(gauge));

        uint256 epoch0 = aeroManagerImpl.currentEpochs(address(gauge));
        assertEq(epoch0, 0);

        uint256 rewardEpoch0 = aeroManagerImpl.claimedAeroPerEpoch(epoch0, address(gauge));
        assertGt(rewardEpoch0, 0);

        vm.prank(governor);
        aeroManagerImpl.closeCurrentEpoch(address(gauge));

        // Allocate all epoch-0 rewards
        AeroManager.AeroRecipient[] memory recipients = new AeroManager.AeroRecipient[](2);
        uint256 aAmt = rewardEpoch0 / 3;
        uint256 bAmt = rewardEpoch0 - aAmt;
        recipients[0] = AeroManager.AeroRecipient({borrower: A, amount: aAmt});
        recipients[1] = AeroManager.AeroRecipient({borrower: B, amount: bAmt});

        vm.prank(governor);
        aeroManagerImpl.distributeAero(address(gauge), recipients);

        // Epoch incremented
        assertEq(aeroManagerImpl.currentEpochs(address(gauge)), epoch0 + 1);

        // Allocations recorded
        assertEq(aeroManagerImpl.claimableRewards(A), aAmt);
        assertEq(aeroManagerImpl.claimableRewards(B), bAmt);

        // Users can claim
        uint256 preA = aeroToken.balanceOf(A);
        uint256 preB = aeroToken.balanceOf(B);

        aeroManagerImpl.claimRewards(A);
        aeroManagerImpl.claimRewards(B);

        assertEq(aeroToken.balanceOf(A), preA + aAmt);
        assertEq(aeroToken.balanceOf(B), preB + bAmt);
        assertEq(aeroManagerImpl.claimableRewards(A), 0);
        assertEq(aeroManagerImpl.claimableRewards(B), 0);
    }

    function test_claimRewards_accruesAcrossMultipleEpochs_thenClaimsOnce() public {
        uint256 amount = 10e18;
        _stakeThroughActivePool(amount);

        // ---- Epoch 0 ----
        aeroManagerImpl.claim(address(gauge));
        uint256 epoch0 = aeroManagerImpl.currentEpochs(address(gauge));
        assertEq(epoch0, 0);
        uint256 reward0 = aeroManagerImpl.claimedAeroPerEpoch(epoch0, address(gauge));
        assertGt(reward0, 0);

        vm.prank(governor);
        aeroManagerImpl.closeCurrentEpoch(address(gauge));

        uint256 a0 = reward0 / 2;
        uint256 b0 = reward0 - a0;
        AeroManager.AeroRecipient[] memory recipients0 = new AeroManager.AeroRecipient[](2);
        recipients0[0] = AeroManager.AeroRecipient({borrower: A, amount: a0});
        recipients0[1] = AeroManager.AeroRecipient({borrower: B, amount: b0});
        vm.prank(governor);
        aeroManagerImpl.distributeAero(address(gauge), recipients0);
        assertEq(aeroManagerImpl.currentEpochs(address(gauge)), 1);

        // ---- Epoch 1 ----
        aeroManagerImpl.claim(address(gauge));
        uint256 epoch1 = aeroManagerImpl.currentEpochs(address(gauge));
        assertEq(epoch1, 1);
        uint256 reward1 = aeroManagerImpl.claimedAeroPerEpoch(epoch1, address(gauge));
        assertGt(reward1, 0);

        vm.prank(governor);
        aeroManagerImpl.closeCurrentEpoch(address(gauge));

        uint256 a1 = reward1 / 4;
        uint256 b1 = reward1 - a1;
        AeroManager.AeroRecipient[] memory recipients1 = new AeroManager.AeroRecipient[](2);
        recipients1[0] = AeroManager.AeroRecipient({borrower: A, amount: a1});
        recipients1[1] = AeroManager.AeroRecipient({borrower: B, amount: b1});
        vm.prank(governor);
        aeroManagerImpl.distributeAero(address(gauge), recipients1);
        assertEq(aeroManagerImpl.currentEpochs(address(gauge)), 2);

        // Claimable should include both epochs (we didn't claim in-between)
        assertEq(aeroManagerImpl.claimableRewards(A), a0 + a1);
        assertEq(aeroManagerImpl.claimableRewards(B), b0 + b1);

        uint256 preA = aeroToken.balanceOf(A);
        uint256 preB = aeroToken.balanceOf(B);

        aeroManagerImpl.claimRewards(A);
        aeroManagerImpl.claimRewards(B);

        assertEq(aeroToken.balanceOf(A), preA + a0 + a1);
        assertEq(aeroToken.balanceOf(B), preB + b0 + b1);
        assertEq(aeroManagerImpl.claimableRewards(A), 0);
        assertEq(aeroManagerImpl.claimableRewards(B), 0);
    }

    // --- Constructor (isolated deploy; branch coverage on `require`s) ---

    function test_constructor_revertsWhenTreasuryIsZero() public {
        vm.expectRevert("AeroManager: Treasury address cannot be 0");
        new AeroManager(address(aeroToken), governor, address(0));
    }

    function test_constructor_revertsWhenAeroTokenIsZero() public {
        vm.expectRevert("AeroManager: Aero token address cannot be 0");
        new AeroManager(address(0), governor, treasury);
    }

    // --- Access control on stake / withdraw ---

    function test_stake_revertsIfCallerNotActivePool() public {
        vm.expectRevert("AeroManager: Caller is not an active pool");
        vm.prank(A);
        aeroManagerImpl.stake(address(gauge), address(weth), 1);
    }

    function test_withdraw_revertsIfCallerNotActivePool() public {
        vm.expectRevert("AeroManager: Caller is not an active pool");
        vm.prank(A);
        aeroManagerImpl.withdraw(address(gauge), address(weth), 1);
    }

    // --- claim / epoch ---

    function test_claim_revertsWhenCurrentEpochClosed() public {
        _stakeThroughActivePool(10e18);
        aeroManagerImpl.claim(address(gauge));
        vm.prank(governor);
        aeroManagerImpl.closeCurrentEpoch(address(gauge));
        vm.expectRevert("AeroManager: Current epoch is already closed");
        aeroManagerImpl.claim(address(gauge));
    }

    function test_claim_revertsWhenGaugeRewardTokenMismatch() public {
        MockAeroToken wrongReward = new MockAeroToken();
        AeroGaugeTester wrongGauge = new AeroGaugeTester(address(weth), address(wrongReward));
        vm.expectRevert("AeroManager: Reward token does not match");
        aeroManagerImpl.claim(address(wrongGauge));
    }

    function test_closeCurrentEpoch_revertsWhenAlreadyClosed() public {
        vm.prank(governor);
        aeroManagerImpl.closeCurrentEpoch(address(gauge));
        vm.prank(governor);
        vm.expectRevert("AeroManager: Current epoch is already closed");
        aeroManagerImpl.closeCurrentEpoch(address(gauge));
    }

    function test_closeCurrentEpoch_revertsIfNotGovernor() public {
        vm.expectRevert("AeroManager: Caller is not the governor");
        aeroManagerImpl.closeCurrentEpoch(address(gauge));
    }

    // --- distributeAero ---

    function test_distributeAero_revertsWhenEpochNotClosed() public {
        AeroManager.AeroRecipient[] memory recipients = new AeroManager.AeroRecipient[](1);
        recipients[0] = AeroManager.AeroRecipient({borrower: A, amount: 1});
        vm.prank(governor);
        vm.expectRevert("AeroManager: Current epoch is not closed yet to distribute rewards");
        aeroManagerImpl.distributeAero(address(gauge), recipients);
    }

    function test_distributeAero_revertsWhenNoRecipients() public {
        vm.prank(governor);
        aeroManagerImpl.closeCurrentEpoch(address(gauge));
        vm.prank(governor);
        vm.expectRevert("AeroManager: No recipients");
        aeroManagerImpl.distributeAero(address(gauge), new AeroManager.AeroRecipient[](0));
    }

    function test_distributeAero_revertsWhenRecipientAmountExceedsReward() public {
        _stakeThroughActivePool(10e18);
        aeroManagerImpl.claim(address(gauge));
        uint256 reward = aeroManagerImpl.claimedAeroPerEpoch(0, address(gauge));
        vm.prank(governor);
        aeroManagerImpl.closeCurrentEpoch(address(gauge));
        AeroManager.AeroRecipient[] memory recipients = new AeroManager.AeroRecipient[](1);
        recipients[0] = AeroManager.AeroRecipient({borrower: A, amount: reward + 1});
        vm.prank(governor);
        vm.expectRevert("AeroManager: Total amount exceeds reward amount");
        aeroManagerImpl.distributeAero(address(gauge), recipients);
    }

    function test_distributeAero_revertsWhenRewardNotFullyDistributed() public {
        _stakeThroughActivePool(10e18);
        aeroManagerImpl.claim(address(gauge));
        uint256 reward = aeroManagerImpl.claimedAeroPerEpoch(0, address(gauge));
        vm.prank(governor);
        aeroManagerImpl.closeCurrentEpoch(address(gauge));
        AeroManager.AeroRecipient[] memory recipients = new AeroManager.AeroRecipient[](1);
        recipients[0] = AeroManager.AeroRecipient({borrower: A, amount: reward - 1});
        vm.prank(governor);
        vm.expectRevert("AeroManager: Reward amount not fully distributed");
        aeroManagerImpl.distributeAero(address(gauge), recipients);
    }

    function test_distributeAero_revertsIfNotGovernor() public {
        _stakeThroughActivePool(10e18);
        aeroManagerImpl.claim(address(gauge));
        uint256 reward = aeroManagerImpl.claimedAeroPerEpoch(0, address(gauge));
        vm.prank(governor);
        aeroManagerImpl.closeCurrentEpoch(address(gauge));
        AeroManager.AeroRecipient[] memory recipients = new AeroManager.AeroRecipient[](1);
        recipients[0] = AeroManager.AeroRecipient({borrower: A, amount: reward});
        vm.expectRevert("AeroManager: Caller is not the governor");
        aeroManagerImpl.distributeAero(address(gauge), recipients);
    }

    // --- claimRewards ---

    function test_claimRewards_revertsWhenNothingToClaim() public {
        vm.expectRevert("AeroManager: No rewards to claim");
        aeroManagerImpl.claimRewards(A);
    }

    // --- claim fee ---

    function test_updateClaimFee_revertsWhenUnchanged() public {
        uint256 f = aeroManagerImpl.claimFee();
        vm.prank(governor);
        vm.expectRevert("AeroManager: New fee is the same as the current fee");
        aeroManagerImpl.updateClaimFee(f);
    }

    function test_updateClaimFee_revertsWhenAboveMax() public {
        vm.prank(governor);
        vm.expectRevert("AeroManager: Fee is greater than max aero manager fee limit");
        aeroManagerImpl.updateClaimFee(MAX_AERO_MANAGER_FEE + 1);
    }

    function test_updateClaimFee_toMax_thenAcceptAfterDelay() public {
        vm.prank(governor);
        aeroManagerImpl.updateClaimFee(MAX_AERO_MANAGER_FEE);
        vm.warp(block.timestamp + aeroManagerImpl.claimFeeChangeDelayPeriod());
        vm.prank(governor);
        aeroManagerImpl.acceptClaimFeeUpdate();
        assertEq(aeroManagerImpl.claimFee(), MAX_AERO_MANAGER_FEE);
    }

    function test_acceptClaimFeeUpdate_revertsWhenNoPending() public {
        vm.prank(governor);
        vm.expectRevert("AeroManager: No pending claim fee update");
        aeroManagerImpl.acceptClaimFeeUpdate();
    }

    function test_acceptClaimFeeUpdate_revertsWhenDelayNotPassed() public {
        uint256 oldFee = aeroManagerImpl.claimFee();
        uint256 newFee = oldFee + 1e16;
        vm.prank(governor);
        aeroManagerImpl.updateClaimFee(newFee);
        vm.prank(governor);
        vm.expectRevert("AeroManager: Claim fee update delay period not passed");
        aeroManagerImpl.acceptClaimFeeUpdate();
    }

    // --- AERO token address rotation ---

    function test_setAeroTokenAddress_revertsWhenZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert("AeroManager: Aero token address cannot be 0");
        aeroManagerImpl.setAeroTokenAddress(address(0));
    }

    function test_setAeroTokenAddress_revertsWhenSameAsCurrent() public {
        address cur = aeroManagerImpl.aeroTokenAddress();
        vm.prank(governor);
        vm.expectRevert("AeroManager: New aero token address is the same as the current aero token address");
        aeroManagerImpl.setAeroTokenAddress(cur);
    }

    function test_acceptAeroTokenAddressUpdate_revertsWhenNoPending() public {
        vm.prank(governor);
        vm.expectRevert("AeroManager: No pending aero token address update");
        aeroManagerImpl.acceptAeroTokenAddressUpdate();
    }

    function test_acceptAeroTokenAddressUpdate_revertsWhenDelayNotPassed() public {
        MockAeroToken newTok = new MockAeroToken();
        vm.prank(governor);
        aeroManagerImpl.setAeroTokenAddress(address(newTok));
        vm.prank(governor);
        vm.expectRevert("AeroManager: Aero token address update delay period not passed");
        aeroManagerImpl.acceptAeroTokenAddressUpdate();
    }

    function test_acceptAeroTokenAddressUpdate_succeedsAfterDelay() public {
        MockAeroToken newTok = new MockAeroToken();
        vm.prank(governor);
        aeroManagerImpl.setAeroTokenAddress(address(newTok));
        vm.warp(block.timestamp + aeroManagerImpl.aeroTokenChangeDelayPeriod());
        vm.prank(governor);
        aeroManagerImpl.acceptAeroTokenAddressUpdate();
        assertEq(aeroManagerImpl.aeroTokenAddress(), address(newTok));
        assertEq(aeroManagerImpl.pendingAeroTokenAddress(), address(0));
    }

    // --- Governor ---

    function test_setGovernor_updatesGovernor() public {
        address newGov = address(0xBEEF);
        vm.prank(governor);
        aeroManagerImpl.setGovernor(newGov);
        assertEq(aeroManagerImpl.governor(), newGov);
    }

    // --- Gauge killed / revived (Voter.isAlive), unstaked buffer, _stakeRemaining ---

    function test_isAeroGaugeAlive_followsMockVoter() public {
        assertTrue(aeroManagerImpl.isAeroGaugeAlive(address(gauge)));
        gauge.aeroVoter().setGaugeAlive(address(gauge), false);
        assertFalse(aeroManagerImpl.isAeroGaugeAlive(address(gauge)));
        gauge.aeroVoter().setGaugeAlive(address(gauge), true);
        assertTrue(aeroManagerImpl.isAeroGaugeAlive(address(gauge)));
    }

    function test_stake_whenGaugeKilled_holdsUnstaked_doesNotTouchGauge() public {
        gauge.aeroVoter().setGaugeAlive(address(gauge), false);
        uint256 amount = 7e18;
        _stakeThroughActivePool(amount);

        assertEq(aeroManagerImpl.unstakedAmounts(address(gauge)), amount);
        assertEq(aeroManagerImpl.stakedAmounts(address(gauge)), 0);
        assertEq(weth.balanceOf(address(gauge)), 0);
        assertEq(weth.balanceOf(address(aeroManagerImpl)), amount);
    }

    function test_stake_whenGaugeRevived_afterKill_restakesPriorUnstaked() public {
        gauge.aeroVoter().setGaugeAlive(address(gauge), false);
        uint256 first = 4e18;
        _stakeThroughActivePool(first);
        assertEq(aeroManagerImpl.unstakedAmounts(address(gauge)), first);

        gauge.aeroVoter().setGaugeAlive(address(gauge), true);
        uint256 second = 3e18;
        deal(address(weth), address(borrowerOperations), second);
        vm.startPrank(address(borrowerOperations));
        weth.transfer(address(aeroActivePool), second);
        aeroActivePool.accountForReceivedColl(second);
        vm.stopPrank();

        assertEq(aeroManagerImpl.stakedAmounts(address(gauge)), first + second);
        assertEq(aeroManagerImpl.unstakedAmounts(address(gauge)), 0);
        assertEq(weth.balanceOf(address(gauge)), first + second);
        assertEq(weth.balanceOf(address(aeroManagerImpl)), 0);
    }

    function test_withdraw_fromUnstakedOnly_whenGaugeAlive_restakesLeftovers() public {
        gauge.aeroVoter().setGaugeAlive(address(gauge), false);
        _stakeThroughActivePool(10e18);
        assertEq(aeroManagerImpl.unstakedAmounts(address(gauge)), 10e18);

        gauge.aeroVoter().setGaugeAlive(address(gauge), true);

        uint256 preRecipient = weth.balanceOf(A);
        vm.prank(address(borrowerOperations));
        aeroActivePool.sendColl(A, 4e18);

        assertEq(aeroManagerImpl.unstakedAmounts(address(gauge)), 0);
        assertEq(aeroManagerImpl.stakedAmounts(address(gauge)), 6e18);
        assertEq(weth.balanceOf(A), preRecipient + 4e18);
        assertEq(weth.balanceOf(address(gauge)), 6e18);
    }

    function test_withdraw_mixed_unstakedAndStaked_pullsShortfallFromGauge() public {
        gauge.aeroVoter().setGaugeAlive(address(gauge), false);
        _stakeThroughActivePool(3e18);
        gauge.aeroVoter().setGaugeAlive(address(gauge), true);
        deal(address(weth), address(borrowerOperations), 10e18);
        vm.startPrank(address(borrowerOperations));
        weth.transfer(address(aeroActivePool), 10e18);
        aeroActivePool.accountForReceivedColl(10e18);
        vm.stopPrank();

        assertEq(aeroManagerImpl.stakedAmounts(address(gauge)), 13e18);

        gauge.aeroVoter().setGaugeAlive(address(gauge), false);
        deal(address(weth), address(borrowerOperations), 2e18);
        vm.startPrank(address(borrowerOperations));
        weth.transfer(address(aeroActivePool), 2e18);
        aeroActivePool.accountForReceivedColl(2e18);
        vm.stopPrank();
        assertEq(aeroManagerImpl.unstakedAmounts(address(gauge)), 2e18);

        vm.prank(address(borrowerOperations));
        aeroActivePool.sendColl(A, 5e18);

        assertEq(aeroManagerImpl.unstakedAmounts(address(gauge)), 0);
        assertEq(aeroManagerImpl.stakedAmounts(address(gauge)), 10e18);
    }

    function test_withdraw_whenGaugeKilled_usesGaugeForAmountBeyondUnstaked() public {
        _stakeThroughActivePool(8e18);
        gauge.aeroVoter().setGaugeAlive(address(gauge), false);
        deal(address(weth), address(borrowerOperations), 2e18);
        vm.startPrank(address(borrowerOperations));
        weth.transfer(address(aeroActivePool), 2e18);
        aeroActivePool.accountForReceivedColl(2e18);
        vm.stopPrank();

        assertEq(aeroManagerImpl.unstakedAmounts(address(gauge)), 2e18);
        assertEq(aeroManagerImpl.stakedAmounts(address(gauge)), 8e18);

        uint256 preA = weth.balanceOf(A);
        vm.prank(address(borrowerOperations));
        aeroActivePool.sendColl(A, 7e18);

        assertEq(weth.balanceOf(A), preA + 7e18);
        assertEq(aeroManagerImpl.stakedAmounts(address(gauge)), 3e18);
        assertEq(aeroManagerImpl.unstakedAmounts(address(gauge)), 0);
    }
}