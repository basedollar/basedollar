import type { Address } from "viem";
import type { Config } from "../config.js";
import type { AeroLPCollateral, ClaimedEvent, DistributionPeriod, StakedEvent } from "../types.js";

const SUBGRAPH_QUERY_LIMIT = 1000;

export class AeroEventsService {
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

    const json = (await response.json()) as { data?: T | null; errors?: unknown[] };
    if (!json.data || json.errors) {
      throw new Error(`GraphQL error: ${JSON.stringify(json.errors ?? "No data returned")}`);
    }
    return json.data;
  }

  /**
   * Fetch all Staked events from AeroManager contract
   */
  async getStakedEvents(period?: DistributionPeriod): Promise<StakedEvent[]> {
    const events: StakedEvent[] = [];
    let cursor = "";

    for (;;) {
      const data = await this.query<{
        aeroStakes: Array<{
          id: string;
          gauge: string;
          token: string;
          amount: string;
          blockNumber: string;
          timestamp: string;
          transactionHash: string;
        }>;
      }>(
        `
        query AeroStakes($cursor: ID!, $limit: Int!, $start: BigInt, $end: BigInt) {
          aeroStakes(
            where: {
              id_gt: $cursor
              timestamp_gte: $start
              timestamp_lt: $end
            }
            orderBy: id
            orderDirection: asc
            first: $limit
          ) {
            id
            gauge
            token
            amount
            blockNumber
            timestamp
            transactionHash
          }
        }
        `,
        {
          cursor,
          limit: SUBGRAPH_QUERY_LIMIT,
          start: period ? period.startTimestamp.toString() : null,
          end: period ? period.endTimestamp.toString() : null,
        },
      );

      for (const row of data.aeroStakes) {
        events.push({
          gauge: row.gauge as Address,
          token: row.token as Address,
          amount: BigInt(row.amount),
          blockNumber: BigInt(row.blockNumber),
          transactionHash: row.transactionHash as `0x${string}`,
        });
      }

      if (data.aeroStakes.length < SUBGRAPH_QUERY_LIMIT) break;
      cursor = data.aeroStakes[data.aeroStakes.length - 1].id;
    }

    return events;
  }

  /**
   * Fetch all Claimed events from AeroManager contract
   */
  async getClaimedEvents(period?: DistributionPeriod): Promise<ClaimedEvent[]> {
    const events: ClaimedEvent[] = [];
    let cursor = "";

    for (;;) {
      const data = await this.query<{
        aeroClaims: Array<{
          id: string;
          gauge: string;
          total: string;
          claimFee: string;
          blockNumber: string;
          timestamp: string;
          transactionHash: string;
        }>;
      }>(
        `
        query AeroClaims($cursor: ID!, $limit: Int!, $start: BigInt, $end: BigInt) {
          aeroClaims(
            where: {
              id_gt: $cursor
              timestamp_gte: $start
              timestamp_lt: $end
            }
            orderBy: id
            orderDirection: asc
            first: $limit
          ) {
            id
            gauge
            total
            claimFee
            blockNumber
            timestamp
            transactionHash
          }
        }
        `,
        {
          cursor,
          limit: SUBGRAPH_QUERY_LIMIT,
          start: period ? period.startTimestamp.toString() : null,
          end: period ? period.endTimestamp.toString() : null,
        },
      );

      for (const row of data.aeroClaims) {
        events.push({
          gauge: row.gauge as Address,
          total: BigInt(row.total),
          claimFee: BigInt(row.claimFee),
          blockNumber: BigInt(row.blockNumber),
          transactionHash: row.transactionHash as `0x${string}`,
        });
      }

      if (data.aeroClaims.length < SUBGRAPH_QUERY_LIMIT) break;
      cursor = data.aeroClaims[data.aeroClaims.length - 1].id;
    }

    return events;
  }

  /**
   * Extract unique Aero LP collateral tokens from Staked events.
   * These are the tokens that qualify for AERO rewards distribution.
   */
  async getAeroLPCollaterals(): Promise<AeroLPCollateral[]> {
    // Prefer the indexed AeroGauge mapping from the subgraph.
    const data = await this.query<{
      aeroGauges: Array<{
        gauge: string;
        token: string;
      }>;
    }>(
      `
      query AeroGauges($limit: Int!) {
        aeroGauges(first: $limit) {
          gauge
          token
        }
      }
      `,
      { limit: SUBGRAPH_QUERY_LIMIT },
    );

    return data.aeroGauges.map((g) => ({
      gauge: g.gauge as Address,
      token: g.token as Address,
    }));
  }

  /**
   * Get total claimed AERO for a specific period.
   * Uses block timestamps to filter events within the period.
   */
  async getTotalClaimedInPeriod(period: DistributionPeriod): Promise<bigint> {
    const claimedEvents = await this.getClaimedEvents(period);
    let totalClaimed = 0n;
    for (const event of claimedEvents) {
      // total includes the fee, so subtract it to get the amount for distribution
      totalClaimed += event.total - event.claimFee;
    }

    return totalClaimed;
  }

  /**
   * Get the latest indexed timestamp from the subgraph.
   * Note this is the last indexed block time, not necessarily the current chain head.
   */
  async getCurrentBlockTimestamp(): Promise<bigint> {
    const data = await this.query<{
      aeroClaims: Array<{ timestamp: string }>;
      aeroStakes: Array<{ timestamp: string }>;
    }>(
      `
      query LatestAeroTimestamps {
        aeroClaims(first: 1, orderBy: timestamp, orderDirection: desc) { timestamp }
        aeroStakes(first: 1, orderBy: timestamp, orderDirection: desc) { timestamp }
      }
      `,
      {},
    );

    const claimTs = data.aeroClaims.length > 0 ? BigInt(data.aeroClaims[0].timestamp) : 0n;
    const stakeTs = data.aeroStakes.length > 0 ? BigInt(data.aeroStakes[0].timestamp) : 0n;
    const ts = claimTs > stakeTs ? claimTs : stakeTs;

    // If nothing indexed yet, fall back to wall-clock time.
    if (ts === 0n) return BigInt(Math.floor(Date.now() / 1000));
    return ts;
  }
}
