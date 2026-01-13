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
export function addCollateralBranch(
  collIndex: i32,
  totalCollaterals: i32,
  tokenAddress: Address,
  troveManagerAddress: Address,
  isRedeemable: boolean,
): void {
  let collId = getCollateralId(collIndex, isRedeemable);

  // Collateral is immutable in the schema: only create if missing.
  let existing = Collateral.load(collId);
  if (existing) return;

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
  
  // minCollRatio derived from BorrowerOperations.MCR()
  collateral.minCollRatio = BorrowerOperationsContract.bind(
    Address.fromBytes(addresses.borrowerOperations),
  ).MCR();
  
  // ActivePool drives Aero LP collateral flag and also lets us discover AeroManager.
  let activePoolContract = ActivePoolContract.bind(Address.fromBytes(addresses.activePool));
  collateral.isAeroLPCollateral = activePoolContract.isAeroLPCollateral();
  let aeroGaugeAddress = activePoolContract.aeroGaugeAddress();
  if (aeroGaugeAddress.notEqual(Address.zero())) {
    addresses.aeroGauge = aeroGaugeAddress;
  }

  collateral.save();
  addresses.save();

  if (aeroGaugeAddress.notEqual(Address.zero())) {
    let gauge = new AeroGauge(aeroGaugeAddress.toHexString());
    gauge.collateral = collId;
    gauge.gauge = aeroGaugeAddress;
    gauge.token = addresses.token;
    gauge.activePool = addresses.activePool;
    gauge.aeroManager = activePoolContract.aeroManagerAddress();
    gauge.save();
  }

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
  if (aeroGaugeAddress.notEqual(Address.zero())) {
    context.setBytes("address:aeroGauge", aeroGaugeAddress);
  }
  context.setBytes("address:token", addresses.token);
  context.setBytes("address:troveManager", addresses.troveManager);
  context.setBytes("address:troveNft", addresses.troveNft);
  context.setString("collId", collId);
  context.setString("collType", getCollateralType(isRedeemable));
  context.setI32("collIndex", collIndex);
  context.setI32("totalCollaterals", totalCollaterals);

  TroveManagerTemplate.createWithContext(troveManagerAddress, context);
  TroveNFTTemplate.createWithContext(Address.fromBytes(addresses.troveNft), context);
}

