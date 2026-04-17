// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {AeroGaugeTester} from "./AeroGaugeTester.sol";
import {AeroManager} from "src/AeroManager.sol";
import {IActivePool} from "src/Interfaces/IActivePool.sol";
import {IWETH} from "src/Interfaces/IWETH.sol";

/// @notice Randomized calls for invariant runs: kill/revive gauge (via mock Voter), stake, withdraw.
/// @dev All mutations use `vm.prank`/`deal` so the handler never reverts on valid bounds (`fail_on_revert = true`).
contract AeroManagerGaugeLifecycleHandler is Test {
    IWETH public weth;
    AeroGaugeTester public gauge;
    AeroManager public aeroManager;
    IActivePool public activePool;
    address public borrowerOperations;
    address public withdrawRecipient;

    uint256 public constant MAX_STAKE = 500_000e18;

    constructor(
        IWETH _weth,
        AeroGaugeTester _gauge,
        AeroManager _aeroManager,
        IActivePool _activePool,
        address _borrowerOperations,
        address _withdrawRecipient
    ) {
        weth = _weth;
        gauge = _gauge;
        aeroManager = _aeroManager;
        activePool = _activePool;
        borrowerOperations = _borrowerOperations;
        withdrawRecipient = _withdrawRecipient;
    }

    function killGauge() external {
        gauge.aeroVoter().setGaugeAlive(address(gauge), false);
    }

    function reviveGauge() external {
        gauge.aeroVoter().setGaugeAlive(address(gauge), true);
    }

    function stake(uint256 amountSeed) external {
        uint256 amt = bound(amountSeed, 1, MAX_STAKE);
        deal(address(weth), borrowerOperations, amt);
        vm.startPrank(borrowerOperations);
        IERC20(address(weth)).transfer(address(activePool), amt);
        activePool.accountForReceivedColl(amt);
        vm.stopPrank();
    }

    function withdraw(uint256 amountSeed) external {
        uint256 bal = activePool.getCollBalance();
        if (bal == 0) return;
        uint256 amt = bound(amountSeed, 1, bal);
        vm.prank(borrowerOperations);
        activePool.sendColl(withdrawRecipient, amt);
    }
}
