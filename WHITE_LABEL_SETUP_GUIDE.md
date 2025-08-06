# White-Label Setup Guide

## Setup

1. **Configure**: Edit `/frontend/app/src/white-label.config.ts`
2. **Replace icon**: `/frontend/uikit/src/token-icons/main-token.svg` 
3. **Build**: `pnpm build`

## Configuration Options

- **`mainToken`** - Your stablecoin (name, symbol, ticker, description)
- **`header.appName`** - App name in header
- **`navigation.showBorrow/showEarn/showStake`** - Hide/show sections
- **`navigation.items`** - Custom labels for menu items
- **`brandColors`** - Primary brand colors for ActionCards and hero elements

## Assets to Replace

- `main-token.svg` - Your token icon (24x24px SVG)  
- `/frontend/app/src/assets/logo.svg` - Your app logo (32x32px SVG)

## Colors & Design

For custom colors/branding, provide your brand colors and design system to Claude/AI with this prompt:

```
Update /frontend/uikit/src/Theme/Theme.tsx with my brand colors:
- Primary: #YOUR_COLOR
- Secondary: #YOUR_COLOR  
- Background: #YOUR_COLOR
[include your full color palette]

Keep the same semantic structure but map colors to match my brand.
```

## What Updates Automatically

When you change the token symbol, all references throughout the app update automatically:
- UI text, forms, transaction flows
- Price displays, tooltips, navigation
- TypeScript types with full type safety