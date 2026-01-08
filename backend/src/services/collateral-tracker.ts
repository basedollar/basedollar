import { createPublicClient, http, parseAbiItem, type Address } from "viem";
import { base } from "viem/chains";
import type { Config } from "../config.js";
import type { CollateralSnapshot, DistributionPeriod, Trove, TroveCollateralTWA } from "../types.js";

// TroveUpdated event from TroveManager
const TROVE_UPDATED_EVENT = parseAbiItem(
  "event TroveUpdated(uint256 indexed _troveId, uint256 _debt, uint256 _coll, uint256 _stake, uint256 _annualInterestRate, uint256 _snapshotOfTotalCollRedist, uint256 _snapshotOfTotalDebtRedist)",
);

export class CollateralTrackerService {
  private client;
  private config: Config;

  constructor(config: Config) {
    this.config = config;
    this.client = createPublicClient({
      chain: base,
      transport: http(config.rpcUrl),
    });
  }

  /**
   * Get collateral snapshots (TroveUpdated events) for a trove within a period.
   * These events track changes to the trove's collateral amount.
   *
   * @param troveManagerAddress - The TroveManager contract address for this collateral
   * @param troveId - The trove ID (numeric, from the trove's full ID)
   * @param fromBlock - Start block for event query
   * @param toBlock - End block for event query
   */
  async getCollateralSnapshots(
    troveManagerAddress: Address,
    troveId: bigint,
    fromBlock: bigint,
    toBlock: bigint | "latest",
  ): Promise<CollateralSnapshot[]> {
    const logs = await this.client.getLogs({
      address: troveManagerAddress,
      event: TROVE_UPDATED_EVENT,
      args: {
        _troveId: troveId,
      },
      fromBlock,
      toBlock,
    });

    // Get block timestamps for each event
    const snapshots: CollateralSnapshot[] = [];
    for (const log of logs) {
      const block = await this.client.getBlock({ blockNumber: log.blockNumber });
      snapshots.push({
        troveId: troveId.toString(),
        deposit: log.args._coll as bigint,
        timestamp: block.timestamp,
      });
    }

    return snapshots.sort((a, b) => (a.timestamp < b.timestamp ? -1 : 1));
  }

  /**
   * Calculate time-weighted average collateral for a single trove over the period.
   *
   * TWA = Sum of (collateral_amount × time_held) / total_period_time
   *
   * @param trove - The trove to calculate TWA for
   * @param snapshots - Collateral snapshots within the period
   * @param period - The distribution period
   */
  calculateTWA(
    trove: Trove,
    snapshots: CollateralSnapshot[],
    period: DistributionPeriod,
  ): TroveCollateralTWA {
    const periodDuration = period.endTimestamp - period.startTimestamp;

    // Determine the effective start and end times for this trove in the period
    const troveStart = trove.createdAt > period.startTimestamp ? trove.createdAt : period.startTimestamp;
    const troveEnd = trove.closedAt && trove.closedAt < period.endTimestamp
      ? trove.closedAt
      : period.endTimestamp;

    // If trove wasn't active during the period, return zero
    if (troveStart >= troveEnd) {
      return {
        troveId: trove.id,
        borrower: trove.borrower,
        collateralId: trove.collateral.id,
        timeWeightedAverage: 0n,
        activeTime: 0n,
      };
    }

    const activeTime = troveEnd - troveStart;

    // Filter snapshots to only those within the period
    const relevantSnapshots = snapshots.filter(
      (s) => s.timestamp >= period.startTimestamp && s.timestamp < period.endTimestamp,
    );

    // If no snapshots in period, use the trove's current deposit value for the entire active time
    if (relevantSnapshots.length === 0) {
      // The deposit at period start would be the trove's deposit before any changes in the period
      // We use the current deposit as an approximation (or the last known value)
      const timeWeightedSum = trove.deposit * activeTime;
      const timeWeightedAverage = timeWeightedSum / periodDuration;

      return {
        troveId: trove.id,
        borrower: trove.borrower,
        collateralId: trove.collateral.id,
        timeWeightedAverage,
        activeTime,
      };
    }

    // Calculate time-weighted sum
    let timeWeightedSum = 0n;
    let currentDeposit = trove.deposit; // Start with current deposit as initial value
    let lastTimestamp = troveStart;

    // If the first snapshot is after trove start, account for time before first snapshot
    if (relevantSnapshots[0].timestamp > troveStart) {
      // We need the deposit value at period start - use the snapshot's deposit as the "before" value
      // This is an approximation; ideally we'd query the deposit at period start
      const timeBeforeFirstSnapshot = relevantSnapshots[0].timestamp - troveStart;
      // The deposit before the first snapshot would need to be fetched; for now use first snapshot value
      timeWeightedSum += relevantSnapshots[0].deposit * timeBeforeFirstSnapshot;
      lastTimestamp = relevantSnapshots[0].timestamp;
    }

    // Process each snapshot
    for (let i = 0; i < relevantSnapshots.length; i++) {
      const snapshot = relevantSnapshots[i];
      const nextTimestamp = i < relevantSnapshots.length - 1
        ? relevantSnapshots[i + 1].timestamp
        : troveEnd;

      const duration = nextTimestamp - snapshot.timestamp;
      timeWeightedSum += snapshot.deposit * duration;
    }

    const timeWeightedAverage = timeWeightedSum / periodDuration;

    return {
      troveId: trove.id,
      borrower: trove.borrower,
      collateralId: trove.collateral.id,
      timeWeightedAverage,
      activeTime,
    };
  }

  /**
   * Calculate TWA for multiple troves.
   * This is a simplified version that uses the trove's current deposit value.
   * For more accurate results, you would need to fetch TroveUpdated events for each trove.
   *
   * @param troves - Array of troves to calculate TWA for
   * @param period - The distribution period
   */
  calculateTWAForTroves(
    troves: Trove[],
    period: DistributionPeriod,
  ): TroveCollateralTWA[] {
    // Simplified calculation using current deposit values
    // For production, you should fetch snapshots for each trove
    return troves.map((trove) => this.calculateTWA(trove, [], period));
  }

  /**
   * Get block number for a given timestamp (approximate).
   * Uses binary search to find the closest block.
   */
  async getBlockNumberForTimestamp(targetTimestamp: bigint): Promise<bigint> {
    const latestBlock = await this.client.getBlock({ blockTag: "latest" });

    // Binary search for the block
    let low = this.config.startBlock;
    let high = latestBlock.number;

    while (low < high) {
      const mid = (low + high) / 2n;
      const block = await this.client.getBlock({ blockNumber: mid });

      if (block.timestamp < targetTimestamp) {
        low = mid + 1n;
      } else {
        high = mid;
      }
    }

    return low;
  }
}
