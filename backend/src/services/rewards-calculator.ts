import type { TroveCollateralTWA, TroveDistribution } from "../types.js";

/**
 * Rewards Calculator Service
 *
 * This service is responsible for calculating AERO reward distributions
 * based on time-weighted average collateral amounts.
 */
export class RewardsCalculatorService {
  /**
   * Calculate AERO rewards per troveId based on time-weighted average collateral.
   *
   * Approach:
   * 1. Compute a weight per trove (TWA * activeTime)
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
}
