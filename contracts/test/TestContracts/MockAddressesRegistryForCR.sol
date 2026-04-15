// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "src/Interfaces/IAddressesRegistry.sol";
import "src/Interfaces/IWETH.sol";

/// @dev Minimal `IAddressesRegistry` for `CollateralRegistry.createNewBranch` validation tests.
contract MockAddressesRegistryForCR is IAddressesRegistry {
    IERC20Metadata internal _collToken;
    ITroveManager internal _troveManager;
    IStabilityPool internal _stabilityPool;
    IBorrowerOperations internal _borrowerOperations;
    IActivePool internal _activePool;

    function configure(
        IERC20Metadata collToken_,
        ITroveManager troveManager_,
        IStabilityPool stabilityPool_,
        IBorrowerOperations borrowerOperations_,
        IActivePool activePool_
    ) external {
        _collToken = collToken_;
        _troveManager = troveManager_;
        _stabilityPool = stabilityPool_;
        _borrowerOperations = borrowerOperations_;
        _activePool = activePool_;
    }

    function collToken() external view override returns (IERC20Metadata) {
        return _collToken;
    }

    function troveManager() external view override returns (ITroveManager) {
        return _troveManager;
    }

    function stabilityPool() external view override returns (IStabilityPool) {
        return _stabilityPool;
    }

    function borrowerOperations() external view override returns (IBorrowerOperations) {
        return _borrowerOperations;
    }

    function activePool() external view override returns (IActivePool) {
        return _activePool;
    }

    function CCR() external pure override returns (uint256) {
        return 15e17;
    }

    function SCR() external pure override returns (uint256) {
        return 13e17;
    }

    function MCR() external pure override returns (uint256) {
        return 11e17;
    }

    function BCR() external pure override returns (uint256) {
        return 10e17;
    }

    function LIQUIDATION_PENALTY_SP() external pure override returns (uint256) {
        return 5e16;
    }

    function LIQUIDATION_PENALTY_REDISTRIBUTION() external pure override returns (uint256) {
        return 10e16;
    }

    function troveNFT() external view override returns (ITroveNFT) {
        return ITroveNFT(address(0x1));
    }

    function metadataNFT() external view override returns (IMetadataNFT) {
        return IMetadataNFT(address(0x1));
    }

    function priceFeed() external view override returns (IPriceFeed) {
        return IPriceFeed(address(0x1));
    }

    function defaultPool() external view override returns (IDefaultPool) {
        return IDefaultPool(address(0x1));
    }

    function gasPoolAddress() external pure override returns (address) {
        return address(0x1);
    }

    function collSurplusPool() external view override returns (ICollSurplusPool) {
        return ICollSurplusPool(address(0x1));
    }

    function sortedTroves() external view override returns (ISortedTroves) {
        return ISortedTroves(address(0x1));
    }

    function interestRouter() external view override returns (IInterestRouter) {
        return IInterestRouter(address(0x1));
    }

    function hintHelpers() external view override returns (IHintHelpers) {
        return IHintHelpers(address(0x1));
    }

    function multiTroveGetter() external view override returns (IMultiTroveGetter) {
        return IMultiTroveGetter(address(0x1));
    }

    function collateralRegistry() external view override returns (ICollateralRegistry) {
        return ICollateralRegistry(address(0x1));
    }

    function boldToken() external view override returns (IBoldToken) {
        return IBoldToken(address(0x1));
    }

    function WETH() external view override returns (IWETH) {
        return IWETH(address(0x1));
    }

    function debtLimit() external pure override returns (uint256) {
        return type(uint256).max;
    }

    function aeroManager() external view override returns (IAeroManager) {
        return IAeroManager(address(0x1));
    }

    function setAddresses(AddressVars memory) external override {}
}
