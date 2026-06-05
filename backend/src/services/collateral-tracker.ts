import type { Config } from "../config.js";
import type {
  DistributionPeriod,
  Trove,
  TrovePositionSnapshot,
  TrovePositionTWA,
  TroveStatus,
} from "../types.js";

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
  debt: string;
  interestRate: string;
  status: string;
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
   * Fetch all TroveSnapshot rows needed to reconstruct position state through the
   * period. Snapshots are post-operation state, so the latest snapshot before the
   * period start is needed to price the first interval correctly.
   */
  async getSnapshotsForTroves(
    troveIds: string[],
    period: DistributionPeriod,
  ): Promise<Map<string, TrovePositionSnapshot[]>> {
    const byTrove = new Map<string, TrovePositionSnapshot[]>();
    for (const id of troveIds) byTrove.set(id, []);

    for (let offset = 0; offset < troveIds.length; offset += TROVE_SNAPSHOT_TROVE_ID_BATCH) {
      const troveIdBatch = troveIds.slice(offset, offset + TROVE_SNAPSHOT_TROVE_ID_BATCH);
      let cursor = "";

      for (;;) {
        const result = await this.query<{ troveSnapshots: TroveSnapshotRow[] }>(
          `
          query TroveSnapshots($troveIds: [String!]!, $end: BigInt!, $cursor: ID!, $limit: Int!) {
            troveSnapshots(
              where: { trove_in: $troveIds, timestamp_lte: $end, id_gt: $cursor }
              orderBy: id
              orderDirection: asc
              first: $limit
            ) {
              id
              trove { id }
              deposit
              debt
              interestRate
              status
              timestamp
            }
          }
          `,
          {
            troveIds: troveIdBatch,
            end: period.endTimestamp.toString(),
            cursor,
            limit: SUBGRAPH_QUERY_LIMIT,
          },
        );

        const rows = result.troveSnapshots;
        for (const row of rows) {
          const snapshot: TrovePositionSnapshot = {
            troveId: row.trove.id,
            deposit: BigInt(row.deposit),
            debt: BigInt(row.debt),
            interestRate: BigInt(row.interestRate),
            status: row.status as TroveStatus,
            timestamp: BigInt(row.timestamp),
          };
          const arr = byTrove.get(row.trove.id);
          if (arr) arr.push(snapshot);
        }

        if (rows.length < SUBGRAPH_QUERY_LIMIT) break;
        cursor = rows[rows.length - 1].id;
      }
    }

    for (const [id, arr] of byTrove.entries()) {
      arr.sort((a, b) => (a.timestamp < b.timestamp ? -1 : a.timestamp > b.timestamp ? 1 : 0));
      byTrove.set(id, arr);
    }

    return byTrove;
  }

  /**
   * Calculate time-weighted average deposit, debt, and interest rate for a trove
   * over the period. Only intervals whose state is active contribute to activeTime.
   */
  calculateTWA(
    trove: Trove,
    snapshots: TrovePositionSnapshot[],
    period: DistributionPeriod,
  ): TrovePositionTWA {
    const empty = {
      troveId: trove.id,
      borrower: trove.borrower,
      collateralId: trove.collateral.id,
      timeWeightedAverageDeposit: 0n,
      timeWeightedAverageDebt: 0n,
      timeWeightedAverageInterestRate: 0n,
      activeTime: 0n,
    };

    if (period.startTimestamp >= period.endTimestamp) {
      return empty;
    }

    if (snapshots.length === 0) {
      const fallbackStart = trove.createdAt > period.startTimestamp ? trove.createdAt : period.startTimestamp;
      const fallbackEnd = trove.closedAt && trove.closedAt < period.endTimestamp
        ? trove.closedAt
        : period.endTimestamp;

      if (trove.status !== "active" || fallbackStart >= fallbackEnd) {
        return empty;
      }

      return {
        ...empty,
        timeWeightedAverageDeposit: trove.deposit,
        timeWeightedAverageDebt: trove.debt,
        timeWeightedAverageInterestRate: trove.interestRate,
        activeTime: fallbackEnd - fallbackStart,
      };
    }

    let currentDeposit = 0n;
    let currentDebt = 0n;
    let currentInterestRate = 0n;
    let currentStatus: TroveStatus = "closed";

    for (const snapshot of snapshots) {
      if (snapshot.timestamp > period.startTimestamp) {
        break;
      }

      currentDeposit = snapshot.deposit;
      currentDebt = snapshot.debt;
      currentInterestRate = snapshot.interestRate;
      currentStatus = snapshot.status;
    }

    let cursor = period.startTimestamp;
    let activeTime = 0n;
    let depositTimeWeightedSum = 0n;
    let debtTimeWeightedSum = 0n;
    let rateTimeWeightedSum = 0n;

    for (const snapshot of snapshots) {
      if (snapshot.timestamp <= period.startTimestamp) {
        continue;
      }
      if (snapshot.timestamp > period.endTimestamp) {
        break;
      }

      if (snapshot.timestamp > cursor && currentStatus === "active") {
        const duration = snapshot.timestamp - cursor;
        activeTime += duration;
        depositTimeWeightedSum += currentDeposit * duration;
        debtTimeWeightedSum += currentDebt * duration;
        rateTimeWeightedSum += currentInterestRate * duration;
      }

      currentDeposit = snapshot.deposit;
      currentDebt = snapshot.debt;
      currentInterestRate = snapshot.interestRate;
      currentStatus = snapshot.status;
      cursor = snapshot.timestamp;
    }

    if (cursor < period.endTimestamp && currentStatus === "active") {
      const duration = period.endTimestamp - cursor;
      activeTime += duration;
      depositTimeWeightedSum += currentDeposit * duration;
      debtTimeWeightedSum += currentDebt * duration;
      rateTimeWeightedSum += currentInterestRate * duration;
    }

    if (activeTime === 0n) {
      return empty;
    }

    return {
      ...empty,
      timeWeightedAverageDeposit: depositTimeWeightedSum / activeTime,
      timeWeightedAverageDebt: debtTimeWeightedSum / activeTime,
      timeWeightedAverageInterestRate: rateTimeWeightedSum / activeTime,
      activeTime,
    };
  }

  /**
   * Calculate TWA position metrics for multiple troves.
   */
  async calculateTWAForTroves(
    troves: Trove[],
    period: DistributionPeriod,
  ): Promise<TrovePositionTWA[]> {
    const troveIds = troves.map((t) => t.id);
    const snapshotsByTrove = await this.getSnapshotsForTroves(troveIds, period);

    return troves.map((trove) => {
      const snapshots = snapshotsByTrove.get(trove.id) ?? [];
      return this.calculateTWA(trove, snapshots, period);
    });
  }
}
