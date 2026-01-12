import { loadConfig } from "./config.js";
import { AeroEventsService } from "./services/aero-events.js";
import { CollateralTrackerService } from "./services/collateral-tracker.js";
import { RewardsCalculatorService } from "./services/rewards-calculator.js";
import { TroveQueryService } from "./services/trove-query.js";
import type { DistributionPeriod, DistributionResult } from "./types.js";

/**
 * Main distribution calculation flow.
 *
 * This function orchestrates the entire AERO rewards distribution calculation:
 * 1. Fetches Aero LP collateral tokens from Staked events
 * 2. Queries troves that were active during the distribution period
 * 3. Calculates time-weighted average collateral for each trove
 * 4. Calculates reward distribution (placeholder - to be implemented)
 */
async function calculateDistribution(periodOverride?: DistributionPeriod): Promise<DistributionResult> {
  const config = loadConfig();

  // Initialize services
  const aeroEventsService = new AeroEventsService(config);
  const troveQueryService = new TroveQueryService(config);
  const collateralTrackerService = new CollateralTrackerService(config);
  const rewardsCalculatorService = new RewardsCalculatorService();

  console.log("Starting AERO rewards distribution calculation...");

  // Step 1: Get the distribution period
  const currentTimestamp = await aeroEventsService.getCurrentBlockTimestamp();
  const period: DistributionPeriod = periodOverride ?? {
    startTimestamp: currentTimestamp - config.distributionPeriodSeconds,
    endTimestamp: currentTimestamp,
  };

  console.log(`Distribution period: ${period.startTimestamp} - ${period.endTimestamp}`);

  // Step 2: Get Aero LP collaterals from Staked events
  console.log("Fetching Aero LP collaterals from Staked events...");
  const lpCollaterals = await aeroEventsService.getAeroLPCollaterals();
  console.log(`Found ${lpCollaterals.length} Aero LP collateral(s)`);

  if (lpCollaterals.length === 0) {
    console.log("No Aero LP collaterals found. Exiting.");
    return {
      period,
      lpCollaterals: [],
      totalClaimedAero: 0n,
      distributions: [],
    };
  }

  // Step 3: Get collateral IDs for the LP tokens
  console.log("Mapping LP tokens to collateral IDs...");
  const tokenAddresses = lpCollaterals.map((lp) => lp.token);
  const collateralIds = await troveQueryService.getCollateralIdsForTokens(tokenAddresses);
  console.log(`Mapped to ${collateralIds.length} collateral ID(s): ${collateralIds.join(", ")}`);

  if (collateralIds.length === 0) {
    console.log("No matching collateral IDs found. Exiting.");
    return {
      period,
      lpCollaterals,
      totalClaimedAero: 0n,
      distributions: [],
    };
  }

  // Step 4: Query troves active during the period
  console.log("Querying troves active during the distribution period...");
  const troves = await troveQueryService.getTrovesActiveInPeriod(collateralIds, period);
  console.log(`Found ${troves.length} trove(s) active during the period`);

  if (troves.length === 0) {
    console.log("No active troves found. Exiting.");
    return {
      period,
      lpCollaterals,
      totalClaimedAero: 0n,
      distributions: [],
    };
  }

  // Step 5: Calculate time-weighted average collateral for each trove
  console.log("Calculating time-weighted average collateral...");
  const twaResults = await collateralTrackerService.calculateTWAForTroves(troves, period);
  console.log(`Calculated TWA for ${twaResults.length} trove(s)`);

  // Step 6: Get total claimed AERO for the period
  console.log("Fetching total claimed AERO for the period...");
  const totalClaimedAero = await aeroEventsService.getTotalClaimedInPeriod(period);
  console.log(`Total claimed AERO (excluding fees): ${totalClaimedAero}`);

  // Step 7: Calculate reward distributions
  console.log("Calculating reward distributions...");
  const distributions = rewardsCalculatorService.calculateRewards(twaResults, totalClaimedAero);
  console.log(`Generated distributions for ${distributions.length} trove(s)`);

  // Build final result
  const result = rewardsCalculatorService.buildDistributionResult(distributions, {
    period,
    lpCollaterals,
    totalClaimedAero,
  });

  console.log("\nDistribution calculation complete!");
  console.log(`Total troves: ${result.distributions.length}`);
  console.log(`Total AERO to distribute: ${result.totalClaimedAero}`);

  return result;
}

/**
 * Entry point
 */
async function main() {
  try {
    const result = await calculateDistribution();

    // Output result as JSON
    console.log("\n=== Distribution Result ===");
    console.log(
      JSON.stringify(
        result,
        (_, value) => (typeof value === "bigint" ? value.toString() : value),
        2,
      ),
    );
  } catch (error) {
    console.error("Error calculating distribution:", error);
    process.exit(1);
  }
}

// Run if this is the main module
main();

export { calculateDistribution };
