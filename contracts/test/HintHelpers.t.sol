// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TestContracts/DevTestSetup.sol";
import {INTEREST_RATE_ADJ_COOLDOWN} from "src/Dependencies/Constants.sol";

contract HintHelpersTest is DevTestSetup {
    function test_GetApproxHintNeverReturnsZombies(uint256 seed) external {
        for (uint256 i = 1; i <= 10; ++i) {
            openTroveHelper(A, i, 100 ether, 10_000 ether, i * 0.01 ether);
        }

        uint256 redeemedTroveId = sortedTroves.getLast();
        uint256 redeemable = troveManager.getTroveEntireDebt(redeemedTroveId);

        redeem(A, redeemable);

        assertEq(
            uint8(troveManager.getTroveStatus(redeemedTroveId)),
            uint8(ITroveManager.Status.zombie),
            "Redeemed Trove should have become a zombie"
        );

        // Choose an interest rate very close to the redeemed Trove's
        uint256 interestRate = troveManager.getTroveAnnualInterestRate(redeemedTroveId) + 1;

        (uint256 hintId,,) = hintHelpers.getApproxHint(0, interestRate, 10, seed);
        assertNotEq(hintId, redeemedTroveId, "Zombies should not be hints");
    }

    function test_getApproxHint_returnsZeroWhenNoTroves() public {
        (uint256 hintId, uint256 diff, uint256 outSeed) = hintHelpers.getApproxHint(0, 5e16, 5, 123);
        assertEq(hintId, 0);
        assertEq(diff, 0);
        assertEq(outSeed, 123);
    }

    function test_getApproxHint_canUpdateToCloserTrove() public {
        priceFeed.setPrice(2000e18);
        openTroveHelper(A, 0, 10 ether, 1000e18, 1e16);
        openTroveHelper(A, 1, 10 ether, 1000e18, 5e16);
        openTroveHelper(A, 2, 10 ether, 1000e18, 10e16);

        (uint256 hintId, uint256 diff,) = hintHelpers.getApproxHint(0, 5e16, 100, 1);
        assertEq(troveManager.getTroveAnnualInterestRate(hintId), 5e16);
        assertEq(diff, 0);
    }

    function test_forcePredictAdjustInterestRateUpfrontFee_canBeNonZeroWhenPredictReturnsZeroAfterCooldown() public {
        priceFeed.setPrice(2000e18);
        uint256 troveId = openTroveNoHints100pct(A, 10 ether, 2000e18, 5e16);

        vm.warp(block.timestamp + INTEREST_RATE_ADJ_COOLDOWN + 1);

        uint256 predicted = hintHelpers.predictAdjustInterestRateUpfrontFee(0, troveId, 6e16);
        assertEq(predicted, 0);

        uint256 forced = hintHelpers.forcePredictAdjustInterestRateUpfrontFee(0, troveId, 6e16);
        assertGe(forced, 0);
    }

    function test_predictAdjustInterestRateUpfrontFee_nonZeroWhileStillInCooldownForRateChange() public {
        priceFeed.setPrice(2000e18);
        uint256 troveId = openTroveNoHints100pct(A, 10 ether, 2000e18, 5e16);

        uint256 predicted = hintHelpers.predictAdjustInterestRateUpfrontFee(0, troveId, 6e16);
        assertGt(predicted, 0);
    }

    function test_predictAdjustInterestRateUpfrontFee_zeroWhenRateUnchanged() public {
        priceFeed.setPrice(2000e18);
        uint256 troveId = openTroveNoHints100pct(A, 10 ether, 2000e18, 5e16);

        assertEq(hintHelpers.predictAdjustInterestRateUpfrontFee(0, troveId, 5e16), 0);
    }

    function test_predictAdjustTroveUpfrontFee_zeroDebtIncrease() public {
        priceFeed.setPrice(2000e18);
        uint256 troveId = openTroveNoHints100pct(A, 10 ether, 2000e18, 5e16);

        assertEq(hintHelpers.predictAdjustTroveUpfrontFee(0, troveId, 0), 0);
    }

    function test_predictAdjustTroveUpfrontFee_withBatchDebtIncrease() public {
        priceFeed.setPrice(2000e18);
        uint256 troveId = openTroveAndJoinBatchManager(A, 10 ether, 2000e18, B, 5e16);

        assertGt(hintHelpers.predictAdjustTroveUpfrontFee(0, troveId, 500e18), 0);
    }

    function test_predictAdjustBatchInterestRateUpfrontFee_zeroWhenRateUnchangedOrAfterCooldown() public {
        priceFeed.setPrice(2000e18);
        openTroveAndJoinBatchManager(A, 10 ether, 2000e18, B, 5e16);

        assertEq(hintHelpers.predictAdjustBatchInterestRateUpfrontFee(0, B, 5e16), 0);

        vm.warp(block.timestamp + INTEREST_RATE_ADJ_COOLDOWN + 1);
        assertEq(hintHelpers.predictAdjustBatchInterestRateUpfrontFee(0, B, 6e16), 0);
    }

    function test_predictOpenTroveAndJoinBatchUpfrontFee() public {
        priceFeed.setPrice(2000e18);
        registerBatchManager(B);

        assertGt(hintHelpers.predictOpenTroveAndJoinBatchUpfrontFee(0, 2000e18, B), 0);
    }

    function test_predictJoinBatchInterestRateUpfrontFee() public {
        priceFeed.setPrice(2000e18);
        registerBatchManager(B);
        uint256 troveId = openTroveNoHints100pct(A, 10 ether, 2000e18, 5e16);

        assertGt(hintHelpers.predictJoinBatchInterestRateUpfrontFee(0, troveId, B), 0);
    }

    function test_predictRemoveFromBatchUpfrontFee_zeroWhenRateUnchangedOrAfterCooldown() public {
        priceFeed.setPrice(2000e18);
        uint256 troveId = openTroveAndJoinBatchManager(A, 10 ether, 2000e18, B, 5e16);

        assertEq(hintHelpers.predictRemoveFromBatchUpfrontFee(0, troveId, 5e16), 0);

        vm.warp(block.timestamp + INTEREST_RATE_ADJ_COOLDOWN + 1);
        assertEq(hintHelpers.predictRemoveFromBatchUpfrontFee(0, troveId, 6e16), 0);
    }
}
