import tokenMainToken from "./token-icons/main-token.svg";
import tokenLqty from "./token-icons/lqty.svg";
import tokenLusd from "./token-icons/lusd.svg";
import tokenSbold from "./token-icons/sbold.svg";
import { WHITE_LABEL_CONFIG } from "../../app/src/white-label.config";

// Import all available collateral icons
import tokenEth from "./token-icons/eth.svg";
import tokenReth from "./token-icons/reth.svg";
import tokenWsteth from "./token-icons/wsteth.svg";

// Map of available collateral icons
const collateralIcons: Record<string, string> = {
  ETH: tokenEth,
  RETH: tokenReth,
  WSTETH: tokenWsteth,
};


// any external token, without a known symbol
export type ExternalToken = {
  icon: string;
  name: string;
  symbol: string;
};

// a token with a known symbol (TokenSymbol)
export type Token = ExternalToken & {
  icon: string;
  name: string;
  symbol: TokenSymbol;
};

// Generate types from config
type ConfigCollateralSymbol = typeof WHITE_LABEL_CONFIG.collaterals[number]["symbol"];

export type TokenSymbol =
  | typeof WHITE_LABEL_CONFIG.mainToken.symbol
  | typeof WHITE_LABEL_CONFIG.governanceToken.symbol
  | typeof WHITE_LABEL_CONFIG.otherTokens.lusd.symbol
  | typeof WHITE_LABEL_CONFIG.otherTokens.staked.symbol
  | ConfigCollateralSymbol;

export type CollateralSymbol = ConfigCollateralSymbol;

export function isTokenSymbol(symbolOrUrl: string): symbolOrUrl is TokenSymbol {
  return (
    symbolOrUrl === WHITE_LABEL_CONFIG.mainToken.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.governanceToken.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.otherTokens.lusd.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.otherTokens.staked.symbol
    || WHITE_LABEL_CONFIG.collaterals.some(c => c.symbol === symbolOrUrl)
  );
}

export function isCollateralSymbol(symbol: string): symbol is CollateralSymbol {
  return WHITE_LABEL_CONFIG.collaterals.some(c => c.symbol === symbol);
}

export type CollateralToken = Token & {
  collateralRatio: number;
  symbol: CollateralSymbol;
};

export const LUSD: Token = {
  icon: tokenLusd,
  name: WHITE_LABEL_CONFIG.otherTokens.lusd.name,
  symbol: WHITE_LABEL_CONFIG.otherTokens.lusd.symbol,
} as const;

export const MAIN_TOKEN: Token = {
  icon: tokenMainToken,
  name: WHITE_LABEL_CONFIG.mainToken.name,
  symbol: WHITE_LABEL_CONFIG.mainToken.symbol,
} as const;

export const LQTY: Token = {
  icon: tokenLqty,
  name: WHITE_LABEL_CONFIG.governanceToken.name,
  symbol: WHITE_LABEL_CONFIG.governanceToken.symbol,
} as const;

export const SBOLD: Token = {
  icon: tokenSbold,
  name: WHITE_LABEL_CONFIG.otherTokens.staked.name,
  symbol: WHITE_LABEL_CONFIG.otherTokens.staked.symbol,
} as const;

// Generate collaterals from config using dynamic icons
export const COLLATERALS: CollateralToken[] = WHITE_LABEL_CONFIG.collaterals.map(collateral => ({
  collateralRatio: collateral.collateralRatio,
  icon: collateralIcons[collateral.symbol] || tokenMainToken, // fallback to main token icon
  name: collateral.name,
  symbol: collateral.symbol,
}));

// Export individual tokens for backward compatibility
export const ETH = COLLATERALS.find(c => c.symbol === "ETH") ?? COLLATERALS[0];
export const RETH = COLLATERALS.find(c => c.symbol === "RETH") ?? COLLATERALS[0];
export const WSTETH = COLLATERALS.find(c => c.symbol === "WSTETH") ?? COLLATERALS[0];

// Build TOKENS_BY_SYMBOL with all tokens
const tokensMap: Record<string, Token | CollateralToken> = {
  [WHITE_LABEL_CONFIG.mainToken.symbol]: MAIN_TOKEN,
  [WHITE_LABEL_CONFIG.governanceToken.symbol]: LQTY,
  [WHITE_LABEL_CONFIG.otherTokens.lusd.symbol]: LUSD,
  [WHITE_LABEL_CONFIG.otherTokens.staked.symbol]: SBOLD,
};

// Add all collaterals to the map
COLLATERALS.forEach(collateral => {
  tokensMap[collateral.symbol] = collateral;
});

export const TOKENS_BY_SYMBOL = tokensMap as Record<TokenSymbol, Token | CollateralToken>;
