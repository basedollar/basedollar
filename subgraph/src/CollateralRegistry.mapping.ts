import { CollateralBranchAdded as CollateralBranchAddedEvent } from "../generated/templates/CollateralRegistry/CollateralRegistry";
import { addCollateralBranch } from "./shared/collateral";

export function handleCollateralBranchAdded(event: CollateralBranchAddedEvent): void {
  let isRedeemable = event.params._isRedeemable;

  addCollateralBranch(
    event.params._index.toI32(),
    event.params._totalCollaterals.toI32(),
    event.params._token,
    event.params._troveManager,
    isRedeemable,
  );
}

