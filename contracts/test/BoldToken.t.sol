// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TestContracts/DevTestSetup.sol";
import "./TestContracts/BoldTokenTester.sol";

contract BoldTokenTest is DevTestSetup {
    // TODO: need more tests for:
    // - transfer protection
    // - sendToPool() / returnFromPool()

    function test_InfiniteApprovalPersistsAfterTransfer() external {
        uint256 initialBalance_A = 10_000 ether;

        openTroveHelper(A, 0, 100 ether, initialBalance_A, 0.01 ether);
        assertEq(boldToken.balanceOf(A), initialBalance_A, "A's balance is wrong");

        vm.prank(A);
        assertTrue(boldToken.approve(B, UINT256_MAX));
        assertEq(boldToken.allowance(A, B), UINT256_MAX, "Allowance should be infinite");

        uint256 value = 1_000 ether;

        vm.prank(B);
        assertTrue(boldToken.transferFrom(A, C, value));
        assertEq(boldToken.balanceOf(A), initialBalance_A - value, "A's balance should have decreased by value");
        assertEq(boldToken.balanceOf(C), value, "C's balance should have increased by value");
        assertEq(boldToken.allowance(A, B), UINT256_MAX, "Allowance should still be infinite");
    }

    function test_transfer_revertsForInvalidRecipients() external {
        vm.prank(address(activePool));
        boldToken.mint(A, 1 ether);

        vm.prank(A);
        vm.expectRevert("BoldToken: Cannot transfer tokens directly to the Bold token contract or the zero address");
        boldToken.transfer(address(0), 1);

        vm.prank(A);
        vm.expectRevert("BoldToken: Cannot transfer tokens directly to the Bold token contract or the zero address");
        boldToken.transfer(address(boldToken), 1);
    }

    function test_transferFrom_revertsForInvalidRecipient() external {
        vm.prank(address(activePool));
        boldToken.mint(A, 1 ether);

        vm.prank(A);
        boldToken.approve(B, 1 ether);

        vm.prank(B);
        vm.expectRevert("BoldToken: Cannot transfer tokens directly to the Bold token contract or the zero address");
        boldToken.transferFrom(A, address(boldToken), 1);
    }

    function test_mint_allowsBorrowerOperationsAndActivePoolOnly() external {
        vm.prank(address(borrowerOperations));
        boldToken.mint(A, 1 ether);
        assertEq(boldToken.balanceOf(A), 1 ether);

        vm.prank(address(activePool));
        boldToken.mint(A, 2 ether);
        assertEq(boldToken.balanceOf(A), 3 ether);

        vm.prank(A);
        vm.expectRevert("BoldToken: Caller is not BO or AP");
        boldToken.mint(A, 1);
    }

    function test_burn_allowsAuthorizedCoreContractsOnly() external {
        vm.startPrank(address(activePool));
        boldToken.mint(A, 4 ether);
        vm.stopPrank();

        vm.prank(address(collateralRegistry));
        boldToken.burn(A, 1 ether);

        vm.prank(address(borrowerOperations));
        boldToken.burn(A, 1 ether);

        vm.prank(address(troveManager));
        boldToken.burn(A, 1 ether);

        vm.prank(address(stabilityPool));
        boldToken.burn(A, 1 ether);

        assertEq(boldToken.balanceOf(A), 0);

        vm.prank(address(activePool));
        boldToken.mint(A, 1 ether);

        vm.prank(A);
        vm.expectRevert("BoldToken: Caller is neither CR nor BorrowerOperations nor TroveManager nor StabilityPool");
        boldToken.burn(A, 1);
    }

    function test_sendToPoolAndReturnFromPool_allowOnlyStabilityPool() external {
        vm.prank(address(activePool));
        boldToken.mint(A, 2 ether);

        vm.prank(A);
        vm.expectRevert("BoldToken: Caller is not the StabilityPool");
        boldToken.sendToPool(A, address(stabilityPool), 1 ether);

        vm.prank(address(stabilityPool));
        boldToken.sendToPool(A, address(stabilityPool), 1 ether);
        assertEq(boldToken.balanceOf(A), 1 ether);
        assertEq(boldToken.balanceOf(address(stabilityPool)), 1 ether);

        vm.prank(A);
        vm.expectRevert("BoldToken: Caller is not the StabilityPool");
        boldToken.returnFromPool(address(stabilityPool), A, 1 ether);

        vm.prank(address(stabilityPool));
        boldToken.returnFromPool(address(stabilityPool), A, 1 ether);
        assertEq(boldToken.balanceOf(A), 2 ether);
        assertEq(boldToken.balanceOf(address(stabilityPool)), 0);
    }

    function test_setBranchAddressesViaCollateralRegistry_guardsCallerAndDuplicates() external {
        BoldTokenTester token = new BoldTokenTester(address(this));
        address registry = makeAddr("registry");

        vm.expectRevert("BoldToken: Caller is not the CollateralRegistry");
        token.setBranchAddressesViaCollateralRegistry(address(1), address(2), address(3), address(4));

        token.setCollateralRegistry(registry);

        vm.prank(registry);
        token.setBranchAddressesViaCollateralRegistry(address(1), address(2), address(3), address(4));

        vm.prank(registry);
        vm.expectRevert("BoldToken: TroveManager address already set");
        token.setBranchAddressesViaCollateralRegistry(address(1), address(5), address(6), address(7));

        vm.prank(registry);
        vm.expectRevert("BoldToken: StabilityPool address already set");
        token.setBranchAddressesViaCollateralRegistry(address(5), address(2), address(6), address(7));

        vm.prank(registry);
        vm.expectRevert("BoldToken: BorrowerOperations address already set");
        token.setBranchAddressesViaCollateralRegistry(address(5), address(6), address(3), address(7));

        vm.prank(registry);
        vm.expectRevert("BoldToken: ActivePool address already set");
        token.setBranchAddressesViaCollateralRegistry(address(5), address(6), address(7), address(4));
    }
}
