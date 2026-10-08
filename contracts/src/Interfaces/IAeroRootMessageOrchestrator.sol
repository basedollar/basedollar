/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IAeroMessageAdapter} from './IAeroMessageAdapter.sol';

/**
 * @title IAeroRootMessageOrchestrator
 * @notice Root-side orchestrator: sends outbound messages from the local `Voter` to many leaves and routes inbound
 * `Redeem` and `Deallocate` messages back to it.
 */
interface IAeroRootMessageOrchestrator {
  /// @notice Local `Voter` bound to this orchestrator at deployment.
  /// @dev The only caller allowed to `dispatch`. It owns the chain registry and the roles checked here; the
  ///      orchestrator holds none.
  /// @return Local `Voter`.
  function VOTER() external view returns (IVoter);

  /// @notice Registered transport adapter for a destination chain, or zero if none.
  /// @param _chainId Destination chain id.
  /// @return Registered adapter for `_chainId`.
  function adapters(uint256 _chainId) external view returns (IAeroMessageAdapter);

  /// @notice Native amount kept per dispatch that carries a deallocation return, covering the gas the leaf fronts.
  /// @param _chainId Destination chain id.
  /// @return _cost Configured cost for `_chainId`.
  function deallocationReturnCost(uint256 _chainId) external view returns (uint256 _cost);

  /// @notice Last outbound nonce stamped on a dispatch to a destination chain.
  /// @param _chainId Destination chain id.
  /// @return _lastNonce Last outbound nonce for `_chainId`.
  function nonceOut(uint256 _chainId) external view returns (uint256 _lastNonce);

  /// @notice Whether an inbound nonce has already been consumed for a source chain.
  /// @dev Single-use replay gate: a nonce that reads true makes `route` revert `NonceAlreadyUsed`.
  /// @param _chainId Source chain id.
  /// @param _nonce Inbound nonce to check.
  /// @return _isUsed Whether `_nonce` has been consumed for `_chainId`.
  function noncesUsed(uint256 _chainId, uint256 _nonce) external view returns (bool _isUsed);
}

interface IVoter {
    function MINTER() external view returns (IMinter);
}

interface IMinter {
    function TOKEN() external view returns (address);
}