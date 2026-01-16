// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestContracts/DevTestSetup.sol";
import "./TestContracts/AeroGaugeTester.sol";
import "./TestContracts/WETHTester.sol";
import "src/AeroManager.sol";

contract AeroManagerTest is DevTestSetup {
    AeroGaugeTester internal gauge;
    MockAeroToken internal aeroToken;
    IActivePool internal aeroActivePool;
    WETHTester internal weth;
    AeroManager internal aeroManagerImpl;

    address internal governor;
    address internal treasury;
    address internal collateralRegistryAddress;

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
        deal(address(weth), address(borrowerOperations), amount);
        
        // As seen in BorrowerOperations._pullCollAndSendToActivePool(), we need to transfer the collateral to the ActivePool.
        vm.startPrank(address(borrowerOperations));
        weth.transfer(address(aeroActivePool), amount);
        aeroActivePool.accountForReceivedColl(amount);
        vm.stopPrank();

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
}