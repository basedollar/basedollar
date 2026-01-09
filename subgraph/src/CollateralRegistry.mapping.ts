import { dataSource } from "@graphprotocol/graph-ts";
import { CollateralBranchAdded as CollateralBranchAddedEvent } from "../generated/templates/CollateralRegistry/CollateralRegistry";
import { ensureCollateralBranch } from "./shared/collateral";

export function handleCollateralBranchAdded(event: CollateralBranchAddedEvent): void {
  // Expect single CollateralRegistry, stored in this data source's context.
  let registryAddress = dataSource.context().getBytes("address:collateralRegistry");

  let isRedeemable = event.params._isRedeemable;

  ensureCollateralBranch({
    collIndex: event.params._index.toI32(),
    totalCollaterals: event.params._totalCollaterals.toI32(),
    tokenAddress: event.params._token,
    troveManagerAddress: event.params._troveManager,
    isRedeemable,
    collateralRegistryAddress: registryAddress,
  });
}

