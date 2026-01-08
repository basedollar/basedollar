import type { Address } from "viem";
import type { DistributionResult, TroveCollateralTWA, UserDistribution } from "../types.js";

/**
 * Rewards Calculator Service
 *
 * This service is responsible for calculating AERO reward distributions
 * based on time-weighted average collateral amounts.
 *
 * TODO: Implement the reward calculation logic based on your specific requirements.
 * The placeholder function below provides the structure - fill in the math.
 */
export class RewardsCalculatorService {
  /**
   * Calculate AERO rewards for each user based on their time-weighted average collateral.
   *
   * TODO: Implement your reward distribution formula here.
   *
   * Suggested approach:
   * 1. Calculate total TWA across all users
   * 2. For each user, calculate their share: (user TWA / total TWA)
   * 3. Multiply share by total AERO to distribute
   *
   * You may also want to consider:
   * - Different reward rates per collateral type
   * - Minimum thresholds
   * - Cap/floor on rewards per user
   * - Time-based multipliers
   *
   * @param twaResults - Array of time-weighted average collateral for each trove
   * @param totalAeroToDistribute - Total AERO tokens available for distribution
   * @returns Array of user distributions with calculated reward amounts
   */
  calculateRewards(
    twaResults: TroveCollateralTWA[],
    totalAeroToDistribute: bigint,
  ): UserDistribution[] {
    // Group troves by borrower
    const userTroves = new Map<Address, TroveCollateralTWA[]>();
    for (const twa of twaResults) {
      const existing = userTroves.get(twa.borrower) ?? [];
      existing.push(twa);
      userTroves.set(twa.borrower, existing);
    }

    // Calculate total TWA across all troves
    const totalTWA = twaResults.reduce(
      (sum, twa) => sum + twa.timeWeightedAverage,
      0n,
    );

    // Build user distributions
    const distributions: UserDistribution[] = [];
    for (const [borrower, troves] of userTroves) {
      const userTotalTWA = troves.reduce(
        (sum, twa) => sum + twa.timeWeightedAverage,
        0n,
      );

      distributions.push({
        borrower,
        troves,
        totalTimeWeightedCollateral: userTotalTWA,
        // TODO: Implement your reward calculation formula here
        // Example pro-rata distribution:
        // rewardAmount: totalTWA > 0n ? (userTotalTWA * totalAeroToDistribute) / totalTWA : 0n,
        rewardAmount: undefined, // Set to undefined until formula is implemented
      });
    }

    return distributions;
  }

  /**
   * Build the final distribution result.
   *
   * @param distributions - Calculated user distributions
   * @param result - Partial distribution result with period and other metadata
   * @returns Complete distribution result
   */
  buildDistributionResult(
    distributions: UserDistribution[],
    result: Omit<DistributionResult, "distributions">,
  ): DistributionResult {
    return {
      ...result,
      distributions,
    };
  }
}
