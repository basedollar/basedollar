import type { CollateralSymbol } from "../tokens";
import { WHITE_LABEL_CONFIG } from "../../../app/src/white-label.config";

type AmmCollateral = {
  type: "samm" | "vamm";
  token1: { symbol: string; name: string };
  token2: { symbol: string; name: string };
};

function isAmmCollateralConfig(collateral: unknown): collateral is AmmCollateral {
  return (
    typeof collateral === "object"
    && collateral !== null
    && "type" in collateral
    && ((collateral as { type: unknown }).type === "samm" || (collateral as { type: unknown }).type === "vamm")
    && "token1" in collateral
    && "token2" in collateral
  );
}

export function isAmmCollateral(symbol: CollateralSymbol): boolean {
  const collateral = WHITE_LABEL_CONFIG.tokens.collaterals.find(c => c.symbol === symbol);
  return isAmmCollateralConfig(collateral);
}

export function getAmmTokenPair(symbol: CollateralSymbol): { token1: { symbol: string; name: string }, token2: { symbol: string; name: string } } | null {
  const collateral = WHITE_LABEL_CONFIG.tokens.collaterals.find(c => c.symbol === symbol);
  if (!isAmmCollateralConfig(collateral)) {
    return null;
  }

  return {
    token1: collateral.token1,
    token2: collateral.token2,
  };
}