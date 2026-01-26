# Base Dollar hints:

## Helpers for non redeemable troves
`HintHelpers.sol` functions can be used with an appended `NonRedeemable` to the function name to work with all the non-redeemable troves.

For example, `predictRemoveFromBatchUpfrontFee()` becomes `predictRemoveFromBatchUpfrontFeeNonRedeemable()`, and should work the same way.


## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

Run tests with `forge test -vvv` to see the console logs, which will show trove URI data.

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

## Slither

Create a local Python env and activate it:

```shell
python3 -m venv .venv
source .venv/bin/activate
```

Install slither:

```shell
pip3 install -r requirements.txt
```

Install and use Solidity compiler:

```shell
solc-select install 0.8.18
solc-select use 0.8.18
```

Run slither:

```shell
slither src
```

## CollateralRegistry: Redeemable vs Non-Redeemable Collaterals

The `CollateralRegistry` contract maintains two separate collateral lists:

### Redeemable Collaterals
- Standard branches where Bold can be redeemed for the underlying collateral
- Limited to a maximum of **10 branches**
- Used in the `redeemCollateral()` function to proportionally redeem Bold across branches
- Accessed via `getTroveManager(index)`, `getTroveManagers()`, `getToken(index)`

### Non-Redeemable Collaterals
- Special branches (typically LP token collaterals) that are exempt from redemptions
- No limit on the number of branches
- Useful for volatile or complex collateral types where redemption mechanics could be problematic
- Accessed via `getNonRedeemableTroveManager(index)`, `getNonRedeemableTroveManagers()`, `getNonRedeemableToken(index)`

### Adding New Branches

New branches can be added via `createNewBranch(token, troveManager, isRedeemable)` by the collateral governor. If the new branch uses an Aero LP collateral, it is automatically registered with the AeroManager.

---

## AeroManager

The `AeroManager` contract manages AERO token rewards earned from Aerodrome LP positions used as collateral in Basedollar.

### AERO Flow

1. **Staking**: When LP tokens are deposited as collateral, the `ActivePool` calls `AeroManager.stake()` which deposits the LP tokens into the associated Aerodrome gauge
2. **Accrual**: AERO rewards accrue from the staked LP positions in the gauge
3. **Claiming**: Anyone can call `claim(gauge)` to claim AERO rewards from a gauge. A configurable fee (default 10%, max 20%) is sent to the treasury, and the remainder is held by AeroManager
4. **Distribution**: The governor calls `distributeAero(gauge, recipients)` to allocate rewards to borrowers based on their collateral amounts
5. **User Claims**: Users call `claimRewards(user)` to withdraw their allocated AERO rewards

### Key State

- `stakedAmounts[gauge]`: Total LP tokens staked per gauge
- `activePools[activePool]`: Registered ActivePools that can stake/withdraw
- `claimedAeroPerEpoch[epoch][gauge]`: AERO claimed per epoch per gauge
- `claimableRewards[user]`: AERO available for users to claim
- `claimFee`: Fee percentage taken on claims (sent to treasury)

### Governance Functions

- `setAeroTokenAddress(address)`: Update the AERO token address
- `setGovernor(address)`: Transfer governor role
- `updateClaimFee(uint256)`: Change the claim fee (increases require a 7-day delay)
- `acceptClaimFeeUpdate()`: Finalize a pending fee increase after the delay period
- `distributeAero(gauge, recipients[])`: Distribute claimed AERO to users for an epoch

---

## AeroLPTokenPriceFeed

The `AeroLPTokenPriceFeed` contract provides price feeds for Aerodrome LP tokens used as collateral.

### Price Calculation

The feed combines two data sources:
1. **Cumulative prices** from the Aerodrome pool (`pool.currentCumulativePrices()`)
2. **Chainlink USD oracles** for both token0 and token1 in the LP pair

### Oracle Validation

- Each Chainlink oracle has a staleness threshold
- The Aerodrome pool also has a staleness threshold for its cumulative prices
- If any oracle fails validation, the branch shuts down and falls back to `lastGoodPrice`

### Price Deviation Protection

A 2% deviation threshold is used to compare pool prices against Chainlink prices:
- For **normal operations**: Takes the more conservative price (min for token1, max for token0) to protect against upward manipulation
- For **redemptions**: Takes the opposite (max for token1, min for token0) to prevent value leakage during redemptions
