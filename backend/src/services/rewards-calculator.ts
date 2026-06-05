import type { TroveDistribution, TrovePositionTWA } from "../types.js";

/**
 * Rewards Calculator Service
 *
 * Weight formula:
 *   (TWA collateral deposit + TWA debt) * activeTime
 *     * (1 + borrower TWA interest rate / global AERO LP TWA interest rate)
 */
export class RewardsCalculatorService {
  calculateGlobalAverageInterestRate(twaResults: TrovePositionTWA[]): bigint {
    let activeTime = 0n;
    let rateTimeWeightedSum = 0n;

    for (const twa of twaResults) {
      if (twa.activeTime === 0n) continue;
      activeTime += twa.activeTime;
      rateTimeWeightedSum += twa.timeWeightedAverageInterestRate * twa.activeTime;
    }

    return activeTime > 0n ? rateTimeWeightedSum / activeTime : 0n;
  }

  /**
   * Calculate AERO rewards per troveId.
   *
   * When the recipient cap is exceeded, the highest-weight troves are retained
   * and rewards are calculated over that capped set. Any integer-division
   * remainder is assigned to the highest rewardee in the capped set so
   * `AeroManager.distributeAero` can be called with an exact total.
   */
  calculateRewards(
    twaResults: TrovePositionTWA[],
    totalAeroToDistribute: bigint,
    globalAverageInterestRate: bigint,
    maxRecipientsPerEpoch: number,
  ): TroveDistribution[] {
    const uncappedWeights = twaResults.map((twa) => {
      const baseWeight = (
        twa.timeWeightedAverageDeposit
        + twa.timeWeightedAverageDebt
      ) * twa.activeTime;

      const interestMultiplierNumerator = globalAverageInterestRate > 0n
        ? globalAverageInterestRate + twa.timeWeightedAverageInterestRate
        : 1n;
      const interestMultiplierDenominator = globalAverageInterestRate > 0n
        ? globalAverageInterestRate
        : 1n;

      // The denominator is common to all troves, so omitting it preserves the
      // exact pro-rata ordering while avoiding avoidable integer truncation.
      const weight = globalAverageInterestRate > 0n
        ? baseWeight * interestMultiplierNumerator
        : baseWeight;

      return {
        twa,
        baseWeight,
        interestMultiplierNumerator,
        interestMultiplierDenominator,
        weight,
      };
    }).filter((w) => w.weight > 0n);

    const cappedWeights = uncappedWeights
      .sort((a, b) => {
        if (a.weight > b.weight) return -1;
        if (a.weight < b.weight) return 1;
        return a.twa.troveId.localeCompare(b.twa.troveId);
      })
      .slice(0, Math.max(maxRecipientsPerEpoch, 0));

    const totalWeight = cappedWeights.reduce((sum, w) => sum + w.weight, 0n);
    if (totalWeight === 0n) {
      return [];
    }

    const distributions = cappedWeights.map((w) => {
      const rewardAmount = (totalAeroToDistribute * w.weight) / totalWeight;
      return {
        ...w.twa,
        baseWeight: w.baseWeight,
        interestMultiplierNumerator: w.interestMultiplierNumerator,
        interestMultiplierDenominator: w.interestMultiplierDenominator,
        weight: w.weight,
        rewardAmount,
      };
    });

    const distributed = distributions.reduce((sum, d) => sum + d.rewardAmount, 0n);
    const remainder = totalAeroToDistribute - distributed;
    if (remainder > 0n && distributions.length > 0) {
      const highestRewardee = distributions.reduce((highest, current) => {
        if (current.rewardAmount > highest.rewardAmount) return current;
        if (current.rewardAmount < highest.rewardAmount) return highest;
        return current.weight > highest.weight ? current : highest;
      });
      highestRewardee.rewardAmount += remainder;
    }

    return distributions.filter((distribution) => distribution.rewardAmount > 0n);
  }
}
