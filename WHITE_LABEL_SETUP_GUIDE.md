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
      { symbol: "ETH", name: "ETH", icon: "eth", collateralRatio: 1.1, maxDeposit: "100000000", maxLTV: 0.916, deployments: {...} }
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

1. **Add icon**: Create `/frontend/uikit/src/token-icons/mytoken.svg`

2. **Add to icon map**: In `/frontend/uikit/src/tokens.ts`:
   ```typescript
   import tokenMytoken from "./token-icons/mytoken.svg";
   
   const tokenIconMap: Record<string, string> = {
     // existing icons...
     "mytoken": tokenMytoken,
   };
   ```

3. **Add config**: In `white-label.config.ts`:
   ```typescript
   tokens: {
     collaterals: [
       // existing collaterals...
       {
         symbol: "MYTOKEN" as const,
         name: "My Token",
         icon: "mytoken",  // matches icon map key
         collateralRatio: 1.2,
         maxDeposit: "100000000",
         maxLTV: 0.916,
         deployments: {
           1: { collToken: "0x...", leverageZapper: "0x...", stabilityPool: "0x...", troveManager: "0x..." }
         }
       }
     ]
   }
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

## What Updates Automatically

When you change the config:
✅ All UI text, navigation, forms, transaction flows  
✅ Token symbols, names, icons throughout the app  
✅ Documentation links, external links  
✅ TypeScript types with full type safety  
✅ Routing for collateral and earn pool pages

Just update the config and rebuild - everything else is dynamic.

## What Does NOT Change (And Why)

❌ **Smart Contract References** - These are immutable and must stay as-is:
- Field names: `stakedLQTY`, `voteLQTY`, `vetoLQTY` (actual blockchain data fields)
- Function names: `depositLQTY`, `withdrawLQTY` (deployed contract functions)  
- Contract addresses: `CONTRACT_LQTY_TOKEN` (actual deployed addresses)

❌ **API/Backend Integration** - These match the blockchain layer:
- GraphQL queries: `govUser.data?.stakedLQTY` (subgraph field names)
- Variable names: `const lqtyBalance =` (internal code variables)
- Type definitions: Interface fields that match contracts

**Why?** The smart contracts are deployed with LQTY field names. Changing these would break the blockchain integration. This is standard practice - you customize the UI layer while preserving the data layer contracts.

**Architecture:** UI shows "Stake MYTOKEN" to users, but code still calls `depositLQTY()` on the contract.