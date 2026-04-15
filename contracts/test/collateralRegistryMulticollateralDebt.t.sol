// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./multicollateral.t.sol";

contract CollateralRegistryMulticollateralDebtTest is MulticollateralTest {
    address internal govAddr = makeAddr("GOVERNOR");

    function test_updateDebtLimit_decrease_succeeds() public {
        uint256 before = contractsArray[0].troveManager.getDebtLimit();
        vm.prank(govAddr);
        collateralRegistry.updateDebtLimit(0, before / 2);
        assertEq(contractsArray[0].troveManager.getDebtLimit(), before / 2);
    }

    function test_updateDebtLimit_increaseBeyond2xAndAboveInitial_reverts() public {
        vm.startPrank(govAddr);
        collateralRegistry.updateDebtLimit(0, 40_000_000 ether);
        vm.expectRevert("CollateralRegistry: Debt limit increase by more than 2x is not allowed");
        collateralRegistry.updateDebtLimit(0, 150_000_000 ether);
        vm.stopPrank();
    }

    function test_updateDebtLimit_increaseWithin2x_succeeds() public {
        vm.startPrank(govAddr);
        collateralRegistry.updateDebtLimit(0, 40_000_000 ether);
        collateralRegistry.updateDebtLimit(0, 75_000_000 ether);
        vm.stopPrank();
        assertEq(contractsArray[0].troveManager.getDebtLimit(), 75_000_000 ether);
    }

    function test_getDebtLimit_viewMatchesBranch() public {
        assertEq(collateralRegistry.getDebtLimit(0), contractsArray[0].troveManager.getDebtLimit());
    }
}
