import tokenMainToken from "./token-icons/main-token.svg";
import tokenLqty from "./token-icons/lqty.svg";
import tokenLusd from "./token-icons/lusd.svg";
import tokenSbold from "./token-icons/sbold.svg";
import { WHITE_LABEL_CONFIG } from "../../app/src/white-label.config";

// Import all available collateral icons
import tokenEth from "./token-icons/eth.svg";
import tokenReth from "./token-icons/reth.svg";
import tokenWsteth from "./token-icons/wsteth.svg";
import tokenOseth from "./token-icons/oseth.svg";
import tokenSuperoethb from "./token-icons/superoethb.svg";
import tokenCbbtc from "./token-icons/cbbtc.svg";

// Import icons for AMM pair tokens - now we have them!
import tokenAero from "./token-icons/aero.svg";
import tokenUsdc from "./token-icons/usdc.svg";
import tokenMseth from "./token-icons/mseth.svg";
import tokenMsusd from "./token-icons/msusd.svg";
import tokenWell from "./token-icons/well.svg";
import tokenVirtual from "./token-icons/virtual.svg";
import tokenWeth from "./token-icons/weth.svg";
import tokenBold from "./token-icons/bold.svg";
import tokenDefault from "./token-icons/default.svg"; // Fallback

// Map of available token icons by icon name from config
const tokenIconMap: Record<string, string> = {
  "main-token": tokenMainToken,
  "governance-token": tokenLqty,
  "legacy-stablecoin": tokenLusd,
  "staked-main-token": tokenSbold,
  "eth": tokenEth,
  "reth": tokenReth,
  "wsteth": tokenWsteth,
  "oseth": tokenOseth,
  "superoethb": tokenSuperoethb,
  "cbbtc": tokenCbbtc,
  "aero": tokenAero,
  "usdc": tokenUsdc,
  "mseth": tokenMseth,
  "msusd": tokenMsusd,
  "lusd": tokenLusd,
  "well": tokenWell,
  "virtual": tokenVirtual,
  "weth": tokenWeth,
  
  // AMM LP token icons (will use fallback for now)  
  "bold": tokenBold,
  "samm-lp": tokenDefault, // TODO: Add sAMM LP icon or composite
  "vamm-lp": tokenDefault, // TODO: Add vAMM LP icon or composite
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
type ConfigCollateralSymbol = typeof WHITE_LABEL_CONFIG.tokens.collaterals[number]["symbol"];

export type TokenSymbol =
  | typeof WHITE_LABEL_CONFIG.tokens.mainToken.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.governanceToken.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.eth.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.staked.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.usdc.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.weth.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.mseth.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.msusd.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.well.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.virtual.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.cbbtc.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.bold.symbol
  | ConfigCollateralSymbol;

export type CollateralSymbol = ConfigCollateralSymbol;

export function isTokenSymbol(symbolOrUrl: string): symbolOrUrl is TokenSymbol {
  return (
    symbolOrUrl === WHITE_LABEL_CONFIG.tokens.mainToken.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.governanceToken.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.eth.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.staked.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.usdc.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.weth.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.mseth.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.msusd.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.well.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.virtual.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.cbbtc.symbol
    || symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.bold.symbol
    || WHITE_LABEL_CONFIG.tokens.collaterals.some(c => c.symbol === symbolOrUrl)
  );
}

export function isCollateralSymbol(symbol: string): symbol is CollateralSymbol {
  return WHITE_LABEL_CONFIG.tokens.collaterals.some(c => c.symbol === symbol);
}

export type CollateralToken = Token & {
  collateralRatio: number;
  symbol: CollateralSymbol;
};

// Generate all tokens from unified config
const MAIN_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.mainToken.icon],
  name: WHITE_LABEL_CONFIG.tokens.mainToken.name,
  symbol: WHITE_LABEL_CONFIG.tokens.mainToken.symbol,
} as const;

const GOVERNANCE_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.governanceToken.icon],
  name: WHITE_LABEL_CONFIG.tokens.governanceToken.name,
  symbol: WHITE_LABEL_CONFIG.tokens.governanceToken.symbol,
} as const;


const ETH_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.eth.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.eth.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.eth.symbol,
} as const;

const SBOLD_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.symbol,
} as const;

const LUSD_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.symbol,
} as const;

// Additional tokens for AMM pairs
const USDC_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.usdc.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.usdc.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.usdc.symbol,
} as const;

const WETH_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.weth.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.weth.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.weth.symbol,
} as const;

const MSETH_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.mseth.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.mseth.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.mseth.symbol,
} as const;

const MSUSD_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.msusd.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.msusd.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.msusd.symbol,
} as const;

const WELL_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.well.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.well.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.well.symbol,
} as const;

const VIRTUAL_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.virtual.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.virtual.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.virtual.symbol,
} as const;

const CBBTC_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.cbbtc.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.cbbtc.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.cbbtc.symbol,
} as const;

const BOLD_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.bold.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.bold.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.bold.symbol,
} as const;


// Generate collaterals from config using dynamic icons
export const COLLATERALS: CollateralToken[] = WHITE_LABEL_CONFIG.tokens.collaterals.map(collateral => {
  const iconUrl = tokenIconMap[collateral.icon];
  if (!iconUrl) {
    console.warn(`Missing icon mapping for "${collateral.icon}" (${collateral.symbol}), using fallback`);
  }
  return {
    collateralRatio: collateral.collateralRatio,
    icon: iconUrl || tokenIconMap["main-token"], // fallback to main token icon
    name: collateral.name,
    symbol: collateral.symbol,
  };
});

// Build tokens map from config-driven definitions
const tokensMap: Record<string, Token | CollateralToken> = {
  [WHITE_LABEL_CONFIG.tokens.mainToken.symbol]: MAIN_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.governanceToken.symbol]: GOVERNANCE_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.eth.symbol]: ETH_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.symbol]: SBOLD_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.symbol]: LUSD_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.usdc.symbol]: USDC_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.weth.symbol]: WETH_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.mseth.symbol]: MSETH_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.msusd.symbol]: MSUSD_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.well.symbol]: WELL_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.virtual.symbol]: VIRTUAL_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.cbbtc.symbol]: CBBTC_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.bold.symbol]: BOLD_TOKEN,
};

// Add all collaterals to the map
COLLATERALS.forEach(collateral => {
  tokensMap[collateral.symbol] = collateral;
});

export const TOKENS_BY_SYMBOL = tokensMap as Record<TokenSymbol, Token | CollateralToken>;
