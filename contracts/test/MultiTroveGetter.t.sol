// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TestContracts/DevTestSetup.sol";
import "src/MultiTroveGetter.sol";
import "src/Interfaces/IMultiTroveGetter.sol";

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
}
