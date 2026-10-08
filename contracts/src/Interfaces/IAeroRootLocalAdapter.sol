/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @title IAeroRootLocalAdapter
 * @notice Interface for the local adapter deployed on root that connects the `RootMessageOrchestrator` and the
 * on-root `LeafMessageOrchestrator` in the same transaction.
 */
interface IAeroRootLocalAdapter {
  /// @notice Thrown when both orchestrator addresses passed to the constructor are identical.
  error IdenticalOrchestrators();

  /// @notice Thrown when `sendMessage` is invoked with non-zero `msg.value` on an adapter that carries no transport fee.
  error NoFeeRequired();

  /// @notice Thrown when an `IMessageAdapter` entrypoint with no semantic on this adapter is invoked (`handle` and
  /// `setRemoteAdapter` — the local adapter has no underlying transport and no remote counterpart).
  error NotSupported();

  /**
   * @notice Address of the `RootMessageOrchestrator` bound to this adapter at deployment.
   * @return _rootMessageOrchestrator Address of the `RootMessageOrchestrator`.
   */
  function ROOT_MESSAGE_ORCHESTRATOR() external view returns (address _rootMessageOrchestrator);

  /**
   * @notice Address of the on-root `LeafMessageOrchestrator` bound to this adapter at deployment.
   * @return _leafMessageOrchestrator Address of the on-root `LeafMessageOrchestrator`.
   */
  function LEAF_MESSAGE_ORCHESTRATOR() external view returns (address _leafMessageOrchestrator);
}
