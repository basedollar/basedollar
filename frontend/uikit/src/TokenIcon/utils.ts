import type { CollateralSymbol } from "../tokens";
import { WHITE_LABEL_CONFIG } from "../../../app/src/white-label.config";

export function isAmmCollateral(symbol: CollateralSymbol): boolean {
  const collateral = WHITE_LABEL_CONFIG.tokens.collaterals.find(c => c.symbol === symbol);
  return collateral?.type === "samm" || collateral?.type === "vamm" || false;
}

export function getAmmTokenPair(symbol: CollateralSymbol): { token1: { symbol: string; name: string }, token2: { symbol: string; name: string } } | null {
  const collateral = WHITE_LABEL_CONFIG.tokens.collaterals.find(c => c.symbol === symbol);
  if (!collateral || (!collateral.type || (collateral.type !== "samm" && collateral.type !== "vamm"))) {
    return null;
  }
  
  // TypeScript doesn't know about the new properties, so we cast
  const ammCollateral = collateral as any;
  return {
    token1: ammCollateral.token1,
    token2: ammCollateral.token2,
  };
}