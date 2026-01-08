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

// Final distribution data per user
export interface UserDistribution {
  borrower: Address;
  troves: TroveCollateralTWA[];
  totalTimeWeightedCollateral: bigint;
  // Reward amount - to be calculated by rewards-calculator.ts
  rewardAmount?: bigint;
}

// Distribution calculation result
export interface DistributionResult {
  period: DistributionPeriod;
  lpCollaterals: AeroLPCollateral[];
  totalClaimedAero: bigint;
  distributions: UserDistribution[];
}
