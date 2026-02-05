import { loadConfig } from "./config.js";
import { AeroEventsService } from "./services/aero-events.js";
import { CollateralTrackerService } from "./services/collateral-tracker.js";
import { RewardsCalculatorService } from "./services/rewards-calculator.js";
import { TroveQueryService } from "./services/trove-query.js";
import type { GaugeDistributionInfo, GaugeDistributionResult } from "./types.js";

/**
 * Main distribution calculation flow.
 *
 * This function orchestrates the entire AERO rewards distribution calculation:
 * 1. Gets per-gauge distribution info based on epoch data from distributed events
 * 2. For each gauge: queries troves active during the gauge's period
 * 3. Calculates time-weighted average collateral for each trove
 * 4. Distributes rewards per gauge based on claim events at epoch = latestDistributedEpoch + 1
 */
async function calculateDistribution(gaugeInfoOverride?: GaugeDistributionInfo[]): Promise<GaugeDistributionResult[]> {
  const config = loadConfig();

  // Initialize services
  const aeroEventsService = new AeroEventsService(config);
  const troveQueryService = new TroveQueryService(config);
  const collateralTrackerService = new CollateralTrackerService(config);
  const rewardsCalculatorService = new RewardsCalculatorService();

  console.log("Starting AERO rewards distribution calculation...");

  // Step 1: Get current timestamp and per-gauge distribution info
  const currentTimestamp = await aeroEventsService.getCurrentBlockTimestamp();
  console.log(`Current timestamp: ${currentTimestamp}`);

  const gaugeDistributionInfos =
    gaugeInfoOverride ?? (await aeroEventsService.getGaugeDistributionInfo(currentTimestamp));

  if (gaugeDistributionInfos.length === 0) {
    console.log("No gauge distribution info found. Exiting.");
    return [];
  }

  console.log(`Found ${gaugeDistributionInfos.length} gauge(s) with distribution info`);

  // Log gauge info
  for (const g of gaugeDistributionInfos) {
    console.log(
      `Gauge ${g.gauge}: period ${g.period.startTimestamp}-${g.period.endTimestamp}, ` +
        `epoch ${g.latestDistributedEpoch} -> claim epoch ${g.claimEpoch}, rewards ${g.totalRewards}`,
    );
  }

  // Step 2: Process each gauge separately and build per-gauge results
  const results: GaugeDistributionResult[] = [];

  for (const gaugeInfo of gaugeDistributionInfos) {
    console.log(`\nProcessing gauge ${gaugeInfo.gauge}...`);

    // Get collateral ID for this gauge's LP token
    const collateralIds = await troveQueryService.getCollateralIdsForTokens([gaugeInfo.token]);
    if (collateralIds.length === 0) {
      console.log(`  No collateral ID found for token ${gaugeInfo.token}. Skipping.`);
      continue;
    }
    console.log(`  Collateral ID: ${collateralIds[0]}`);

    // Query troves active during this gauge's period
    const troves = await troveQueryService.getTrovesActiveInPeriod(collateralIds, gaugeInfo.period);
    console.log(`  Found ${troves.length} trove(s) active during the period`);

    if (troves.length === 0) {
      console.log("  No active troves. Skipping.");
      continue;
    }

    // Calculate TWA for troves in this gauge's period
    const twaResults = await collateralTrackerService.calculateTWAForTroves(troves, gaugeInfo.period);
    console.log(`  Calculated TWA for ${twaResults.length} trove(s)`);

    // Calculate reward distributions for this gauge
    const distributions = rewardsCalculatorService.calculateRewards(twaResults, gaugeInfo.totalRewards);
    console.log(`  Generated distributions for ${distributions.length} trove(s), total rewards: ${gaugeInfo.totalRewards}`);

    // Build per-gauge result
    results.push({
      gauge: gaugeInfo.gauge,
      token: gaugeInfo.token,
      period: gaugeInfo.period,
      latestDistributedEpoch: gaugeInfo.latestDistributedEpoch,
      claimEpoch: gaugeInfo.claimEpoch,
      totalRewards: gaugeInfo.totalRewards,
      distributions,
    });
  }

  console.log("\nDistribution calculation complete!");
  console.log(`Total gauges processed: ${results.length}`);
  const totalTroves = results.reduce((sum, r) => sum + r.distributions.length, 0);
  const totalRewards = results.reduce((sum, r) => sum + r.totalRewards, 0n);
  console.log(`Total troves: ${totalTroves}`);
  console.log(`Total AERO to distribute: ${totalRewards}`);

  return results;
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
