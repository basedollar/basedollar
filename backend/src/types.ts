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
  blockNumber: bigint;
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
  createdAt: bigint; // timestamp
  closedAt: bigint | null; // timestamp, null if still active
  updatedAt: bigint; // timestamp
  status: TroveStatus;
}

export type TroveStatus = "active" | "closed" | "liquidated" | "redeemed";

// Collateral snapshot for TWA calculation
export interface CollateralSnapshot {
  troveId: string;
  deposit: bigint;
  timestamp: bigint;
}

// Time-weighted average result for a trove
export interface TroveCollateralTWA {
  troveId: string;
  borrower: Address;
  collateralId: string;
  timeWeightedAverage: bigint;
  // Time this trove was active during the period (in seconds)
  activeTime: bigint;
}

// Final distribution data per trove (keyed by troveId)
export interface TroveDistribution extends TroveCollateralTWA {
  // Weight used for distribution (e.g. TWA * activeTime)
  weight: bigint;
  // Reward amount allocated to this troveId
  rewardAmount: bigint;
}

// Distribution period configuration
export interface DistributionPeriod {
  startTimestamp: bigint;
  endTimestamp: bigint;
}

// Aero LP collateral info
export interface AeroLPCollateral {
  token: Address;
  gauge: Address;
}

// Distribution calculation result
export interface DistributionResult {
  period: DistributionPeriod;
  lpCollaterals: AeroLPCollateral[];
  totalClaimedAero: bigint;
  distributions: TroveDistribution[];
}
