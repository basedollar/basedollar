import type { Address } from "viem";

// AeroManager Events
export interface StakedEvent {
  gauge: Address;
  token: Address;
  amount: bigint;
  blockNumber: bigint;
  transactionHash: `0x${string}`;
}

export interface ClaimedEvent {
  gauge: Address;
  total: bigint;
  claimFee: bigint;
  epoch: bigint;
  blockNumber: bigint;
  timestamp: bigint;
  transactionHash: `0x${string}`;
}

export interface DistributedEvent {
  gauge: Address;
  recipients: bigint;
  totalRewardAmount: bigint;
  epoch: bigint;
  blockNumber: bigint;
  timestamp: bigint;
  transactionHash: `0x${string}`;
}

// Trove data from subgraph
export interface Trove {
  id: string; // "collIndex:troveId"
  borrower: Address;
  collateral: {
    id: string; // collIndex
  };
  deposit: bigint; // collateral amount
  debt: bigint; // borrowed debt amount
  interestRate: bigint; // annual interest rate, or effective batch rate
  createdAt: bigint; // timestamp
  closedAt: bigint | null; // timestamp, null if still active
  updatedAt: bigint; // timestamp
  status: TroveStatus;
}

export type TroveStatus = "active" | "closed" | "liquidated" | "redeemed";

// Position snapshot for TWA calculation
export interface TrovePositionSnapshot {
  troveId: string;
  deposit: bigint;
  debt: bigint;
  interestRate: bigint;
  status: TroveStatus;
  timestamp: bigint;
}

// Time-weighted average result for a trove
export interface TrovePositionTWA {
  troveId: string;
  borrower: Address;
  collateralId: string;
  timeWeightedAverageDeposit: bigint;
  timeWeightedAverageDebt: bigint;
  timeWeightedAverageInterestRate: bigint;
  // Time this trove was active during the period (in seconds)
  activeTime: bigint;
}

// Final distribution data per trove (keyed by troveId)
export interface TroveDistribution extends TrovePositionTWA {
  // Weight before the interest multiplier: (TWA deposit + TWA debt) * activeTime
  baseWeight: bigint;
  // Multiplier is numerator / denominator; denominator is 1 when global average rate is zero.
  interestMultiplierNumerator: bigint;
  interestMultiplierDenominator: bigint;
  // Scaled weight used for distribution. When denominator > 1, the common denominator is omitted.
  weight: bigint;
  // Reward amount allocated to this troveId
  rewardAmount: bigint;
}

// Distribution period configuration
export interface DistributionPeriod {
  startTimestamp: bigint;
  endTimestamp: bigint;
}

// Per-gauge distribution information derived from epochs
export interface GaugeDistributionInfo {
  gauge: Address;
  token: Address;
  period: DistributionPeriod;
  latestDistributedEpoch: bigint;
  claimEpoch: bigint; // latestDistributedEpoch + 1
  totalRewards: bigint; // sum of claims for this gauge at claimEpoch
}

// Aero LP collateral info
export interface AeroLPCollateral {
  token: Address;
  gauge: Address;
}

// Per-gauge distribution result
export interface GaugeDistributionResult {
  gauge: Address;
  token: Address;
  period: DistributionPeriod;
  latestDistributedEpoch: bigint;
  claimEpoch: bigint;
  totalRewards: bigint;
  distributions: TroveDistribution[];
}
