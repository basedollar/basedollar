# White-Label Setup Guide

## Quick Setup

1. **Configure**: Edit `/frontend/app/src/white-label.config.ts`
2. **Replace icons**: Update token icons in `/frontend/uikit/src/token-icons/`
3. **Build**: `pnpm build`

## Configuration Structure

```typescript
export const WHITE_LABEL_CONFIG = {
  // Brand identity
  branding: {
    appName: "Your App V2",           // Full app name for titles
    brandName: "Your Brand",          // Core brand name for protocol references
    appUrl: "https://yourapp.com/",
    navigation: { showBorrow: true, showEarn: true, showStake: false },
    menu: { dashboard: "Dashboard", borrow: "Borrow", earn: "Earn", stake: "Stake" },
    links: {
      docs: { base: "https://docs.yourapp.com/", redemptions: "...", earn: "..." },
      dune: "https://dune.com/yourapp",
      discord: "https://discord.gg/yourapp",
    }
  },

  // All tokens in one place
  tokens: {
    mainToken: { symbol: "YOUR", name: "Your Token", icon: "main-token" },
    governanceToken: { symbol: "GOV", name: "Gov Token", icon: "lqty" },
    collaterals: [
      { symbol: "ETH", name: "ETH", icon: "eth", collateralRatio: 1.1, maxDeposit: "100000000", maxLTV: 0.916, deployments: {...} },
      { symbol: "RETH", name: "Rocket Pool ETH", icon: "reth", collateralRatio: 1.2, maxDeposit: "50000000", maxLTV: 0.833, deployments: {...} }
    ],
    otherTokens: {
      lusd: { symbol: "LUSD", name: "LUSD", icon: "lusd" },
      staked: { symbol: "sYOUR", name: "sYour Token", icon: "sbold" }
    }
  },

  // Pool configuration
  earnPools: { enableStabilityPools: true, enableStakedMainToken: true },

  // Colors and fonts
  brandColors: { primary: "blue:500", secondary: "gray:100" },
  typography: { fontFamily: "Inter, sans-serif" }
}
```

## Required Icons (24x24px SVG)

Place these in `/frontend/uikit/src/token-icons/`:
- `main-token.svg` - Your stablecoin icon
- `lqty.svg` - Governance token icon  
- `eth.svg`, `reth.svg`, `wsteth.svg` - Collateral icons
- `lusd.svg`, `sbold.svg` - Other token icons

App logo: `/frontend/app/src/assets/logo.svg` (32x32px)

## Adding New Collaterals

### Step 1: Add Token Icon
Place your icon in `/frontend/uikit/src/token-icons/mytoken.svg` (24x24px)

Import it in `/frontend/uikit/src/tokens.ts`:
```typescript
import tokenMytoken from "./token-icons/mytoken.svg";

const tokenIconMap: Record<string, string> = {
  // existing icons...
  "mytoken": tokenMytoken,
};
```

### Step 2: Update white-label.config.ts
Add your collateral to the `collaterals` array:
```typescript
tokens: {
  collaterals: [
    // existing collaterals...
    {
      symbol: "MYTOKEN" as const,
      name: "My Token",
      icon: "mytoken",  // matches tokenIconMap key
      collateralRatio: 1.3,
      maxDeposit: "5000000",
      maxLTV: 0.769231,
      deployments: {
        646: {  // Your chain ID
          collToken: "0x...",  // Required: token address
          leverageZapper: "0x...",  // Optional
          stabilityPool: "0x...",   // Optional
          troveManager: "0x...",    // Optional
        },
      },
    },
  ]
}
```

### Step 3: Build and Run
```bash
pnpm build
pnpm dev
```



## Customizing Content

All app content comes from the config:
- **App name**: `branding.appName` ("Your App V2")  
- **Protocol references**: `branding.brandName` ("Your Brand")
- **Navigation labels**: `branding.menu.*`
- **Documentation links**: `branding.links.docs.*`
- **External links**: `branding.links.*`

## Earn Pools

Pools are auto-generated from config:
- **Stability Pools**: One per collateral (if `enableStabilityPools: true`)
- **Staked Token Pool**: Your staked main token (if `enableStakedMainToken: true`)  
- **Custom Pools**: Add to `earnPools.customPools` array

## Font Setup

1. Update `typography.fontFamily` in config
2. Import font in `/frontend/app/src/app/layout.tsx`
3. Apply to body element

