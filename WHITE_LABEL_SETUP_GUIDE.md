# White-Label Setup Guide

This guide explains how to customize the BOLD frontend for your white-label deployment.

## What Works Currently

1. **App Name Customization** - Change the header app name
2. **Navigation Control** - Show/hide navigation items (Borrow, Earn, Stake)
3. **Navigation Labels** - Custom labels for menu items
4. **Action Cards** - Dashboard cards automatically follow navigation settings

---

## Configuration

Edit the main configuration file: **`white-label.config.ts`**

### What you can configure:

- **`appName`** - Application name shown in header
- **`showBorrow`** - Show/hide Borrow navigation and action cards
- **`showEarn`** - Show/hide Earn navigation and action cards  
- **`showStake`** - Show/hide Stake navigation and action cards
- **Navigation labels** - Custom text for Dashboard, Borrow, Earn, Stake menu items
- **Main token** - Stablecoin name, symbol, ticker throughout the app

## Current Features

### 1. App Name
Change the app name in the header:
```typescript
appName: "Your Protocol Name"
```

### 2. Hide/Show Navigation & Action Cards
```typescript
navigation: {
  showBorrow: false,  // Hides borrow nav + removes borrow action card
  showEarn: true,     // Shows earn nav + shows earn action card
  showStake: false,   // Hides stake nav + removes stake action card
}
```

### 3. Custom Navigation Labels
```typescript
items: {
  dashboard: { label: "Overview" },
  borrow: { label: "Lend" },
  earn: { label: "Farm" },
}
```

### 4. Main Token (Stablecoin)
```typescript
mainToken: {
  name: "BOLD",
  symbol: "BOLD",
  ticker: "BOLD",
  description: "USD-pegged stablecoin",
}
```

## To Customize Icons (Manual)

Replace icon files in `/frontend/uikit/src/icons/`:
- `IconDashboard.tsx`
- `IconBorrow.tsx` 
- `IconEarn.tsx`
- `IconStake.tsx`

Keep the same export name and props interface.

## Examples

### Hide Staking Completely
```typescript
navigation: {
  showStake: false,  // Removes stake from nav + dashboard
}
```

### Custom App Name + Labels
```typescript
header: {
  appName: "Gyoza",
  navigation: {
    items: {
      borrow: { label: "Lend", path: "/borrow" },
      earn: { label: "Yield", path: "/earn" },
    },
  },
}
```