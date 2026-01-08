import type { Address } from "viem";
import type { Config } from "../config.js";
import type { DistributionPeriod, Trove, TroveStatus } from "../types.js";

const SUBGRAPH_QUERY_LIMIT = 1000;

interface GraphQLResponse<T> {
  data?: T | null;
  errors?: unknown[];
}

interface TroveQueryResult {
  id: string;
  borrower: string;
  collateral: { id: string };
  deposit: string;
  createdAt: string;
  closedAt: string | null;
  updatedAt: string;
  status: string;
}

interface TrovesQueryResponse {
  activeTroves: TroveQueryResult[];
  closedTroves: TroveQueryResult[];
}

export class TroveQueryService {
  private config: Config;

  constructor(config: Config) {
    this.config = config;
  }

  /**
   * Execute a GraphQL query against the subgraph
   */
  private async query<T>(queryString: string, variables: Record<string, unknown>): Promise<T> {
    const response = await fetch(this.config.subgraphUrl, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        query: queryString,
        variables,
      }),
    });

    const json = (await response.json()) as GraphQLResponse<T>;

    if (!json.data || json.errors) {
      throw new Error(
        `GraphQL error: ${JSON.stringify(json.errors ?? "No data returned")}`,
      );
    }

    return json.data;
  }

  /**
   * Convert raw trove query result to Trove type
   */
  private parseTrove(raw: TroveQueryResult): Trove {
    return {
      id: raw.id,
      borrower: raw.borrower as Address,
      collateral: { id: raw.collateral.id },
      deposit: BigInt(raw.deposit),
      createdAt: BigInt(raw.createdAt),
      closedAt: raw.closedAt ? BigInt(raw.closedAt) : null,
      updatedAt: BigInt(raw.updatedAt),
      status: raw.status as TroveStatus,
    };
  }

  /**
   * Query troves that were active at any point during the distribution period.
   * This includes:
   * - Currently active troves created before period end
   * - Troves that were closed after period start (they contributed collateral for part of the period)
   *
   * @param collateralIds - Array of collateral IDs (collIndex) to filter by
   * @param period - The distribution period to query for
   */
  async getTrovesActiveInPeriod(
    collateralIds: string[],
    period: DistributionPeriod,
  ): Promise<Trove[]> {
    const allTroves: Trove[] = [];

    // Query in batches due to subgraph limits
    // We need two separate queries: one for active troves and one for closed troves

    // 1. Query currently active troves (paginated)
    let activeCursor = "";
    while (true) {
      const result = await this.query<{ troves: TroveQueryResult[] }>(
        `
        query ActiveTroves($collateralIds: [String!]!, $periodEnd: BigInt!, $cursor: ID!, $limit: Int!) {
          troves(
            where: {
              status: active
              collateral_in: $collateralIds
              createdAt_lt: $periodEnd
              id_gt: $cursor
            }
            orderBy: id
            first: $limit
          ) {
            id
            borrower
            collateral { id }
            deposit
            createdAt
            closedAt
            updatedAt
            status
          }
        }
        `,
        {
          collateralIds,
          periodEnd: period.endTimestamp.toString(),
          cursor: activeCursor,
          limit: SUBGRAPH_QUERY_LIMIT,
        },
      );

      const troves = result.troves.map((t) => this.parseTrove(t));
      allTroves.push(...troves);

      if (troves.length < SUBGRAPH_QUERY_LIMIT) break;
      activeCursor = result.troves[result.troves.length - 1].id;
    }

    // 2. Query troves that were closed during the period (paginated)
    let closedCursor = "";
    while (true) {
      const result = await this.query<{ troves: TroveQueryResult[] }>(
        `
        query ClosedTroves($collateralIds: [String!]!, $periodStart: BigInt!, $periodEnd: BigInt!, $cursor: ID!, $limit: Int!) {
          troves(
            where: {
              status_not: active
              collateral_in: $collateralIds
              createdAt_lt: $periodEnd
              closedAt_gt: $periodStart
              id_gt: $cursor
            }
            orderBy: id
            first: $limit
          ) {
            id
            borrower
            collateral { id }
            deposit
            createdAt
            closedAt
            updatedAt
            status
          }
        }
        `,
        {
          collateralIds,
          periodStart: period.startTimestamp.toString(),
          periodEnd: period.endTimestamp.toString(),
          cursor: closedCursor,
          limit: SUBGRAPH_QUERY_LIMIT,
        },
      );

      const troves = result.troves.map((t) => this.parseTrove(t));
      allTroves.push(...troves);

      if (troves.length < SUBGRAPH_QUERY_LIMIT) break;
      closedCursor = result.troves[result.troves.length - 1].id;
    }

    return allTroves;
  }

  /**
   * Get collateral IDs (collIndex) that match the given LP token addresses.
   * This requires querying the CollateralAddresses entity.
   */
  async getCollateralIdsForTokens(tokenAddresses: Address[]): Promise<string[]> {
    // Convert addresses to lowercase for comparison (subgraph stores as lowercase hex)
    const lowerTokens = tokenAddresses.map((addr) => addr.toLowerCase());

    const result = await this.query<{ collateralAddresses: { collateral: { id: string }; token: string }[] }>(
      `
      query CollateralsByToken($tokens: [Bytes!]!) {
        collateralAddresses(where: { token_in: $tokens }) {
          collateral { id }
          token
        }
      }
      `,
      { tokens: lowerTokens },
    );

    return result.collateralAddresses.map((c) => c.collateral.id);
  }
}
