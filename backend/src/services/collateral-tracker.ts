import type { Config } from "../config.js";
import type { CollateralSnapshot, DistributionPeriod, Trove, TroveCollateralTWA } from "../types.js";

const SUBGRAPH_QUERY_LIMIT = 1000;
const TROVE_SNAPSHOT_TROVE_ID_BATCH = 100;

interface GraphQLResponse<T> {
  data?: T | null;
  errors?: unknown[];
}

interface TroveSnapshotRow {
  id: string;
  trove: { id: string };
  deposit: string;
  timestamp: string;
}

export class CollateralTrackerService {
  private config: Config;

  constructor(config: Config) {
    this.config = config;
  }

  private async query<T>(queryString: string, variables: Record<string, unknown>): Promise<T> {
    const response = await fetch(this.config.subgraphUrl, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ query: queryString, variables }),
    });

    const json = (await response.json()) as GraphQLResponse<T>;
    if (!json.data || json.errors) {
      throw new Error(`GraphQL error: ${JSON.stringify(json.errors ?? "No data returned")}`);
    }
    return json.data;
  }

  /**
   * Fetch all TroveSnapshot rows for the given trove IDs within the period.
   * This assumes the subgraph is indexing `TroveSnapshot` entities.
   */
  async getSnapshotsForTroves(
    troveIds: string[],
    period: DistributionPeriod,
  ): Promise<Map<string, CollateralSnapshot[]>> {
    const byTrove = new Map<string, CollateralSnapshot[]>();
    for (const id of troveIds) byTrove.set(id, []);

    for (let offset = 0; offset < troveIds.length; offset += TROVE_SNAPSHOT_TROVE_ID_BATCH) {
      const troveIdBatch = troveIds.slice(offset, offset + TROVE_SNAPSHOT_TROVE_ID_BATCH);
      let cursor = "";

      for (;;) {
        const result = await this.query<{ troveSnapshots: TroveSnapshotRow[] }>(
          `
          query TroveSnapshots($troveIds: [String!]!, $start: BigInt!, $end: BigInt!, $cursor: ID!, $limit: Int!) {
            troveSnapshots(
              where: { trove_in: $troveIds, timestamp_gte: $start, timestamp_lte: $end, id_gt: $cursor }
              orderBy: id
              orderDirection: asc
              first: $limit
            ) {
              id
              trove { id }
              deposit
              timestamp
            }
          }
          `,
          {
            troveIds: troveIdBatch,
            start: period.startTimestamp.toString(),
            end: period.endTimestamp.toString(),
            cursor,
            limit: SUBGRAPH_QUERY_LIMIT,
          },
        );

        const rows = result.troveSnapshots;
        for (const row of rows) {
          const snapshot: CollateralSnapshot = {
            troveId: row.trove.id,
            deposit: BigInt(row.deposit),
            timestamp: BigInt(row.timestamp),
          };
          const arr = byTrove.get(row.trove.id);
          if (arr) arr.push(snapshot);
        }

        if (rows.length < SUBGRAPH_QUERY_LIMIT) break;
        cursor = rows[rows.length - 1].id;
      }
    }

    // Sort snapshots per trove by timestamp asc
    for (const [id, arr] of byTrove.entries()) {
      arr.sort((a, b) => (a.timestamp < b.timestamp ? -1 : a.timestamp > b.timestamp ? 1 : 0));
      byTrove.set(id, arr);
    }

    return byTrove;
  }

  /**
   * Calculate time-weighted average *deposit size* for a single trove over the period.
   *
   * TWA(deposit) = Sum of (deposit × time_held) / active_time_in_period
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

    // If no snapshots found for this trove, assume TWA deposit size is the current trove deposit.
    // (User-specified fallback behavior.)
    if (snapshots.length === 0) {
      return {
        troveId: trove.id,
        borrower: trove.borrower,
        collateralId: trove.collateral.id,
        timeWeightedAverage: trove.deposit,
        activeTime,
      };
    }

    // Use snapshots that fall within the trove's active window.
    const relevantSnapshots = snapshots.filter((s) => s.timestamp >= troveStart && s.timestamp <= troveEnd);
    if (relevantSnapshots.length === 0) {
      return {
        troveId: trove.id,
        borrower: trove.borrower,
        collateralId: trove.collateral.id,
        timeWeightedAverage: trove.deposit,
        activeTime,
      };
    }

    // Time-weighted sum over activeTime.
    let timeWeightedSum = 0n;
    let lastTimestamp = troveStart;
    // Assume deposit at troveStart equals the first snapshot's deposit (best effort).
    let lastDeposit = relevantSnapshots[0].deposit;

    for (const snapshot of relevantSnapshots) {
      if (snapshot.timestamp <= lastTimestamp) {
        lastDeposit = snapshot.deposit;
        continue;
      }
      const duration = snapshot.timestamp - lastTimestamp;
      timeWeightedSum += lastDeposit * duration;
      lastTimestamp = snapshot.timestamp;
      lastDeposit = snapshot.deposit;
    }

    // Tail segment until troveEnd
    if (lastTimestamp < troveEnd) {
      timeWeightedSum += lastDeposit * (troveEnd - lastTimestamp);
    }

    const timeWeightedAverage = timeWeightedSum / activeTime;

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
   *
   * @param troves - Array of troves to calculate TWA for
   * @param period - The distribution period
   */
  async calculateTWAForTroves(
    troves: Trove[],
    period: DistributionPeriod,
  ): Promise<TroveCollateralTWA[]> {
    const troveIds = troves.map((t) => t.id);
    const snapshotsByTrove = await this.getSnapshotsForTroves(troveIds, period);

    return troves.map((trove) => {
      const snapshots = snapshotsByTrove.get(trove.id) ?? [];
      return this.calculateTWA(trove, snapshots, period);
    });
  }
}
