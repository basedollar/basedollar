import type { DistributionResult, TroveCollateralTWA, TroveDistribution } from "../types.js";

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
   * Calculate AERO rewards per troveId based on time-weighted average collateral.
   *
   * Suggested approach:
   * 1. Compute a weight per trove (default: TWA * activeTime)
   * 2. Sum weights across all troves
   * 3. Allocate pro-rata: reward = totalAeroToDistribute * weight / totalWeight
   *
   * @param twaResults - Array of time-weighted average collateral for each trove
   * @param totalAeroToDistribute - Total AERO tokens available for distribution
   * @returns Array of per-trove distributions keyed by troveId
   */
  calculateRewards(
    twaResults: TroveCollateralTWA[],
    totalAeroToDistribute: bigint,
  ): TroveDistribution[] {
    // Weight per trove: (average deposit size) * (seconds active in period)
    const weights = twaResults.map((twa) => ({
      twa,
      weight: twa.timeWeightedAverage * twa.activeTime,
    }));

    const totalWeight = weights.reduce((sum, w) => sum + w.weight, 0n);

    return weights.map(({ twa, weight }) => {
      const rewardAmount = totalWeight > 0n
        ? (totalAeroToDistribute * weight) / totalWeight
        : 0n;

      return {
        ...twa,
        weight,
        rewardAmount,
      };
    });
  }

  /**
   * Build the final distribution result.
   *
   * @param distributions - Calculated user distributions
   * @param result - Partial distribution result with period and other metadata
   * @returns Complete distribution result
   */
  buildDistributionResult(
    distributions: TroveDistribution[],
    result: Omit<DistributionResult, "distributions">,
  ): DistributionResult {
    return {
      ...result,
      distributions,
    };
  }
}
