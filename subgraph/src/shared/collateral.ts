import { Address, DataSourceContext } from "@graphprotocol/graph-ts";
import { ActivePool as ActivePoolContract } from "../../generated/BoldToken/ActivePool";
import { BorrowerOperations as BorrowerOperationsContract } from "../../generated/BoldToken/BorrowerOperations";
import { TroveManager as TroveManagerContract } from "../../generated/BoldToken/TroveManager";
import { AeroGauge, Collateral, CollateralAddresses } from "../../generated/schema";
import { AeroManager as AeroManagerTemplate, TroveManager as TroveManagerTemplate, TroveNFT as TroveNFTTemplate } from "../../generated/templates";

export function getCollateralType(isRedeemable: boolean): string {
  return isRedeemable ? "r" : "n"; // "r" or "n"
}

export function getCollateralId(collIndex: i32, isRedeemable: boolean): string {
  return getCollateralType(isRedeemable) + ":" + collIndex.toString(); // "r:0" or "n:0"
}

/**
 * Create Collateral + CollateralAddresses and template data sources
 * for a given branch.
 *
 * AeroManager is expected to be a single instance, created once elsewhere.
 */
export function ensureCollateralBranch(params: {
  collIndex: i32;
  totalCollaterals: i32;
  tokenAddress: Address;
  troveManagerAddress: Address;
  isRedeemable: boolean;
  collateralRegistryAddress: Address;
}): void {
  let collId = getCollateralId(params.collIndex, params.isRedeemable);

  let collateral = new Collateral(collId);
  collateral.collIndex = params.collIndex;
  collateral.redeemable = params.isRedeemable;

  let troveManagerContract = TroveManagerContract.bind(params.troveManagerAddress);

  let addresses = new CollateralAddresses(collId);
  addresses.collateral = collId;
  addresses.borrowerOperations = troveManagerContract.borrowerOperations();
  addresses.sortedTroves = troveManagerContract.sortedTroves();
  addresses.stabilityPool = troveManagerContract.stabilityPool();
  addresses.activePool = troveManagerContract.activePool();
  addresses.token = params.tokenAddress;
  addresses.troveManager = params.troveManagerAddress;
  addresses.troveNft = troveManagerContract.troveNFT();
  
  // minCollRatio derived from BorrowerOperations.MCR()
  collateral.minCollRatio = BorrowerOperationsContract.bind(
    Address.fromBytes(addresses.borrowerOperations),
  ).MCR();
  
  // ActivePool drives Aero LP collateral flag and also lets us discover AeroManager.
  let activePoolContract = ActivePoolContract.bind(Address.fromBytes(addresses.activePool));
  collateral.isAeroLPCollateral = activePoolContract.isAeroLPCollateral();
  addresses.aeroGauge = activePoolContract.aeroGaugeAddress();

  collateral.save();
  addresses.save();

  let gauge = new AeroGauge(addresses.aeroGauge.toHexString());
  gauge.collateral = collId;
  gauge.gauge = addresses.aeroGauge;
  gauge.token = addresses.token;
  gauge.activePool = addresses.activePool;
  gauge.aeroManager = activePoolContract.aeroManagerAddress();
  gauge.save();

  // Lazily create single AeroManager template instance.
  let aeroManagerAddress = activePoolContract.aeroManagerAddress();
  if (aeroManagerAddress.notEqual(Address.zero())) {
    AeroManagerTemplate.create(aeroManagerAddress);
  }

  // Create TroveManager + TroveNFT templates with context.
  let context = new DataSourceContext();
  context.setBytes("address:borrowerOperations", addresses.borrowerOperations);
  context.setBytes("address:sortedTroves", addresses.sortedTroves);
  context.setBytes("address:stabilityPool", addresses.stabilityPool);
  context.setBytes("address:activePool", addresses.activePool);
  context.setBytes("address:aeroGauge", addresses.aeroGauge);
  context.setBytes("address:token", addresses.token);
  context.setBytes("address:troveManager", addresses.troveManager);
  context.setBytes("address:troveNft", addresses.troveNft);
  context.setString("collId", collId);
  context.setString("collType", getCollateralType(params.isRedeemable));
  context.setI32("collIndex", params.collIndex);
  context.setI32("totalCollaterals", params.totalCollaterals);

  TroveManagerTemplate.createWithContext(params.troveManagerAddress, context);
  TroveNFTTemplate.createWithContext(Address.fromBytes(addresses.troveNft), context);
}

