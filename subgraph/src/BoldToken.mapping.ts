import { Address, BigInt, DataSourceContext } from "@graphprotocol/graph-ts";
import {
  CollateralRegistryAddressChanged as CollateralRegistryAddressChangedEvent,
} from "../generated/BoldToken/BoldToken";
import { ActivePool as ActivePoolContract } from "../generated/BoldToken/ActivePool";
import { BorrowerOperations as BorrowerOperationsContract } from "../generated/BoldToken/BorrowerOperations";
import { CollateralRegistry as CollateralRegistryContract } from "../generated/BoldToken/CollateralRegistry";
import { TroveManager as TroveManagerContract } from "../generated/BoldToken/TroveManager";
import { Collateral, CollateralAddresses } from "../generated/schema";
import {
  AeroManager as AeroManagerTemplate,
  TroveManager as TroveManagerTemplate,
  TroveNFT as TroveNFTTemplate,
} from "../generated/templates";

function addCollateral(
  collIndex: i32,
  totalCollaterals: i32,
  tokenAddress: Address,
  troveManagerAddress: Address,
  isRedeemable: boolean,
): void {
  let collId = collIndex.toString();

  let collateral = new Collateral(collId);
  collateral.collIndex = collIndex;
  collateral.redeemable = isRedeemable;

  let troveManagerContract = TroveManagerContract.bind(troveManagerAddress);

  let addresses = new CollateralAddresses(collId);
  addresses.collateral = collId;
  addresses.borrowerOperations = troveManagerContract.borrowerOperations();
  addresses.sortedTroves = troveManagerContract.sortedTroves();
  addresses.stabilityPool = troveManagerContract.stabilityPool();
  addresses.activePool = troveManagerContract.activePool();
  addresses.token = tokenAddress;
  addresses.troveManager = troveManagerAddress;
  addresses.troveNft = troveManagerContract.troveNFT();

  // Dynamically create an AeroManager data source from the ActivePool's configured AeroManager.
  // This avoids hardcoding the AeroManager address in subgraph.yaml/network files.
  let aeroManagerAddress = ActivePoolContract.bind(Address.fromBytes(addresses.activePool)).aeroManagerAddress();
  if (aeroManagerAddress.notEqual(Address.zero())) {
    AeroManagerTemplate.create(aeroManagerAddress);
  }

  collateral.minCollRatio = BorrowerOperationsContract.bind(
    Address.fromBytes(addresses.borrowerOperations),
  ).MCR();

  collateral.save();
  addresses.save();

  let context = new DataSourceContext();
  context.setBytes("address:borrowerOperations", addresses.borrowerOperations);
  context.setBytes("address:sortedTroves", addresses.sortedTroves);
  context.setBytes("address:stabilityPool", addresses.stabilityPool);
  context.setBytes("address:token", addresses.token);
  context.setBytes("address:troveManager", addresses.troveManager);
  context.setBytes("address:troveNft", addresses.troveNft);
  context.setString("collId", collId);
  context.setI32("collIndex", collIndex);
  context.setI32("totalCollaterals", totalCollaterals);

  TroveManagerTemplate.createWithContext(troveManagerAddress, context);
  TroveNFTTemplate.createWithContext(Address.fromBytes(addresses.troveNft), context);
}

export function handleCollateralRegistryAddressChanged(event: CollateralRegistryAddressChangedEvent): void {
  let registry = CollateralRegistryContract.bind(event.params._newCollateralRegistryAddress);
  let totalCollaterals = registry.totalCollaterals().toI32();

  for (let index = 0; index < totalCollaterals; index++) {
    // Handle redeemable branches
    try {
      let tokenAddress = Address.fromBytes(registry.getToken(BigInt.fromI32(index)));
      let troveManagerAddress = Address.fromBytes(registry.getTroveManager(BigInt.fromI32(index)));
  
      addCollateral(
        index,
        totalCollaterals,
        tokenAddress,
        troveManagerAddress,
        true,
      );
    } catch {
      continue;
    }

    // Handle non-redeemable branches
    try {
      let tokenAddress = Address.fromBytes(registry.getNonRedeemableToken(BigInt.fromI32(index)));
      let troveManagerAddress = Address.fromBytes(registry.getNonRedeemableTroveManager(BigInt.fromI32(index)));
  
      addCollateral(
        index,
        totalCollaterals,
        tokenAddress,
        troveManagerAddress,
        false,
      );
    } catch {
      continue;
    }
  }
}
