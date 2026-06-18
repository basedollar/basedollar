// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TestContracts/DevTestSetup.sol";
import "src/MultiTroveGetter.sol";
import "src/Interfaces/ICollateralRegistry.sol";
import "src/Interfaces/IMultiTroveGetter.sol";
import "src/Interfaces/ISortedTroves.sol";
import "src/Interfaces/ITroveManager.sol";

contract MultiTroveGetterTest is DevTestSetup {
    MultiTroveGetter internal mtg;

    function setUp() public override {
        super.setUp();
        mtg = new MultiTroveGetter(collateralRegistry);
    }

    function test_getMultipleSortedTroves_returnsEmptyWhenNoTroves() public {
        IMultiTroveGetter.CombinedTroveData[] memory troves = mtg.getMultipleSortedTroves(0, 0, 5);
        assertEq(troves.length, 0);
    }

    function test_getMultipleSortedTroves_startIdxBeyondSizeReturnsEmpty() public {
        priceFeed.setPrice(2000e18);
        openTroveNoHints100pct(A, 10 ether, 1000e18, 5e16);
        uint256 sz = sortedTroves.getSize();
        IMultiTroveGetter.CombinedTroveData[] memory troves =
            mtg.getMultipleSortedTroves(0, int256(uint256(sz)), 10);
        assertEq(troves.length, 0);
    }

    function test_getMultipleSortedTroves_negativeStartIdxBeyondSizeReturnsEmpty() public {
        priceFeed.setPrice(2000e18);
        openTroveNoHints100pct(A, 10 ether, 1000e18, 5e16);
        uint256 sz = sortedTroves.getSize();
        IMultiTroveGetter.CombinedTroveData[] memory troves = mtg.getMultipleSortedTroves(0, -int256(sz + 1), 10);
        assertEq(troves.length, 0);
    }

    function test_getMultipleSortedTroves_descendFromHeadAndTruncateCount() public {
        priceFeed.setPrice(2000e18);
        openTroveHelper(A, 0, 10 ether, 1000e18, 1 * 0.01 ether);
        openTroveHelper(A, 1, 10 ether, 1000e18, 3 * 0.01 ether);
        openTroveHelper(A, 2, 10 ether, 1000e18, 5 * 0.01 ether);

        uint256 first = sortedTroves.getFirst();
        IMultiTroveGetter.CombinedTroveData[] memory head = mtg.getMultipleSortedTroves(0, 0, 1);
        assertEq(head.length, 1);
        assertEq(head[0].id, first);

        IMultiTroveGetter.CombinedTroveData[] memory many = mtg.getMultipleSortedTroves(0, 0, 100);
        assertEq(many.length, sortedTroves.getSize());

        IMultiTroveGetter.CombinedTroveData[] memory exact = mtg.getMultipleSortedTroves(0, 1, 2);
        assertEq(exact.length, 2);
    }

    function test_getMultipleSortedTroves_ascendFromTailWithNegativeStartIdx() public {
        priceFeed.setPrice(2000e18);
        openTroveHelper(A, 0, 10 ether, 1000e18, 1 * 0.01 ether);
        openTroveHelper(A, 1, 10 ether, 1000e18, 3 * 0.01 ether);
        openTroveHelper(A, 2, 10 ether, 1000e18, 5 * 0.01 ether);

        uint256 last = sortedTroves.getLast();
        IMultiTroveGetter.CombinedTroveData[] memory tail = mtg.getMultipleSortedTroves(0, -1, 1);
        assertEq(tail.length, 1);
        assertEq(tail[0].id, last);

        IMultiTroveGetter.CombinedTroveData[] memory tailTwo = mtg.getMultipleSortedTroves(0, -2, 2);
        assertEq(tailTwo.length, 2);
    }

    function test_getDebtPerInterestRateAscending_fromStartIdZeroIteratesTowardsLowerRates() public {
        priceFeed.setPrice(2000e18);
        openTroveHelper(A, 0, 10 ether, 1000e18, 1 * 0.01 ether);
        openTroveHelper(A, 1, 10 ether, 1000e18, 3 * 0.01 ether);

        (IMultiTroveGetter.DebtPerInterestRate[] memory data,) = mtg.getDebtPerInterestRateAscending(0, 0, 5);
        assertGt(data[0].debt, 0);
        assertGt(data[0].interestRate, 0);
    }

    function test_getDebtPerInterestRateAscending_explicitStartAndZeroIterations() public {
        priceFeed.setPrice(2000e18);
        openTroveHelper(A, 0, 10 ether, 1000e18, 1 * 0.01 ether);
        openTroveHelper(A, 1, 10 ether, 1000e18, 3 * 0.01 ether);

        uint256 startId = sortedTroves.getLast();
        (IMultiTroveGetter.DebtPerInterestRate[] memory data, uint256 currId) =
            mtg.getDebtPerInterestRateAscending(0, startId, 1);
        assertEq(data.length, 1);
        assertGt(data[0].debt, 0);
        assertEq(currId, sortedTroves.getPrev(startId));

        (IMultiTroveGetter.DebtPerInterestRate[] memory empty, uint256 zeroIterCurrId) =
            mtg.getDebtPerInterestRateAscending(0, startId, 0);
        assertEq(empty.length, 0);
        assertEq(zeroIterCurrId, startId);
    }

    function test_gettersRevertForInvalidCollateralIndex() public {
        MultiTroveGetter invalidGetter =
            new MultiTroveGetter(ICollateralRegistry(address(new ZeroTroveManagerRegistry())));

        vm.expectRevert("Invalid collateral index");
        invalidGetter.getMultipleSortedTroves(0, 0, 1);

        vm.expectRevert("Invalid collateral index");
        invalidGetter.getMultipleSortedNonRedeemableTroves(0, 0, 1);

        vm.expectRevert("Invalid collateral index");
        invalidGetter.getDebtPerInterestRateAscending(0, 0, 1);

        vm.expectRevert("Invalid collateral index");
        invalidGetter.getNonRedeemableDebtPerInterestRateAscending(0, 0, 1);
    }

    function test_gettersAssertWhenSortedTrovesIsZeroAddress() public {
        MultiTroveGetter invalidGetter =
            new MultiTroveGetter(ICollateralRegistry(address(new ZeroSortedTrovesRegistry())));

        vm.expectRevert(stdError.assertionError);
        invalidGetter.getMultipleSortedTroves(0, 0, 1);

        vm.expectRevert(stdError.assertionError);
        invalidGetter.getMultipleSortedNonRedeemableTroves(0, 0, 1);

        vm.expectRevert(stdError.assertionError);
        invalidGetter.getDebtPerInterestRateAscending(0, 0, 1);

        vm.expectRevert(stdError.assertionError);
        invalidGetter.getNonRedeemableDebtPerInterestRateAscending(0, 0, 1);
    }
}

contract ZeroTroveManagerRegistry {
    function getTroveManager(uint256) external pure returns (ITroveManager) {
        return ITroveManager(address(0));
    }

    function getNonRedeemableTroveManager(uint256) external pure returns (ITroveManager) {
        return ITroveManager(address(0));
    }
}

contract ZeroSortedTrovesRegistry {
    ITroveManager internal immutable manager;

    constructor() {
        manager = ITroveManager(address(new ZeroSortedTrovesTroveManager()));
    }

    function getTroveManager(uint256) external view returns (ITroveManager) {
        return manager;
    }

    function getNonRedeemableTroveManager(uint256) external view returns (ITroveManager) {
        return manager;
    }
}

contract ZeroSortedTrovesTroveManager {
    function sortedTroves() external pure returns (ISortedTroves) {
        return ISortedTroves(address(0));
    }
}
