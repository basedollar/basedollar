// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TestContracts/DevTestSetup.sol";
import "./TestContracts/Deployment.t.sol";
import {ERC20Faucet} from "./TestContracts/ERC20Faucet.sol";
import "./TestContracts/MockAddressesRegistryForCR.sol";
import "./TestContracts/MockAeroGaugeForCR.sol";
import "src/CollateralRegistry.sol";
import "src/Interfaces/IAddressesRegistry.sol";
import "src/MultiTroveGetter.sol";
import "src/Interfaces/IAeroManager.sol";
import "src/Interfaces/IMultiTroveGetter.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {CollateralRegistryTester} from "./TestContracts/CollateralRegistryTester.sol";
import {AeroManager} from "src/AeroManager.sol";
import {DECIMAL_PRECISION, ONE_MINUTE, REDEMPTION_FEE_FLOOR} from "src/Dependencies/Constants.sol";

contract CollateralRegistryExtendedCoverageTest is DevTestSetup {
    address internal gov;
    IMultiTroveGetter internal multiTroveGetterCached;

    function _collMeta() internal view returns (IERC20Metadata) {
        return IERC20Metadata(address(collToken));
    }

    event CollateralGovernorUpdated(address oldGovernor, address newGovernor);
    event CollateralBranchAdded(
        uint256 totalCollaterals, uint256 index, IERC20Metadata token, ITroveManager troveManager, bool isRedeemable
    ); // matches CollateralRegistry.CollateralBranchAdded (no indexed topics)
    event LastFeeOpTimeUpdated(uint256 lastFeeOpTime);

    function setUp() public override {
        super.setUp();
        gov = makeAddr("GOVERNOR");
        multiTroveGetterCached = IMultiTroveGetter(address(new MultiTroveGetter(collateralRegistry)));
    }

    function _freshDeployer() internal returns (TestDeployer) {
        return new TestDeployer();
    }

    function _lstToken(string memory sym) internal returns (IERC20Metadata) {
        return new ERC20Faucet("LST Tester", sym, 100 ether, 1 days);
    }

    function _deployExtraBranch(TestDeployer d, IERC20Metadata lst, TestDeployer.AeroParams memory ap)
        internal
        returns (TestDeployer.LiquityContractsDev memory c)
    {
        TestDeployer.TroveManagerParams memory p = TestDeployer.TroveManagerParams({
            CCR: 160e16,
            MCR: 120e16,
            BCR: 10e16,
            SCR: 120e16,
            debtLimit: 1_000_000 ether,
            LIQUIDATION_PENALTY_SP: 5e16,
            LIQUIDATION_PENALTY_REDISTRIBUTION: 10e16,
            isAeroLPCollateral: ap.isAeroLPCollateral,
            aeroGaugeAddress: ap.aeroGaugeAddress
        });
        (c,) = d.deployAdditionalBranchDev(p, lst, boldToken, collateralRegistry, WETH, hintHelpers, multiTroveGetterCached, ap);
    }

    function test_createNewBranch_redeemable_registersBoldAndIncreasesTotal() public {
        TestDeployer d = _freshDeployer();
        IERC20Metadata lst = _lstToken("L2");
        TestDeployer.AeroParams memory ap = TestDeployer.AeroParams(aeroManager, false, address(0));
        TestDeployer.LiquityContractsDev memory c = _deployExtraBranch(d, lst, ap);

        assertEq(collateralRegistry.totalCollaterals(), 1);

        vm.expectEmit(false, false, false, true);
        emit CollateralBranchAdded(2, 1, lst, c.troveManager, true);

        vm.prank(gov);
        CollateralRegistry(address(collateralRegistry)).createNewBranch(c.addressesRegistry, true);

        assertEq(collateralRegistry.totalCollaterals(), 2);
        assertEq(address(collateralRegistry.getToken(1)), address(lst));
        assertEq(address(collateralRegistry.getTroveManager(1)), address(c.troveManager));
    }

    function test_createNewBranch_nonRedeemable_tracksSeparately() public {
        TestDeployer d = _freshDeployer();
        IERC20Metadata lst = _lstToken("NR");
        TestDeployer.AeroParams memory ap = TestDeployer.AeroParams(aeroManager, false, address(0));
        TestDeployer.LiquityContractsDev memory c = _deployExtraBranch(d, lst, ap);

        vm.prank(gov);
        CollateralRegistry(address(collateralRegistry)).createNewBranch(c.addressesRegistry, false);

        assertEq(address(collateralRegistry.getNonRedeemableToken(0)), address(lst));
        assertEq(address(collateralRegistry.getNonRedeemableTroveManager(0)), address(c.troveManager));
        ITroveManager[] memory nrs = collateralRegistry.getNonRedeemableTroveManagers();
        assertEq(nrs.length, 1);
        assertEq(address(nrs[0]), address(c.troveManager));
    }

    function test_getAllTroveManagers_ordersRedeemableThenNonRedeemable() public {
        TestDeployer d = _freshDeployer();
        IERC20Metadata lst = _lstToken("ALL");
        TestDeployer.AeroParams memory ap = TestDeployer.AeroParams(aeroManager, false, address(0));
        TestDeployer.LiquityContractsDev memory c = _deployExtraBranch(d, lst, ap);

        vm.prank(gov);
        CollateralRegistry(address(collateralRegistry)).createNewBranch(c.addressesRegistry, false);

        ITroveManager[] memory all = CollateralRegistry(address(collateralRegistry)).getAllTroveManagers();
        assertEq(all.length, 2);
        assertEq(address(all[0]), address(troveManager));
        assertEq(address(all[1]), address(c.troveManager));
    }

    function test_createNewBranch_aeroLpCollateral_callsAeroManagerAddActivePool() public {
        TestDeployer d = _freshDeployer();
        IERC20Metadata lst = _lstToken("AERO");
        MockAeroGaugeForCR gauge = new MockAeroGaugeForCR(address(lst), AeroManager(address(aeroManager)).aeroTokenAddress());
        TestDeployer.AeroParams memory ap = TestDeployer.AeroParams(aeroManager, true, address(gauge));
        TestDeployer.LiquityContractsDev memory c = _deployExtraBranch(d, lst, ap);

        vm.expectCall(address(aeroManager), abi.encodeCall(IAeroManager.addActivePool, (address(c.activePool))));

        vm.prank(gov);
        CollateralRegistry(address(collateralRegistry)).createNewBranch(c.addressesRegistry, true);
    }

    function test_createNewBranch_revertsIfNotCollateralGovernor() public {
        TestDeployer d = _freshDeployer();
        IERC20Metadata lst = _lstToken("X");
        TestDeployer.AeroParams memory ap = TestDeployer.AeroParams(aeroManager, false, address(0));
        TestDeployer.LiquityContractsDev memory c = _deployExtraBranch(d, lst, ap);

        vm.prank(A);
        vm.expectRevert("CR: Only collateral governor can create new branches");
        CollateralRegistry(address(collateralRegistry)).createNewBranch(c.addressesRegistry, true);
    }

    function test_createNewBranch_validationReverts() public {
        MockAddressesRegistryForCR mock = new MockAddressesRegistryForCR();
        vm.prank(gov);
        vm.expectRevert("CR: Token cannot be the zero address");
        CollateralRegistry(address(collateralRegistry)).createNewBranch(IAddressesRegistry(address(mock)), true);

        mock.configure(
            IERC20Metadata(address(0)),
            troveManager,
            stabilityPool,
            borrowerOperations,
            activePool
        );
        vm.prank(gov);
        vm.expectRevert("CR: Token cannot be the zero address");
        CollateralRegistry(address(collateralRegistry)).createNewBranch(IAddressesRegistry(address(mock)), true);

        mock.configure(
            _collMeta(),
            ITroveManager(address(0)),
            stabilityPool,
            borrowerOperations,
            activePool
        );
        vm.prank(gov);
        vm.expectRevert("CR: Trove manager cannot be the zero address");
        CollateralRegistry(address(collateralRegistry)).createNewBranch(IAddressesRegistry(address(mock)), true);

        mock.configure(IERC20Metadata(address(boldToken)), troveManager, stabilityPool, borrowerOperations, activePool);
        vm.prank(gov);
        vm.expectRevert("CR: Token cannot be the bold token");
        CollateralRegistry(address(collateralRegistry)).createNewBranch(IAddressesRegistry(address(mock)), true);

        mock.configure(_collMeta(), troveManager, IStabilityPool(address(0)), borrowerOperations, activePool);
        vm.prank(gov);
        vm.expectRevert("CR: Stability pool cannot be the zero address");
        CollateralRegistry(address(collateralRegistry)).createNewBranch(IAddressesRegistry(address(mock)), true);

        mock.configure(_collMeta(), troveManager, stabilityPool, IBorrowerOperations(address(0)), activePool);
        vm.prank(gov);
        vm.expectRevert("CR: Borrower operations cannot be the zero address");
        CollateralRegistry(address(collateralRegistry)).createNewBranch(IAddressesRegistry(address(mock)), true);

        mock.configure(_collMeta(), troveManager, stabilityPool, borrowerOperations, IActivePool(address(0)));
        vm.prank(gov);
        vm.expectRevert("CR: Active pool cannot be the zero address");
        CollateralRegistry(address(collateralRegistry)).createNewBranch(IAddressesRegistry(address(mock)), true);

        IActivePool wrongAp = IActivePool(address(uint160(uint256(keccak256("wrongAp")))));
        mock.configure(_collMeta(), troveManager, stabilityPool, borrowerOperations, wrongAp);
        vm.prank(gov);
        vm.expectRevert("CR: Active pool does not match trove manager");
        CollateralRegistry(address(collateralRegistry)).createNewBranch(IAddressesRegistry(address(mock)), true);
    }

    function test_updateCollateralGovernor_emitsAndUpdates() public {
        address next = makeAddr("NEXT_COLLATERAL_GOV");
        vm.prank(gov);
        vm.expectEmit(false, false, false, true);
        emit CollateralGovernorUpdated(gov, next);
        CollateralRegistry(address(collateralRegistry)).updateCollateralGovernor(next);
        assertEq(CollateralRegistry(address(collateralRegistry)).collateralGovernor(), next);
    }

    function test_updateNonRedeemableDebtLimit_increaseBeyond2xAndAboveInitial_reverts() public {
        TestDeployer d = _freshDeployer();
        IERC20Metadata lst = _lstToken("DL");
        TestDeployer.AeroParams memory ap = TestDeployer.AeroParams(aeroManager, false, address(0));
        TestDeployer.LiquityContractsDev memory c = _deployExtraBranch(d, lst, ap);

        vm.prank(gov);
        CollateralRegistry(address(collateralRegistry)).createNewBranch(c.addressesRegistry, false);

        vm.startPrank(gov);
        collateralRegistry.updateNonRedeemableDebtLimit(0, 400_000 ether);
        vm.expectRevert("CollateralRegistry: Debt limit increase by more than 2x is not allowed");
        collateralRegistry.updateNonRedeemableDebtLimit(0, 2_000_000 ether);
        vm.stopPrank();
    }

    function test_updateNonRedeemableDebtLimit_decreaseAndWithin2x_succeeds() public {
        TestDeployer d = _freshDeployer();
        IERC20Metadata lst = _lstToken("DL2");
        TestDeployer.AeroParams memory ap = TestDeployer.AeroParams(aeroManager, false, address(0));
        TestDeployer.LiquityContractsDev memory c = _deployExtraBranch(d, lst, ap);

        vm.prank(gov);
        CollateralRegistry(address(collateralRegistry)).createNewBranch(c.addressesRegistry, false);

        vm.startPrank(gov);
        collateralRegistry.updateNonRedeemableDebtLimit(0, 400_000 ether);
        collateralRegistry.updateNonRedeemableDebtLimit(0, 800_000 ether);
        vm.stopPrank();
        assertEq(collateralRegistry.getNonRedeemableDebtLimit(0), 800_000 ether);
    }

    function test_redeemCollateral_revertsIfMaxFeeBelowFloor() public {
        vm.expectRevert("Max fee percentage must be between 0.5% and 100%");
        collateralRegistry.redeemCollateral(1 ether, 0, REDEMPTION_FEE_FLOOR - 1);
    }

    function test_redeemCollateral_revertsIfMaxFeeAbove100Percent() public {
        vm.expectRevert("Max fee percentage must be between 0.5% and 100%");
        collateralRegistry.redeemCollateral(1 ether, 0, DECIMAL_PRECISION + 1);
    }

    function test_redeemCollateral_revertsWhenFeeExceedsMax() public {
        priceFeed.setPrice(2000e18);
        openTroveNoHints100pct(A, 50 ether, 10_000e18, 5e16);
        deal(address(boldToken), B, 1_000 ether);
        CollateralRegistryTester(address(collateralRegistry)).setBaseRate(DECIMAL_PRECISION);

        vm.startPrank(B);
        vm.expectRevert("CR: Fee exceeded provided maximum");
        collateralRegistry.redeemCollateral(100 ether, 0, REDEMPTION_FEE_FLOOR);
        vm.stopPrank();
    }

    function test_redeemCollateral_unbackedPortionZeroUsesEntireBranchDebtWeights() public {
        priceFeed.setPrice(2000e18);
        openTroveNoHints100pct(A, 100 ether, 20_000e18, 5e16);
        deal(address(boldToken), A, 50_000 ether);
        makeSPDepositAndClaim(A, 50_000 ether);

        (uint256 unbacked,, bool redeemable) = troveManager.getUnbackedPortionPriceAndRedeemability();
        assertEq(unbacked, 0);
        assertTrue(redeemable);

        deal(address(boldToken), B, 5_000 ether);
        vm.prank(B);
        collateralRegistry.redeemCollateral(1_000 ether, 0, DECIMAL_PRECISION);

        assertGt(troveManager.getEntireBranchDebt(), 0);
    }

    function test_redeemCollateral_lastFeeOpTimeAdvancesWhenMinutesPass() public {
        priceFeed.setPrice(2000e18);
        openTroveNoHints100pct(A, 100 ether, 15_000e18, 5e16);

        CollateralRegistryTester t = CollateralRegistryTester(address(collateralRegistry));
        t.setLastFeeOpTimeToNow();
        uint256 beforeOp = collateralRegistry.lastFeeOperationTime();

        vm.warp(block.timestamp + 3 * ONE_MINUTE);
        deal(address(boldToken), B, 5_000 ether);
        vm.prank(B);
        vm.expectEmit(false, false, false, true);
        emit LastFeeOpTimeUpdated(beforeOp + 3 * ONE_MINUTE);
        collateralRegistry.redeemCollateral(100 ether, 0, DECIMAL_PRECISION);

        assertEq(collateralRegistry.lastFeeOperationTime(), beforeOp + 3 * ONE_MINUTE);
    }
}
