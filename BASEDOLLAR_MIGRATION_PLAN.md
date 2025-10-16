# Basedollar Migration Plan

## Overview
This document tracks the migration from Liquity V2 to Basedollar (BD) on Base chain.

## ✅ Completed Changes

### 1. Frontend Branding Updates
- Updated `frontend/app/src/white-label.config.ts`:
  - Changed main token from "YOUR" to "BD" (Basedollar)
  - Changed governance token from "GOV" to "BASED"
  - Updated app name to "Basedollar"
  - Updated all URLs to basedollar.org
  - Changed staked token symbols to sBD

### 2. Documentation
- README already contains the 14 Basedollar changes
- Created CLAUDE.md for development guidance

## 🚧 Pending Changes (Easy)

### 1. Token Renaming in Contracts
**⚠️ IMPORTANT: Do not modify contracts until ready for full deployment**

When ready, rename:
- `BoldToken.sol` → `BDToken.sol`
- `IBoldToken.sol` → `IBDToken.sol`
- Update all references to "BOLD" → "BD" in contracts
- Update token name: "BOLD Stablecoin" → "Basedollar"
- Update token symbol: "BOLD" → "BD"

### 2. Update Deployment Parameters
- Gas deposit requirements for Base
- Minimum redemption size for Base
- Update collateral parameters for Base-specific tokens

## 🔴 Complex Changes (Need Implementation)

### 1. Superfluid Streaming Integration
- Add Superfluid streaming directly into BD token
- Update tests that use memory layout `deal()` function

### 2. Redemption Protected Branches
- Implement branches that can't be redeemed against
- Add alternative requirements for these branches

### 3. AERO Synergy Features
- Support vAMM and sAMM LP tokens as collateral
- Implement LP token staking for AERO rewards
- Add AERO distribution logic (% to treasury)
- Implement withdrawal queue for staked assets
- Update liquidation system for staked assets

### 4. Governance Features
- Add debt limit controls per collateral branch
- Implement ability to add/remove collateral branches
- Add safe wind-down mechanisms for branches

### 5. Revenue Distribution
- Change from 75/25 split to custom distribution:
  - 80% to sBaseD (stability pool)
  - 10% to POL treasury
  - 10% to GovToken holders
- Implement timelock treasury

### 6. New Collateral Types
Need to add support for:
- ETH (90.91% LTV)
- wstETH (87.5% LTV)
- rETH (87.5% LTV)  
- superOETHb (85% LTV)
- cbBTC (87.5% LTV)
- AERO
- vAMM LP tokens (70% LTV)
- sAMM LP tokens (82.5% LTV)

### 7. Price Feed Updates
- Implement OEV (Oracle Extractable Value) pricefeeds
- Add Base-specific oracle integrations

### 8. Stability Pool Structure
- Implement sBaseD (aggregated stability pool)
- Implement FsBaseD (opt-in layer for AERO rewards)
- No dedicated SP for sAMM/vAMM borrowers

## Next Steps

### Phase 1: Safe Frontend Updates ✅
1. Update white label config (DONE)
2. Test frontend with existing contracts
3. Ensure no breaking changes

### Phase 2: Prepare Contract Changes
1. Create new branch for contract modifications
2. Rename token contracts and interfaces
3. Update all BOLD references to BD
4. Add Superfluid integration points

### Phase 3: Add Base-Specific Features
1. Implement AERO synergy
2. Add redemption protected branches
3. Update price feeds
4. Add new collateral types

### Phase 4: Governance & Revenue
1. Implement governance controls
2. Update revenue distribution
3. Add timelock treasury

### Phase 5: Testing & Deployment
1. Update test suite for BD changes
2. Deploy to Base testnet
3. Audit changes
4. Deploy to Base mainnet

## Important Notes

- **DO NOT** modify production contracts until ready for full redeployment
- Frontend can use white label config for branding without breaking contracts
- Prioritize non-breaking changes first
- Test thoroughly on testnet before mainnet deployment
- Consider audit requirements for new features (especially AERO integration)

## Contract Files to Update (When Ready)

Key files that will need updates:
- `contracts/src/BoldToken.sol` → `BDToken.sol`
- `contracts/src/Interfaces/IBoldToken.sol` → `IBDToken.sol`
- All contracts importing IBoldToken
- Deployment scripts in `contracts/script/`
- Test files referencing BOLD token
- Subgraph configurations

## Testing Checklist

Before deployment:
- [ ] All BOLD references changed to BD
- [ ] Superfluid streaming works
- [ ] AERO rewards distribution correct
- [ ] Redemption protected branches functional
- [ ] New collateral types working
- [ ] Price feeds accurate
- [ ] Governance controls operational
- [ ] Revenue splits correct
- [ ] Frontend fully integrated