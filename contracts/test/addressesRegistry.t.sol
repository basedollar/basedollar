// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import "src/AddressesRegistry.sol";

contract AddressesRegistryTest is Test {
    address internal owner = address(this);

    function _deploy(
        uint256 ccr,
        uint256 mcr,
        uint256 bcr,
        uint256 scr,
        uint256 spPenalty,
        uint256 redistPenalty
    ) internal returns (AddressesRegistry) {
        return new AddressesRegistry(owner, ccr, mcr, bcr, scr, 100_000_000 ether, spPenalty, redistPenalty);
    }

    function test_constructor_acceptsValidParameters() external {
        AddressesRegistry registry = _deploy(150e16, 110e16, 10e16, 110e16, 5e16, 10e16);

        assertEq(registry.CCR(), 150e16);
        assertEq(registry.MCR(), 110e16);
        assertEq(registry.BCR(), 10e16);
        assertEq(registry.SCR(), 110e16);
        assertEq(registry.LIQUIDATION_PENALTY_SP(), 5e16);
        assertEq(registry.LIQUIDATION_PENALTY_REDISTRIBUTION(), 10e16);
    }

    function test_constructor_revertsWhenCCRInvalid() external {
        vm.expectRevert(AddressesRegistry.InvalidCCR.selector);
        _deploy(100e16, 110e16, 10e16, 110e16, 5e16, 10e16);
    }

    function test_constructor_revertsWhenMCRInvalid() external {
        vm.expectRevert(AddressesRegistry.InvalidMCR.selector);
        _deploy(150e16, 99e16, 10e16, 110e16, 5e16, 10e16);
    }

    function test_constructor_revertsWhenBCRInvalid() external {
        vm.expectRevert(AddressesRegistry.InvalidBCR.selector);
        _deploy(150e16, 110e16, 4e16, 110e16, 5e16, 10e16);
    }

    function test_constructor_revertsWhenSCRInvalid() external {
        vm.expectRevert(AddressesRegistry.InvalidSCR.selector);
        _deploy(150e16, 110e16, 10e16, 100e16, 5e16, 10e16);
    }

    function test_constructor_revertsWhenSPPenaltyTooLow() external {
        vm.expectRevert(AddressesRegistry.SPPenaltyTooLow.selector);
        _deploy(150e16, 110e16, 10e16, 110e16, 5e16 - 1, 10e16);
    }

    function test_constructor_revertsWhenSPPenaltyGreaterThanRedistPenalty() external {
        vm.expectRevert(AddressesRegistry.SPPenaltyGtRedist.selector);
        _deploy(150e16, 110e16, 10e16, 110e16, 11e16, 10e16);
    }

    function test_constructor_revertsWhenRedistPenaltyTooHigh() external {
        vm.expectRevert(AddressesRegistry.RedistPenaltyTooHigh.selector);
        _deploy(150e16, 110e16, 10e16, 110e16, 5e16, 20e16 + 1);
    }
}
