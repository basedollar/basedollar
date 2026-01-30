import type { Address } from "viem";
import type { Config } from "../config.js";
import type {
  AeroLPCollateral,
  ClaimedEvent,
  DistributedEvent,
  DistributionPeriod,
  GaugeDistributionInfo,
  StakedEvent,
} from "../types.js";

const SUBGRAPH_QUERY_LIMIT = 1000;
const ORIGIN_TIMESTAMP = 0n;

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
          epoch: string;
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
            epoch
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
          epoch: BigInt(row.epoch),
          blockNumber: BigInt(row.blockNumber),
          timestamp: BigInt(row.timestamp),
          transactionHash: row.transactionHash as `0x${string}`,
        });
      }

      if (data.aeroClaims.length < SUBGRAPH_QUERY_LIMIT) break;
      cursor = data.aeroClaims[data.aeroClaims.length - 1].id;
    }

    return events;
  }

  /**
   * Fetch all AeroDistributed events from AeroManager contract
   */
  async getDistributedEvents(period?: DistributionPeriod): Promise<DistributedEvent[]> {
    const events: DistributedEvent[] = [];
    let cursor = "";

    for (;;) {
      const data = await this.query<{
        aeroDistributions: Array<{
          id: string;
          gauge: string;
          recipients: string;
          totalRewardAmount: string;
          epoch: string;
          blockNumber: string;
          timestamp: string;
          transactionHash: string;
        }>;
      }>(
        `
        query AeroDistributions($cursor: ID!, $limit: Int!, $start: BigInt, $end: BigInt) {
          aeroDistributions(
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
            recipients
            totalRewardAmount
            epoch
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

      for (const row of data.aeroDistributions) {
        events.push({
          gauge: row.gauge as Address,
          recipients: BigInt(row.recipients),
          totalRewardAmount: BigInt(row.totalRewardAmount),
          epoch: BigInt(row.epoch),
          blockNumber: BigInt(row.blockNumber),
          timestamp: BigInt(row.timestamp),
          transactionHash: row.transactionHash as `0x${string}`,
        });
      }

      if (data.aeroDistributions.length < SUBGRAPH_QUERY_LIMIT) break;
      cursor = data.aeroDistributions[data.aeroDistributions.length - 1].id;
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
      aeroDistributions: Array<{ timestamp: string }>;
    }>(
      `
      query LatestAeroTimestamps {
        aeroClaims(first: 1, orderBy: timestamp, orderDirection: desc) { timestamp }
        aeroStakes(first: 1, orderBy: timestamp, orderDirection: desc) { timestamp }
        aeroDistributions(first: 1, orderBy: timestamp, orderDirection: desc) { timestamp }
      }
      `,
      {},
    );

    const claimTs = data.aeroClaims.length > 0 ? BigInt(data.aeroClaims[0].timestamp) : 0n;
    const stakeTs = data.aeroStakes.length > 0 ? BigInt(data.aeroStakes[0].timestamp) : 0n;
    const distTs = data.aeroDistributions.length > 0 ? BigInt(data.aeroDistributions[0].timestamp) : 0n;
    let ts = claimTs > stakeTs ? claimTs : stakeTs;
    ts = ts > distTs ? ts : distTs;

    // If nothing indexed yet, fall back to wall-clock time.
    if (ts === 0n) return BigInt(Math.floor(Date.now() / 1000));
    return ts;
  }

  /**
   * Get the latest distributed event per gauge.
   * Returns a map of gauge address to {epoch, timestamp}.
   */
  async getLatestDistributedEpochPerGauge(): Promise<Map<Address, { epoch: bigint; timestamp: bigint }>> {
    const events = await this.getDistributedEvents();

    const latestPerGauge = new Map<Address, { epoch: bigint; timestamp: bigint }>();
    for (const event of events) {
      const current = latestPerGauge.get(event.gauge);
      if (!current || event.epoch > current.epoch) {
        latestPerGauge.set(event.gauge, {
          epoch: event.epoch,
          timestamp: event.timestamp,
        });
      }
    }

    return latestPerGauge;
  }

  /**
   * Build per-gauge distribution info based on epoch data.
   * For each gauge:
   * - Start timestamp = timestamp of latest distributed event for that gauge
   * - End timestamp = current timestamp
   * - Total rewards = sum of claim events where gauge matches AND epoch = latestDistributedEpoch + 1
   */
  async getGaugeDistributionInfo(currentTimestamp: bigint): Promise<GaugeDistributionInfo[]> {
    // Get LP collaterals (gauge -> token mapping)
    const lpCollaterals = await this.getAeroLPCollaterals();
    if (lpCollaterals.length === 0) {
      return [];
    }

    // Get latest distributed epoch per gauge
    const latestDistributed = await this.getLatestDistributedEpochPerGauge();

    // Get all claim events (unfiltered by time)
    const allClaims = await this.getClaimedEvents();

    // Build distribution info per gauge
    const result: GaugeDistributionInfo[] = [];

    for (const lp of lpCollaterals) {
      const distributed = latestDistributed.get(lp.gauge);

      const claimEpoch = distributed ? distributed.epoch + 1n : 0n;

      // Sum claims for this gauge at claimEpoch
      let totalRewards = 0n;
      for (const claim of allClaims) {
        if (claim.gauge === lp.gauge && claim.epoch === claimEpoch) {
          // total includes the fee, subtract it for distribution amount
          totalRewards += claim.total - claim.claimFee;
        }
      }

      result.push({
        gauge: lp.gauge,
        token: lp.token,
        period: {
          startTimestamp: distributed?.timestamp ?? ORIGIN_TIMESTAMP,
          endTimestamp: currentTimestamp,
        },
        latestDistributedEpoch: distributed?.epoch ?? 0n,
        claimEpoch,
        totalRewards,
      });
    }

    return result;
  }
}
