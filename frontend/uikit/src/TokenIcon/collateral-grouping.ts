import type { CollateralSymbol } from "../tokens";
import { WHITE_LABEL_CONFIG } from "../../../app/src/white-label.config";

export type CollateralGroup = {
  title: string;
  collaterals: Array<{ symbol: CollateralSymbol; name: string; maxLTV: number }>;
};

export function groupCollaterals(): CollateralGroup[] {
  const singleAssets: CollateralGroup['collaterals'] = [];
  const stablePairs: CollateralGroup['collaterals'] = [];
  const volatilePairs: CollateralGroup['collaterals'] = [];

  WHITE_LABEL_CONFIG.tokens.collaterals.forEach((collateral) => {
    const item = {
      symbol: collateral.symbol as CollateralSymbol,
      name: collateral.name,
      maxLTV: collateral.maxLTV,
    };

    // Check if it's an AMM token by type or by symbol pattern
    const isAMM = (collateral as any).type === "samm" || (collateral as any).type === "vamm" || 
                  collateral.symbol.includes("SAMM_") || collateral.symbol.includes("VAMM_");
    
    if (!isAMM) {
      // Single assets
      singleAssets.push(item);
    } else if ((collateral as any).type === "samm" || collateral.symbol.includes("SAMM_")) {
      // Stable pairs (sAMM) - higher LTV ~82.5%
      stablePairs.push(item);
    } else {
      // Volatile pairs (vAMM) - lower LTV ~70%
      volatilePairs.push(item);
    }
  });

  // Sort each group by LTV descending, then by name
  const sortGroup = (group: CollateralGroup['collaterals']) => 
    group.sort((a, b) => {
      if (b.maxLTV !== a.maxLTV) return b.maxLTV - a.maxLTV;
      return a.name.localeCompare(b.name);
    });

  return [
    {
      title: "Single Assets",
      collaterals: sortGroup(singleAssets),
    },
    {
      title: "Stable Pairs",
      collaterals: sortGroup(stablePairs),
    },
    {
      title: "Volatile Pairs", 
      collaterals: sortGroup(volatilePairs),
    },
  ].filter(group => group.collaterals.length > 0); // Only show groups that have items
}