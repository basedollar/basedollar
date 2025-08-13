# White-Label Setup Guide

## Quick Setup

1. **Configure**: Edit `/frontend/app/src/white-label.config.ts`
2. **Replace icons**: Update token icons in `/frontend/uikit/src/token-icons/`
3. **Build**: `pnpm build`

## Configuration Options

- **`mainToken`** - Your stablecoin (name, symbol, ticker, description)
- **`collaterals`** - Array of supported collateral tokens with ratios and deployment addresses
- **`governanceToken`** - Your governance token configuration
- **`header.appName`** - App name in header
- **`navigation.showBorrow/showEarn/showStake`** - Hide/show sections
- **`brandColors`** - Primary brand colors for ActionCards and hero elements
- **`typography.fontFamily`** - Font family CSS value (e.g., "Inter, sans-serif")

## Required Icons (24x24px SVG)

- `/frontend/uikit/src/token-icons/main-token.svg` - Your stablecoin icon
- `/frontend/uikit/src/token-icons/lqty.svg` - Governance token icon
- `/frontend/app/src/assets/logo.svg` - App logo (32x32px)
- Collateral icons (see "Adding Collaterals" below)

## Adding New Collaterals

1. **Add icon**: Create `/frontend/uikit/src/token-icons/mytoken.svg`

2. **Map icon**: In `/frontend/uikit/src/tokens.ts`:
   ```typescript
   // Add import at top
   import tokenMytoken from "./token-icons/mytoken.svg";
   
   // Add to collateralIcons object
   const collateralIcons: Record<string, string> = {
     ETH: tokenEth,
     RETH: tokenReth,
     WSTETH: tokenWsteth,
     MYTOKEN: tokenMytoken, // Add this line
   };
   ```

3. **Add config**: In `/frontend/app/src/white-label.config.ts`:
   ```typescript
   collaterals: [
     // existing collaterals...
     {
       symbol: "MYTOKEN" as const,
       name: "My Token",
       collateralRatio: 1.2,
       maxDeposit: "100000000",
       maxLTV: 0.916,
       deployments: {
         1: { // mainnet
           collToken: "0x...",
           leverageZapper: "0x...",
           stabilityPool: "0x...",
           troveManager: "0x...",
         }
       }
     }
   ]
   ```

4. **Deploy contracts** and update deployment addresses

Everything else updates automatically.

## Font Setup

After changing `typography.fontFamily` in the config:
1. Import your font in `/frontend/app/src/app/layout.tsx`
2. Apply the font class to the body element

Example for Google Fonts:
```typescript
import { Inter } from "next/font/google"
const inter = Inter({ subsets: ["latin"] })
// In body tag: className={inter.className}
```

## Custom Colors

For custom colors/branding, ask Claude to:
```
Update /frontend/uikit/src/Theme/Theme.tsx with my brand colors:
- Primary: #YOUR_COLOR
- Secondary: #YOUR_COLOR  
- Background: #YOUR_COLOR
[include your full color palette]

Keep the same semantic structure but map colors to match my brand.
```

## What Updates Automatically

When you update the config, these update automatically:
- UI text, forms, transaction flows
- Price displays, tooltips, navigation  
- TypeScript types with full type safety
- Token selection dropdowns
- All collateral-specific screens and flows