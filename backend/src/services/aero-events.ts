import { createPublicClient, http, parseAbiItem, type Address } from "viem";
import { base } from "viem/chains";
import type { Config } from "../config.js";
import type { AeroLPCollateral, ClaimedEvent, DistributionPeriod, StakedEvent } from "../types.js";

export class AeroEventsService {
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
   * Fetch all Staked events from AeroManager contract
   */
  async getStakedEvents(fromBlock?: bigint, toBlock?: bigint): Promise<StakedEvent[]> {
    const logs = await this.client.getLogs({
      address: this.config.aeroManagerAddress,
      event: parseAbiItem(
        "event Staked(address indexed gauge, address token, uint256 amount)",
      ),
      fromBlock: fromBlock ?? this.config.startBlock,
      toBlock: toBlock ?? "latest",
    });

    return logs.map((log) => ({
      gauge: log.args.gauge as Address,
      token: log.args.token as Address,
      amount: log.args.amount as bigint,
      blockNumber: log.blockNumber,
      transactionHash: log.transactionHash,
    }));
  }

  /**
   * Fetch all Claimed events from AeroManager contract
   */
  async getClaimedEvents(fromBlock?: bigint, toBlock?: bigint): Promise<ClaimedEvent[]> {
    const logs = await this.client.getLogs({
      address: this.config.aeroManagerAddress,
      event: parseAbiItem(
        "event Claimed(address indexed gauge, uint256 total, uint256 claimFee)",
      ),
      fromBlock: fromBlock ?? this.config.startBlock,
      toBlock: toBlock ?? "latest",
    });

    return logs.map((log) => ({
      gauge: log.args.gauge as Address,
      total: log.args.total as bigint,
      claimFee: log.args.claimFee as bigint,
      blockNumber: log.blockNumber,
      transactionHash: log.transactionHash,
    }));
  }

  /**
   * Extract unique Aero LP collateral tokens from Staked events.
   * These are the tokens that qualify for AERO rewards distribution.
   */
  async getAeroLPCollaterals(): Promise<AeroLPCollateral[]> {
    const stakedEvents = await this.getStakedEvents();

    // Build a map of gauge -> token to get unique LP collaterals
    const collateralMap = new Map<Address, Address>();
    for (const event of stakedEvents) {
      // Use the most recent token address for each gauge
      collateralMap.set(event.gauge, event.token);
    }

    return Array.from(collateralMap.entries()).map(([gauge, token]) => ({
      gauge,
      token,
    }));
  }

  /**
   * Get total claimed AERO for a specific period.
   * Uses block timestamps to filter events within the period.
   */
  async getTotalClaimedInPeriod(period: DistributionPeriod): Promise<bigint> {
    // Get all claimed events
    const claimedEvents = await this.getClaimedEvents();

    // We need to filter by timestamp, which requires getting block timestamps
    // For efficiency, we'll fetch blocks in batches
    const blockNumbers = [...new Set(claimedEvents.map((e) => e.blockNumber))];
    const blockTimestamps = new Map<bigint, bigint>();

    // Fetch block timestamps
    for (const blockNumber of blockNumbers) {
      const block = await this.client.getBlock({ blockNumber });
      blockTimestamps.set(blockNumber, block.timestamp);
    }

    // Sum up claimed amounts within the period (excluding the fee that went to treasury)
    let totalClaimed = 0n;
    for (const event of claimedEvents) {
      const timestamp = blockTimestamps.get(event.blockNumber);
      if (timestamp && timestamp >= period.startTimestamp && timestamp < period.endTimestamp) {
        // total includes the fee, so we need to subtract it to get the amount for distribution
        totalClaimed += event.total - event.claimFee;
      }
    }

    return totalClaimed;
  }

  /**
   * Get the current block timestamp
   */
  async getCurrentBlockTimestamp(): Promise<bigint> {
    const block = await this.client.getBlock({ blockTag: "latest" });
    return block.timestamp;
  }
}
