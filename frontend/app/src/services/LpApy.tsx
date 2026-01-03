"use client";

import type { CollateralSymbol } from "@/src/types";
import type { UseQueryResult } from "@tanstack/react-query";

import { WHITE_LABEL_CONFIG } from "@/src/white-label.config";
import { useQuery } from "@tanstack/react-query";

const DEFILLAMA_YIELDS_URL = "https://yields.llama.fi/pools";
const LP_APY_REFRESH_INTERVAL = 5 * 60 * 1000; // 5 minutes

type DefiLlamaPool = {
  pool: string;
  project: string;
  symbol: string;
  apy: number;
  tvlUsd: number;
  chain: string;
};

type LpApyData = {
  apy: number;
  tvlUsd: number;
  source: "defillama" | "static";
};

// Cache for DefiLlama pools data
let poolsCache: DefiLlamaPool[] | null = null;
let poolsCacheTime = 0;
const POOLS_CACHE_TTL = 5 * 60 * 1000; // 5 minutes

async function fetchDefiLlamaPools(): Promise<DefiLlamaPool[]> {
  // Return cached data if still valid
  if (poolsCache && Date.now() - poolsCacheTime < POOLS_CACHE_TTL) {
    return poolsCache;
  }

  const response = await fetch(DEFILLAMA_YIELDS_URL);
  if (!response.ok) {
    throw new Error("Failed to fetch DefiLlama pools");
  }

  const data = await response.json();

  // Filter to Aerodrome pools on Base
  const aerodromePools = (data.data as DefiLlamaPool[]).filter(
    (pool) =>
      pool.project.toLowerCase().includes("aerodrome") &&
      pool.chain?.toLowerCase() === "base"
  );

  poolsCache = aerodromePools;
  poolsCacheTime = Date.now();

  return aerodromePools;
}

/**
 * Get collateral config with LP token info
 */
function getCollateralConfig(symbol: CollateralSymbol) {
  return WHITE_LABEL_CONFIG.tokens.collaterals.find(
    (c) => c.symbol === symbol
  );
}

/**
 * Check if a collateral is an LP token
 */
export function isLpToken(symbol: CollateralSymbol): boolean {
  const config = getCollateralConfig(symbol);
  if (!config) return false;
  return "type" in config && (config.type === "samm" || config.type === "vamm");
}

/**
 * Normalize token symbol for matching
 */
function normalizeSymbol(symbol: string): string {
  return symbol
    .toUpperCase()
    .replace(/^W/, "") // Remove leading W (WETH -> ETH)
    .replace("MSETH", "MSETH")
    .replace("MSUSD", "MSUSD");
}

/**
 * Match a collateral's token pair to DefiLlama pools
 */
function findMatchingPool(
  collateralSymbol: CollateralSymbol,
  pools: DefiLlamaPool[]
): DefiLlamaPool | null {
  const config = getCollateralConfig(collateralSymbol);
  if (!config || !("token1" in config) || !("token2" in config)) {
    return null;
  }

  const configToken1 = (config as { token1?: { symbol: string } }).token1;
  const configToken2 = (config as { token2?: { symbol: string } }).token2;
  if (!configToken1 || !configToken2) {
    return null;
  }

  const token1 = normalizeSymbol(configToken1.symbol);
  const token2 = normalizeSymbol(configToken2.symbol);

  // Determine pool type preference (v1 = classic AMM, slipstream = concentrated)
  // sAMM pools should prefer v1, vAMM can use either
  const preferredProject = config.type === "samm" ? "aerodrome-v1" : null;

  // Find matching pools (both orderings)
  const matchingPools = pools.filter((pool) => {
    const poolSymbol = pool.symbol.toUpperCase();
    const [poolToken1, poolToken2] = poolSymbol.split("-").map(normalizeSymbol);

    return (
      (poolToken1 === token1 && poolToken2 === token2) ||
      (poolToken1 === token2 && poolToken2 === token1)
    );
  });

  if (matchingPools.length === 0) {
    return null;
  }

  // If we have a preferred project, try to find that first
  if (preferredProject) {
    const preferredPool = matchingPools.find(
      (p) => p.project === preferredProject
    );
    if (preferredPool) {
      return preferredPool;
    }
  }

  // Otherwise, return the pool with highest TVL
  return matchingPools.reduce((best, current) =>
    current.tvlUsd > best.tvlUsd ? current : best
  );
}

/**
 * Get static APY from config as fallback
 */
function getStaticApy(symbol: CollateralSymbol): LpApyData | null {
  const config = getCollateralConfig(symbol);
  if (!config || !("poolData" in config) || !config.poolData?.apr) {
    return null;
  }

  // Parse APR string like "10.64%" to number
  const aprString = config.poolData.apr;
  const aprMatch = aprString.match(/[\d.]+/);
  if (!aprMatch) {
    return null;
  }

  return {
    apy: parseFloat(aprMatch[0]),
    tvlUsd: 0,
    source: "static",
  };
}

/**
 * Hook to get LP APY for a collateral
 * Only returns data from DefiLlama - no static fallback for pools that don't exist yet
 */
export function useLpApy(
  symbol: CollateralSymbol | null
): UseQueryResult<LpApyData | null> {
  return useQuery({
    queryKey: ["lpApy", symbol],
    queryFn: async () => {
      if (!symbol || !isLpToken(symbol)) {
        return null;
      }

      try {
        const pools = await fetchDefiLlamaPools();
        const matchingPool = findMatchingPool(symbol, pools);

        if (matchingPool) {
          return {
            apy: matchingPool.apy,
            tvlUsd: matchingPool.tvlUsd,
            source: "defillama" as const,
          };
        }
      } catch (error) {
        console.warn("Failed to fetch LP APY from DefiLlama:", error);
      }

      // No fallback - return null if pool doesn't exist on DefiLlama
      return null;
    },
    enabled: symbol !== null && isLpToken(symbol),
    refetchInterval: LP_APY_REFRESH_INTERVAL,
    staleTime: LP_APY_REFRESH_INTERVAL,
  });
}

/**
 * Hook to get all LP APYs at once
 * Only returns data from DefiLlama - no static fallback for pools that don't exist yet
 */
export function useAllLpApys(): UseQueryResult<Map<CollateralSymbol, LpApyData>> {
  return useQuery({
    queryKey: ["allLpApys"],
    queryFn: async () => {
      const result = new Map<CollateralSymbol, LpApyData>();

      // Get all LP token collaterals
      const lpCollaterals = WHITE_LABEL_CONFIG.tokens.collaterals.filter(
        (c) => "type" in c && (c.type === "samm" || c.type === "vamm")
      );

      try {
        const pools = await fetchDefiLlamaPools();

        for (const collateral of lpCollaterals) {
          const symbol = collateral.symbol as CollateralSymbol;
          const matchingPool = findMatchingPool(symbol, pools);

          if (matchingPool) {
            result.set(symbol, {
              apy: matchingPool.apy,
              tvlUsd: matchingPool.tvlUsd,
              source: "defillama",
            });
          }
          // No static fallback - skip pools that don't exist on DefiLlama
        }
      } catch (error) {
        console.warn("Failed to fetch LP APYs from DefiLlama:", error);
        // Return empty map on error - no static fallback
      }

      return result;
    },
    refetchInterval: LP_APY_REFRESH_INTERVAL,
    staleTime: LP_APY_REFRESH_INTERVAL,
  });
}
