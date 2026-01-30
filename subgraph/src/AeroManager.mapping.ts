import {
  AeroDistributed as AeroDistributedEvent,
  Claimed as ClaimedEvent,
  Staked as StakedEvent,
} from "../generated/templates/AeroManager/AeroManager";
import { AeroClaim, AeroDistribution, AeroGauge, AeroStake } from "../generated/schema";

function eventId(txHash: string, logIndex: string): string {
  return txHash + ":" + logIndex;
}

export function handleStaked(event: StakedEvent): void {
  // The AeroManager event does not include branch info.
  // The staking call comes from the branch's ActivePool, which is the tx sender.
  let activePool = event.transaction.from;
  let gauge = AeroGauge.load(event.params.gauge.toHexString());
  if (!gauge) {
    return;
  }

  let id = eventId(event.transaction.hash.toHexString(), event.logIndex.toString());
  let stake = new AeroStake(id);
  stake.collateral = gauge.collateral;
  stake.activePool = activePool;
  stake.gauge = event.params.gauge;
  stake.token = event.params.token;
  stake.amount = event.params.amount;
  stake.blockNumber = event.block.number;
  stake.timestamp = event.block.timestamp;
  stake.transactionHash = event.transaction.hash;
  stake.save();
}

export function handleClaimed(event: ClaimedEvent): void {
  let activePool = event.transaction.from;
  let gauge = AeroGauge.load(event.params.gauge.toHexString());
  if (!gauge) {
    return;
  }

  let id = eventId(event.transaction.hash.toHexString(), event.logIndex.toString());
  let claim = new AeroClaim(id);
  claim.collateral = gauge.collateral;
  claim.activePool = activePool;
  claim.gauge = event.params.gauge;
  claim.total = event.params.total;
  claim.claimFee = event.params.claimFee;
  claim.epoch = event.params.epoch;
  claim.blockNumber = event.block.number;
  claim.timestamp = event.block.timestamp;
  claim.transactionHash = event.transaction.hash;
  claim.save();
}

export function handleAeroDistributed(event: AeroDistributedEvent): void {
  let gauge = AeroGauge.load(event.params.gauge.toHexString());
  if (!gauge) {
    return;
  }

  let id = eventId(event.transaction.hash.toHexString(), event.logIndex.toString());
  let distribution = new AeroDistribution(id);
  distribution.collateral = gauge.collateral;
  distribution.gauge = event.params.gauge;
  distribution.recipients = event.params.recipients;
  distribution.totalRewardAmount = event.params.totalRewardAmount;
  distribution.epoch = event.params.epoch;
  distribution.blockNumber = event.block.number;
  distribution.timestamp = event.block.timestamp;
  distribution.transactionHash = event.transaction.hash;
  distribution.save();
}

