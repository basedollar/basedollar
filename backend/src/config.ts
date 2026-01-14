import type { Address } from "viem";

export interface Config {
  // RPC URL for Base network
  rpcUrl: string;
  // Subgraph URL for querying trove data
  subgraphUrl: string;
  // AeroManager contract address
  aeroManagerAddress: Address;
  // Distribution period in seconds (default: 7 days)
  distributionPeriodSeconds: bigint;
  // Block to start fetching events from
  startBlock: bigint;
}

function getEnvOrThrow(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function getEnvOrDefault(name: string, defaultValue: string): string {
  return process.env[name] ?? defaultValue;
}

export function loadConfig(): Config {
  return {
    rpcUrl: getEnvOrThrow("RPC_URL"),
    subgraphUrl: getEnvOrThrow("SUBGRAPH_URL"),
    aeroManagerAddress: getEnvOrThrow("AERO_MANAGER_ADDRESS") as Address,
    distributionPeriodSeconds: BigInt(
      getEnvOrDefault("DISTRIBUTION_PERIOD_SECONDS", "604800"), // 7 days
    ),
    startBlock: BigInt(getEnvOrDefault("START_BLOCK", "0")),
  };
}

// AeroManager ABI for the events we need
export const AERO_MANAGER_ABI = [
  {
    type: "event",
    name: "Staked",
    inputs: [
      { name: "gauge", type: "address", indexed: true },
      { name: "token", type: "address", indexed: false },
      { name: "amount", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "Claimed",
    inputs: [
      { name: "gauge", type: "address", indexed: true },
      { name: "total", type: "uint256", indexed: false },
      { name: "claimFee", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "ActivePoolAdded",
    inputs: [{ name: "activePool", type: "address", indexed: true }],
  },
] as const;
