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
}
