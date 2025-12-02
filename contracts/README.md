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

## AeroManager

The `AeroManager` contract is used to direct and manage AERO token rewards earned from Aerodrome LP positions being used as collateral in the Basedollar protocol.

### AERO Flow

AeroManager is integrated into the system through the `AddressesRegistry` and `ActivePool`. When Aerodrome LP tokens are used as collateral:

1. Each `ActivePool` knows about one Aero gauge for that particular collateral type
2. When LP collateral is received, it is deposited into the associated Aerodrome gauge
3. AERO rewards accrue from the Aerodrome LP positions staked in the gauge
4. The `AeroManager` contract manages these rewards and can interact with Aerodrome gauges to direct reward distribution

The contract maintains references to the `CollateralRegistry` and stores the AERO token address for reward management operations.

### Updates

AeroManager can be updated by the governor through two functions:

- `setAeroTokenAddress(address _aeroTokenAddress)`: Updates the AERO token address used for reward management
- `setGovernor(address _governor)`: Updates the governor address that has permission to make updates

Both functions are protected by the `onlyGovernor` modifier, ensuring only the current governor can modify these critical parameters.
