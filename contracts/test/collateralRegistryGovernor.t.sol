// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestContracts/DevTestSetup.sol";
import "src/CollateralRegistry.sol";
import {GOVERNOR_TRANSFER_TIMELOCK} from "src/Dependencies/Constants.sol";

contract CollateralRegistryGovernorTest is DevTestSetup {
    address internal governor;
    address internal newGovernor;

    function setUp() public override {
        super.setUp();

        governor = makeAddr("GOVERNOR");
        newGovernor = makeAddr("NEW_GOVERNOR");
    }

    function test_proposeGovernor_revertsIfNotGovernor() public {
        vm.prank(newGovernor);
        vm.expectRevert("CollateralRegistry: Only governor can call this function");
        collateralRegistry.proposeGovernor(newGovernor);
    }

    function test_proposeGovernor_revertsIfZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert("CR: Governor cannot be zero address");
        collateralRegistry.proposeGovernor(address(0));
    }

    function test_proposeGovernor_revertsIfAlreadyGovernor() public {
        vm.prank(governor);
        vm.expectRevert("CR: Already governor");
        collateralRegistry.proposeGovernor(governor);
    }

    function test_proposeGovernor_setsPendingStateAndEmits() public {
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit GovernorProposed(newGovernor, block.timestamp + GOVERNOR_TRANSFER_TIMELOCK);
        collateralRegistry.proposeGovernor(newGovernor);

        assertEq(collateralRegistry.pendingGovernor(), newGovernor);
        assertEq(collateralRegistry.pendingGovernorTimestamp(), block.timestamp);
    }

    function test_proposeGovernor_overwritesPreviousProposal() public {
        address anotherGovernor = makeAddr("ANOTHER_GOVERNOR");

        vm.prank(governor);
        collateralRegistry.proposeGovernor(newGovernor);
        assertEq(collateralRegistry.pendingGovernor(), newGovernor);

        vm.prank(governor);
        collateralRegistry.proposeGovernor(anotherGovernor);
        assertEq(collateralRegistry.pendingGovernor(), anotherGovernor);
    }

    function test_acceptGovernor_revertsIfNotPendingGovernor() public {
        vm.prank(governor);
        collateralRegistry.proposeGovernor(newGovernor);
        vm.warp(block.timestamp + GOVERNOR_TRANSFER_TIMELOCK);

        vm.prank(governor);
        vm.expectRevert("CR: Caller is not pending governor");
        collateralRegistry.acceptGovernor();
    }

    function test_acceptGovernor_revertsIfTimelockNotPassed() public {
        vm.prank(governor);
        collateralRegistry.proposeGovernor(newGovernor);

        vm.prank(newGovernor);
        vm.expectRevert("CR: Governor transfer timelock not passed");
        collateralRegistry.acceptGovernor();
    }

    function test_acceptGovernor_revertsIfExactlyAtTimelockBoundary() public {
        vm.prank(governor);
        collateralRegistry.proposeGovernor(newGovernor);
        // Warp to 1 second before timelock ends
        vm.warp(block.timestamp + GOVERNOR_TRANSFER_TIMELOCK - 1);

        vm.prank(newGovernor);
        vm.expectRevert("CR: Governor transfer timelock not passed");
        collateralRegistry.acceptGovernor();
    }

    function test_acceptGovernor_succeedsAfterTimelock() public {
        vm.prank(governor);
        collateralRegistry.proposeGovernor(newGovernor);
        vm.warp(block.timestamp + GOVERNOR_TRANSFER_TIMELOCK);

        vm.prank(newGovernor);
        vm.expectEmit(true, true, true, true);
        emit GovernorUpdated(governor, newGovernor);
        collateralRegistry.acceptGovernor();

        assertEq(CollateralRegistry(address(collateralRegistry)).governor(), newGovernor);
        assertEq(collateralRegistry.pendingGovernor(), address(0));
        assertEq(collateralRegistry.pendingGovernorTimestamp(), 0);
    }

    function test_acceptGovernor_newGovernorCanUseGovernorFunctions() public {
        vm.prank(governor);
        collateralRegistry.proposeGovernor(newGovernor);
        vm.warp(block.timestamp + GOVERNOR_TRANSFER_TIMELOCK);

        vm.prank(newGovernor);
        collateralRegistry.acceptGovernor();

        // New governor can call governor-only functions (e.g. propose another governor)
        address yetAnotherGovernor = makeAddr("YET_ANOTHER");
        vm.prank(newGovernor);
        collateralRegistry.proposeGovernor(yetAnotherGovernor);
        assertEq(collateralRegistry.pendingGovernor(), yetAnotherGovernor);
    }

    function test_cancelGovernorProposal_revertsIfNotGovernor() public {
        vm.prank(governor);
        collateralRegistry.proposeGovernor(newGovernor);

        vm.prank(newGovernor);
        vm.expectRevert("CollateralRegistry: Only governor can call this function");
        collateralRegistry.cancelGovernorProposal();
    }

    function test_cancelGovernorProposal_revertsIfNoPending() public {
        vm.prank(governor);
        vm.expectRevert("CR: No pending governor");
        collateralRegistry.cancelGovernorProposal();
    }

    function test_cancelGovernorProposal_clearsPendingAndEmits() public {
        vm.prank(governor);
        collateralRegistry.proposeGovernor(newGovernor);

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit GovernorProposalCancelled(newGovernor);
        collateralRegistry.cancelGovernorProposal();

        assertEq(collateralRegistry.pendingGovernor(), address(0));
        assertEq(collateralRegistry.pendingGovernorTimestamp(), 0);
        assertEq(CollateralRegistry(address(collateralRegistry)).governor(), governor);
    }

    function test_cancelGovernorProposal_pendingGovernorCannotAcceptAfterCancel() public {
        vm.prank(governor);
        collateralRegistry.proposeGovernor(newGovernor);
        vm.prank(governor);
        collateralRegistry.cancelGovernorProposal();

        vm.warp(block.timestamp + GOVERNOR_TRANSFER_TIMELOCK);
        vm.prank(newGovernor);
        vm.expectRevert("CR: Caller is not pending governor");
        collateralRegistry.acceptGovernor();
    }

    function test_fullFlow_proposeAccept_thenProposeAgain() public {
        // Round 1: governor -> newGovernor
        vm.prank(governor);
        collateralRegistry.proposeGovernor(newGovernor);
        vm.warp(block.timestamp + GOVERNOR_TRANSFER_TIMELOCK);
        vm.prank(newGovernor);
        collateralRegistry.acceptGovernor();

        assertEq(CollateralRegistry(address(collateralRegistry)).governor(), newGovernor);

        // Round 2: newGovernor -> governor (transfer back)
        vm.prank(newGovernor);
        collateralRegistry.proposeGovernor(governor);
        vm.warp(block.timestamp + GOVERNOR_TRANSFER_TIMELOCK);
        vm.prank(governor);
        collateralRegistry.acceptGovernor();

        assertEq(CollateralRegistry(address(collateralRegistry)).governor(), governor);
    }

    // Event declarations for vm.expectEmit (must match contract events)
    event GovernorProposed(address indexed pendingGovernor, uint256 activateAtTimestamp);
    event GovernorProposalCancelled(address indexed cancelledGovernor);
    event GovernorUpdated(address oldGovernor, address newGovernor);
}
