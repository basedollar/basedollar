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

## Assets to Replace

- `main-token.svg` - Your token icon (24x24px SVG)  
- `/frontend/app/src/assets/logo.svg` - Your app logo (32x32px SVG)

## What Updates Automatically

When you change the token symbol, all references throughout the app update automatically:
- UI text, forms, transaction flows
- Price displays, tooltips, navigation
- TypeScript types with full type safety