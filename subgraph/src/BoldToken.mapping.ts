import { Address, BigInt, DataSourceContext } from "@graphprotocol/graph-ts";
import {
  CollateralRegistryAddressChanged as CollateralRegistryAddressChangedEvent,
} from "../generated/BoldToken/BoldToken";
// import { ActivePool as ActivePoolContract } from "../generated/BoldToken/ActivePool";
// import { BorrowerOperations as BorrowerOperationsContract } from "../generated/BoldToken/BorrowerOperations";
import { CollateralRegistry as CollateralRegistryContract } from "../generated/BoldToken/CollateralRegistry";
// import { TroveManager as TroveManagerContract } from "../generated/BoldToken/TroveManager";
// import { Collateral, CollateralAddresses } from "../generated/schema";
import {
  // AeroManager as AeroManagerTemplate,
  // TroveManager as TroveManagerTemplate,
  // TroveNFT as TroveNFTTemplate,
  CollateralRegistry as CollateralRegistryTemplate,
} from "../generated/templates";
import { addCollateralBranch } from "./shared/collateral";

// function addCollateral(
//   collIndex: i32,
//   totalCollaterals: i32,
//   tokenAddress: Address,
//   troveManagerAddress: Address,
//   isRedeemable: boolean,
// ): void {
//   let collId = collIndex.toString();

//   let collateral = new Collateral(collId);
//   collateral.collIndex = collIndex;
//   collateral.redeemable = isRedeemable;

//   let troveManagerContract = TroveManagerContract.bind(troveManagerAddress);

//   let addresses = new CollateralAddresses(collId);
//   addresses.collateral = collId;
//   addresses.borrowerOperations = troveManagerContract.borrowerOperations();
//   addresses.sortedTroves = troveManagerContract.sortedTroves();
//   addresses.stabilityPool = troveManagerContract.stabilityPool();
//   addresses.activePool = troveManagerContract.activePool();
//   addresses.token = tokenAddress;
//   addresses.troveManager = troveManagerAddress;
//   addresses.troveNft = troveManagerContract.troveNFT();

//   // Dynamically create an AeroManager data source from the ActivePool's configured AeroManager.
//   // This avoids hardcoding the AeroManager address in subgraph.yaml/network files.
//   let aeroManagerAddress = ActivePoolContract.bind(Address.fromBytes(addresses.activePool)).aeroManagerAddress();
//   if (aeroManagerAddress.notEqual(Address.zero())) {
//     AeroManagerTemplate.create(aeroManagerAddress);
//   }

//   collateral.minCollRatio = BorrowerOperationsContract.bind(
//     Address.fromBytes(addresses.borrowerOperations),
//   ).MCR();

//   collateral.save();
//   addresses.save();

//   let context = new DataSourceContext();
//   context.setBytes("address:borrowerOperations", addresses.borrowerOperations);
//   context.setBytes("address:sortedTroves", addresses.sortedTroves);
//   context.setBytes("address:stabilityPool", addresses.stabilityPool);
//   context.setBytes("address:token", addresses.token);
//   context.setBytes("address:troveManager", addresses.troveManager);
//   context.setBytes("address:troveNft", addresses.troveNft);
//   context.setString("collId", collId);
//   context.setI32("collIndex", collIndex);
//   context.setI32("totalCollaterals", totalCollaterals);

//   TroveManagerTemplate.createWithContext(troveManagerAddress, context);
//   TroveNFTTemplate.createWithContext(Address.fromBytes(addresses.troveNft), context);
// }

export function handleCollateralRegistryAddressChanged(event: CollateralRegistryAddressChangedEvent): void {
  let registry = CollateralRegistryContract.bind(event.params._newCollateralRegistryAddress);
  let totalCollaterals: i32 = registry.totalCollaterals().toI32();

  // Create CollateralRegistry template
  let context = new DataSourceContext();
  context.setBytes("address:collateralRegistry", event.params._newCollateralRegistryAddress);
  CollateralRegistryTemplate.createWithContext(event.params._newCollateralRegistryAddress, context);

  // NOTE: AssemblyScript in The Graph does not support try/catch (exceptions).
  // Use `try_` contract calls to safely probe branch arrays.

  // Redeemable branches: probe [0..] until calls revert.
  for (let index = 0; index < totalCollaterals; index++) {
    let i = BigInt.fromI32(index);
    let tokenRes = registry.try_getToken(i);
    let tmRes = registry.try_getTroveManager(i);
    if (tokenRes.reverted || tmRes.reverted) break;

    addCollateralBranch(
      index,
      totalCollaterals,
      Address.fromBytes(tokenRes.value),
      Address.fromBytes(tmRes.value),
      true,
    );
  }

  // Non-redeemable branches: probe [0..] until calls revert.
  for (let index = 0; index < totalCollaterals; index++) {
    let i = BigInt.fromI32(index);
    let tokenRes = registry.try_getNonRedeemableToken(i);
    let tmRes = registry.try_getNonRedeemableTroveManager(i);
    if (tokenRes.reverted || tmRes.reverted) break;

    addCollateralBranch(
      index,
      totalCollaterals,
      Address.fromBytes(tokenRes.value),
      Address.fromBytes(tmRes.value),
      false,
    );
  }
}
