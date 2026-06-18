// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TestContracts/DevTestSetup.sol";
import "./TestContracts/Deployment.t.sol";
import {ERC20Faucet} from "./TestContracts/ERC20Faucet.sol";
import "src/CollateralRegistry.sol";
import "src/HintHelpers.sol";
import "src/MultiTroveGetter.sol";
import "src/Interfaces/IMultiTroveGetter.sol";
import "src/Interfaces/ISortedTroves.sol";
import "src/Interfaces/ITroveManager.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {INTEREST_RATE_ADJ_COOLDOWN, MIN_INTEREST_RATE_CHANGE_PERIOD} from "src/Dependencies/Constants.sol";
import {IBorrowerOperations} from "src/Interfaces/IBorrowerOperations.sol";

/// @dev Covers `HintHelpers` non-redeemable helpers and `MultiTroveGetter` non-redeemable queries (requires an NR branch).
contract HintHelpersNonRedeemableMultiTroveTest is DevTestSetup {
    address internal gov = makeAddr("GOVERNOR");
    MultiTroveGetter internal mtg;
    TestDeployer.LiquityContractsDev internal nr;

    function setUp() public override {
        super.setUp();
        mtg = new MultiTroveGetter(collateralRegistry);
        _deployNonRedeemableBranch();
    }

    function _freshDeployer() internal returns (TestDeployer) {
        return new TestDeployer();
    }

    function _deployNonRedeemableBranch() internal {
        TestDeployer d = _freshDeployer();
        IERC20Metadata lst = new ERC20Faucet("LST Tester", "NRH", 100 ether, 1 days);
        TestDeployer.TroveManagerParams memory p = TestDeployer.TroveManagerParams({
            CCR: 160e16,
            MCR: 120e16,
            BCR: 10e16,
            SCR: 120e16,
            debtLimit: 1_000_000 ether,
            LIQUIDATION_PENALTY_SP: 5e16,
            LIQUIDATION_PENALTY_REDISTRIBUTION: 10e16,
            isAeroLPCollateral: false,
            aeroGaugeAddress: address(0)
        });
        TestDeployer.AeroParams memory ap = TestDeployer.AeroParams(aeroManager, false, address(0));
        (nr,) = d.deployAdditionalBranchDev(p, lst, boldToken, collateralRegistry, WETH, hintHelpers, mtg, ap);
        vm.prank(gov);
        CollateralRegistry(address(collateralRegistry)).createNewBranch(nr.addressesRegistry, false);
    }

    function _fundNr(address account) internal {
        deal(address(nr.collToken), account, 50_000 ether);
        vm.startPrank(account);
        nr.collToken.approve(address(nr.borrowerOperations), type(uint256).max);
        WETH.approve(address(nr.borrowerOperations), type(uint256).max);
        vm.stopPrank();
    }

    function test_getApproxHintNonRedeemable_returnsZeroWhenNoNrTroves() public {
        (uint256 hintId, uint256 diff, uint256 seedOut) = hintHelpers.getApproxHintNonRedeemable(0, 5e16, 3, 42);
        assertEq(hintId, 0);
        assertEq(diff, 0);
        assertEq(seedOut, 42);
    }

    function test_getApproxHintNonRedeemable_returnsClosestHint() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        _fundNr(B);

        openNrTrove(A, 0, 20 ether, 2000e18, 4e16);
        openNrTrove(B, 0, 20 ether, 2000e18, 8e16);

        (uint256 hintId,,) = hintHelpers.getApproxHintNonRedeemable(0, 6e16, 15, 999);
        assertTrue(nr.sortedTroves.contains(hintId));
    }

    function test_getApproxHintNonRedeemable_skipsZombieAndUpdatesToCloserHint() public {
        HintHelpers mockHintHelpers =
            new HintHelpers(ICollateralRegistry(address(new NonRedeemableApproxHintRegistry())));

        (uint256 hintId, uint256 diff,) = mockHintHelpers.getApproxHintNonRedeemable(0, 5e16, 50, 1);
        assertEq(hintId, 2);
        assertEq(diff, 0);
    }

    function test_predictOpenTroveUpfrontFeeNonRedeemable_matchesOpenPath() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        uint256 borrow = 1500e18;
        uint256 ir = 5e16;
        uint256 fee = hintHelpers.predictOpenTroveUpfrontFeeNonRedeemable(0, borrow, ir);
        vm.startPrank(A);
        uint256 tid = nr.borrowerOperations.openTrove(A, 0, 25 ether, borrow, 0, 0, ir, fee, address(0), address(0), address(0));
        vm.stopPrank();
        assertGt(tid, 0);
    }

    function test_predictAdjustTroveUpfrontFeeNonRedeemable_zeroDebtIncrease() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        uint256 tid = openNrTrove(A, 0, 25 ether, 1500e18, 5e16);
        assertEq(hintHelpers.predictAdjustTroveUpfrontFeeNonRedeemable(0, tid, 0), 0);
    }

    function test_predictAdjustTroveUpfrontFeeNonRedeemable_withBatchDebtIncrease() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        _registerNrBatch(D);
        uint256 tid = openNrTroveInBatch(A, 0, 40 ether, 2000e18, 5e16, D);
        uint256 fee = hintHelpers.predictAdjustTroveUpfrontFeeNonRedeemable(0, tid, 500e18);
        assertGt(fee, 0);
    }

    function test_predictAdjustTroveUpfrontFeeNonRedeemable_withIndividualDebtIncrease() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        uint256 tid = openNrTrove(A, 0, 25 ether, 1500e18, 5e16);

        uint256 fee = hintHelpers.predictAdjustTroveUpfrontFeeNonRedeemable(0, tid, 500e18);
        assertGt(fee, 0);
    }

    function test_predictAdjustInterestRateNonRedeemable_vsForce() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        uint256 tid = openNrTrove(A, 0, 25 ether, 1500e18, 5e16);

        assertEq(hintHelpers.predictAdjustInterestRateUpfrontFeeNonRedeemable(0, tid, 5e16), 0);

        uint256 inCooldown = hintHelpers.predictAdjustInterestRateUpfrontFeeNonRedeemable(0, tid, 6e16);
        assertGt(inCooldown, 0);

        vm.warp(block.timestamp + INTEREST_RATE_ADJ_COOLDOWN + 1);
        assertEq(hintHelpers.predictAdjustInterestRateUpfrontFeeNonRedeemable(0, tid, 7e16), 0);

        uint256 forced = hintHelpers.forcePredictAdjustInterestRateUpfrontFeeNonRedeemable(0, tid, 7e16);
        assertGe(forced, 0);
    }

    function test_predictOpenTroveAndJoinBatchUpfrontFeeNonRedeemable() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        _registerNrBatch(D);
        uint256 fee = hintHelpers.predictOpenTroveAndJoinBatchUpfrontFeeNonRedeemable(0, 2000e18, D);
        assertGt(fee, 0);
    }

    function test_predictAdjustBatchInterestRateUpfrontFeeNonRedeemable_withinBatchCooldown() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        _fundNr(B);
        _registerNrBatch(D);
        openNrTroveInBatch(A, 0, 40 ether, 2000e18, 5e16, D);
        openNrTroveInBatch(B, 0, 40 ether, 2000e18, 5e16, D);

        uint256 fee = hintHelpers.predictAdjustBatchInterestRateUpfrontFeeNonRedeemable(0, D, 6e16);
        assertGt(fee, 0);
    }

    function test_predictAdjustBatchInterestRateUpfrontFeeNonRedeemable_zeroWhenRateUnchangedOrAfterCooldown() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        _registerNrBatch(D);
        openNrTroveInBatch(A, 0, 40 ether, 2000e18, 5e16, D);

        assertEq(hintHelpers.predictAdjustBatchInterestRateUpfrontFeeNonRedeemable(0, D, 5e16), 0);

        vm.warp(block.timestamp + INTEREST_RATE_ADJ_COOLDOWN + 1);
        assertEq(hintHelpers.predictAdjustBatchInterestRateUpfrontFeeNonRedeemable(0, D, 6e16), 0);
    }

    function test_predictJoinBatchInterestRateUpfrontFeeNonRedeemable() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        _registerNrBatch(D);
        uint256 tid = openNrTrove(A, 0, 25 ether, 1500e18, 5e16);
        uint256 fee = hintHelpers.predictJoinBatchInterestRateUpfrontFeeNonRedeemable(0, tid, D);
        assertGt(fee, 0);
        vm.startPrank(A);
        nr.borrowerOperations.setInterestBatchManager(tid, D, 0, 0, type(uint256).max);
        vm.stopPrank();
    }

    function test_predictRemoveFromBatchUpfrontFeeNonRedeemable_whenLeavingBatchRateChanges() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        uint256 tid = openNrTroveInBatch(A, 0, 40 ether, 2000e18, 5e16, D);
        uint256 fee = hintHelpers.predictRemoveFromBatchUpfrontFeeNonRedeemable(0, tid, 6e16);
        assertGt(fee, 0);
    }

    function test_predictRemoveFromBatchUpfrontFeeNonRedeemable_zeroWhenRateUnchangedOrAfterCooldown() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        uint256 tid = openNrTroveInBatch(A, 0, 40 ether, 2000e18, 5e16, D);

        assertEq(hintHelpers.predictRemoveFromBatchUpfrontFeeNonRedeemable(0, tid, 5e16), 0);

        vm.warp(block.timestamp + INTEREST_RATE_ADJ_COOLDOWN + 1);
        assertEq(hintHelpers.predictRemoveFromBatchUpfrontFeeNonRedeemable(0, tid, 6e16), 0);
    }

    function test_getMultipleSortedNonRedeemableTroves_andDebtAscending() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        _fundNr(B);
        openNrTrove(A, 0, 25 ether, 1200e18, 4e16);
        openNrTrove(B, 0, 25 ether, 1200e18, 7e16);

        IMultiTroveGetter.CombinedTroveData[] memory t = mtg.getMultipleSortedNonRedeemableTroves(0, 0, 2);
        assertEq(t.length, 2);

        (IMultiTroveGetter.DebtPerInterestRate[] memory data,) =
            mtg.getNonRedeemableDebtPerInterestRateAscending(0, 0, 3);
        assertGt(data[0].debt, 0);
    }

    function test_getMultipleSortedNonRedeemableTroves_tailAndBounds() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        _fundNr(B);
        openNrTrove(A, 0, 25 ether, 1200e18, 4e16);
        openNrTrove(B, 0, 25 ether, 1200e18, 7e16);

        IMultiTroveGetter.CombinedTroveData[] memory outOfBounds = mtg.getMultipleSortedNonRedeemableTroves(0, -3, 2);
        assertEq(outOfBounds.length, 0);

        IMultiTroveGetter.CombinedTroveData[] memory truncated = mtg.getMultipleSortedNonRedeemableTroves(0, 0, 100);
        assertEq(truncated.length, nr.sortedTroves.getSize());

        IMultiTroveGetter.CombinedTroveData[] memory tail = mtg.getMultipleSortedNonRedeemableTroves(0, -1, 1);
        assertEq(tail.length, 1);
        assertEq(tail[0].id, nr.sortedTroves.getLast());

        IMultiTroveGetter.CombinedTroveData[] memory exactCount = mtg.getMultipleSortedNonRedeemableTroves(0, 1, 1);
        assertEq(exactCount.length, 1);
    }

    function test_getNonRedeemableDebtPerInterestRateAscending_explicitStartAndZeroIterations() public {
        nr.priceFeed.setPrice(2000e18);
        _fundNr(A);
        _fundNr(B);
        openNrTrove(A, 0, 25 ether, 1200e18, 4e16);
        openNrTrove(B, 0, 25 ether, 1200e18, 7e16);

        uint256 startId = nr.sortedTroves.getLast();
        (IMultiTroveGetter.DebtPerInterestRate[] memory data, uint256 currId) =
            mtg.getNonRedeemableDebtPerInterestRateAscending(0, startId, 1);
        assertEq(data.length, 1);
        assertGt(data[0].debt, 0);
        assertEq(currId, nr.sortedTroves.getPrev(startId));

        (IMultiTroveGetter.DebtPerInterestRate[] memory empty, uint256 zeroIterCurrId) =
            mtg.getNonRedeemableDebtPerInterestRateAscending(0, startId, 0);
        assertEq(empty.length, 0);
        assertEq(zeroIterCurrId, startId);
    }

    // --- internal NR open helpers ---

    function openNrTrove(address account, uint256 index, uint256 coll, uint256 borrow, uint256 annualIR)
        internal
        returns (uint256 troveId)
    {
        uint256 upfront = hintHelpers.predictOpenTroveUpfrontFeeNonRedeemable(0, borrow, annualIR);
        vm.startPrank(account);
        troveId = nr.borrowerOperations.openTrove(account, index, coll, borrow, 0, 0, annualIR, upfront, address(0), address(0), address(0));
        vm.stopPrank();
    }

    function _registerNrBatch(address batch) internal {
        vm.startPrank(batch);
        nr.borrowerOperations.registerBatchManager(
            uint128(1e16), uint128(20e16), uint128(5e16), uint128(25e14), MIN_INTEREST_RATE_CHANGE_PERIOD
        );
        vm.stopPrank();
    }

    function openNrTroveInBatch(
        address account,
        uint256 index,
        uint256 coll,
        uint256 borrow,
        uint256 /* annualIR */,
        address batch
    ) internal returns (uint256 troveId) {
        if (!nr.borrowerOperations.checkBatchManagerExists(batch)) {
            _registerNrBatch(batch);
        }
        IBorrowerOperations.OpenTroveAndJoinInterestBatchManagerParams memory params = IBorrowerOperations
            .OpenTroveAndJoinInterestBatchManagerParams({
            owner: account,
            ownerIndex: index,
            collAmount: coll,
            boldAmount: borrow,
            upperHint: 0,
            lowerHint: 0,
            interestBatchManager: batch,
            maxUpfrontFee: 1e24,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(account);
        troveId = nr.borrowerOperations.openTroveAndJoinInterestBatchManager(params);
        vm.stopPrank();
    }
}

contract NonRedeemableApproxHintRegistry {
    ITroveManager internal immutable manager;

    constructor() {
        manager = ITroveManager(address(new NonRedeemableApproxHintTroveManager()));
    }

    function getNonRedeemableTroveManager(uint256) external view returns (ITroveManager) {
        return manager;
    }
}

contract NonRedeemableApproxHintTroveManager {
    ISortedTroves internal immutable sorted;

    constructor() {
        sorted = ISortedTroves(address(new NonRedeemableApproxHintSortedTroves()));
    }

    function sortedTroves() external view returns (ISortedTroves) {
        return sorted;
    }

    function getTroveIdsCount() external pure returns (uint256) {
        return 3;
    }

    function getTroveFromTroveIdsArray(uint256 index) external pure returns (uint256) {
        return index == 1 ? 3 : 2;
    }

    function getTroveAnnualInterestRate(uint256 id) external pure returns (uint256) {
        if (id == 1) return 10e16;
        if (id == 2) return 5e16;
        return 20e16;
    }
}

contract NonRedeemableApproxHintSortedTroves {
    function getLast() external pure returns (uint256) {
        return 1;
    }

    function contains(uint256 id) external pure returns (bool) {
        return id == 1 || id == 2;
    }
}
