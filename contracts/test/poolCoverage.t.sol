// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TestContracts/DevTestSetup.sol";

contract PoolCoverageTest is DevTestSetup {
    function test_defaultPool_receiveColl_revertsWhenCallerIsNotActivePool() external {
        vm.expectRevert("DefaultPool: Caller is not the ActivePool");
        defaultPool.receiveColl(1);
    }

    function test_defaultPool_sendCollToActivePool_revertsWhenCallerIsNotTroveManager() external {
        vm.expectRevert("DefaultPool: Caller is not the TroveManager");
        defaultPool.sendCollToActivePool(1);
    }

    function test_collSurplusPool_accountSurplus_revertsWhenCallerIsNotTroveManager() external {
        vm.expectRevert("CollSurplusPool: Caller is not TroveManager");
        collSurplusPool.accountSurplus(A, 1);
    }

    function test_collSurplusPool_claimColl_revertsWhenCallerIsNotBorrowerOperations() external {
        vm.prank(address(troveManager));
        collSurplusPool.accountSurplus(A, 1 ether);

        vm.prank(A);
        vm.expectRevert("CollSurplusPool: Caller is not Borrower Operations");
        collSurplusPool.claimColl(A);
    }
}
