// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {AeroManager} from "src/AeroManager.sol";
import {IActivePool} from "src/Interfaces/IActivePool.sol";
import {IWETH} from "src/Interfaces/IWETH.sol";

import {TestDeployer} from "./TestContracts/Deployment.t.sol";
import {Accounts, TestAccounts} from "./TestContracts/Accounts.sol";
import {AeroGaugeTester, MockAeroToken} from "./TestContracts/AeroGaugeTester.sol";
import {WETHTester} from "./TestContracts/WETHTester.sol";
import {AeroManagerGaugeLifecycleHandler} from "./TestContracts/AeroManagerGaugeLifecycleHandler.sol";
import {BaseInvariantTest} from "./TestContracts/BaseInvariantTest.sol";

/// @title AeroManagerGaugeLifecycleInvariants
/// @notice Invariant + fuzz coverage for `AeroManager.stake` / `withdraw` across gauge kill and revive (mock Voter).
contract AeroManagerGaugeLifecycleInvariants is TestAccounts, BaseInvariantTest {
    AeroGaugeTester internal gauge;
    WETHTester internal weth;
    AeroManager internal aeroManagerImpl;
    IActivePool internal aeroActivePool;
    AeroManagerGaugeLifecycleHandler internal handler;

    address internal borrowerOperationsAddr;

    function setUp() public override {
        vm.warp(block.timestamp + 600);

        accounts = new Accounts();
        createAccounts();

        (A, B, C, D, E, F, G) = (
            accountsList[0],
            accountsList[1],
            accountsList[2],
            accountsList[3],
            accountsList[4],
            accountsList[5],
            accountsList[6]
        );

        super.setUp();

        TestDeployer deployer = new TestDeployer();

        weth = new WETHTester(100 ether, 1 days);
        gauge = new AeroGaugeTester(address(weth), deployer.AERO_TOKEN_ADDRESS());
        MockAeroToken(gauge.rewardToken());

        TestDeployer.TroveManagerParams[] memory troveManagerParamsArray = new TestDeployer.TroveManagerParams[](1);
        troveManagerParamsArray[0] = TestDeployer.TroveManagerParams(
            150e16,
            110e16,
            10e16,
            110e16,
            100_000_000 ether,
            5e16,
            10e16,
            true,
            address(gauge)
        );

        TestDeployer.DeployAndConnectContractsResults memory result =
            deployer.deployAndConnectContracts(troveManagerParamsArray, IWETH(address(weth)));

        TestDeployer.LiquityContractsDev memory contracts = result.contractsArray[0];

        aeroManagerImpl = AeroManager(address(result.aeroManager));
        borrowerOperationsAddr = address(contracts.borrowerOperations);
        aeroActivePool = IActivePool(address(contracts.activePool));

        uint256 initialCollAmount = 10_000_000e18;
        for (uint256 i = 0; i < 6; i++) {
            address acc = accountsList[i];
            deal(address(weth), acc, initialCollAmount);
            vm.startPrank(acc);
            IERC20(address(weth)).approve(borrowerOperationsAddr, initialCollAmount);
            vm.stopPrank();
        }

        handler = new AeroManagerGaugeLifecycleHandler(
            IWETH(address(weth)), gauge, aeroManagerImpl, aeroActivePool, borrowerOperationsAddr, adam
        );
        vm.label(address(handler), "AeroManagerGaugeLifecycleHandler");
        targetContract(address(handler));
    }

    /// @notice ActivePool accounting tracks all LP whether it sits in the gauge or on AeroManager (unstaked buffer).
    function invariant_collBalanceEqualsStakedPlusUnstaked() external view {
        uint256 coll = aeroActivePool.getCollBalance();
        uint256 st = aeroManagerImpl.stakedAmounts(address(gauge));
        uint256 unst = aeroManagerImpl.unstakedAmounts(address(gauge));
        assertEq(coll, st + unst, "collBalance != staked + unstaked");
    }

    /// @notice LP exists only on gauge or AeroManager (never idle on ActivePool for Aero LP).
    function invariant_physicalLpMatchesAccounting() external view {
        uint256 onGauge = IERC20(address(weth)).balanceOf(address(gauge));
        uint256 onManager = IERC20(address(weth)).balanceOf(address(aeroManagerImpl));
        uint256 st = aeroManagerImpl.stakedAmounts(address(gauge));
        uint256 unst = aeroManagerImpl.unstakedAmounts(address(gauge));
        assertEq(onGauge + onManager, st + unst, "physical LP != staked + unstaked");
        assertEq(IERC20(address(weth)).balanceOf(address(aeroActivePool)), 0, "LP dust on ActivePool");
    }

    /// @notice `isAeroGaugeAlive` tracks the mock voter flag.
    function invariant_aliveMatchesVoter() external view {
        assertEq(
            aeroManagerImpl.isAeroGaugeAlive(address(gauge)),
            gauge.aeroVoter().isAlive(address(gauge)),
            "isAeroGaugeAlive mismatch"
        );
    }

    /// @dev Deterministic fuzz: bounded op sequence, then assert same invariants as above.
    function testFuzz_stakeWithdrawKillReviveSequence(uint256 seed, uint8 numOps) public {
        numOps = uint8(bound(uint256(numOps), 1, 64));
        for (uint256 i; i < numOps; i++) {
            uint256 r = uint256(keccak256(abi.encode(seed, i)));
            uint256 op = r % 5;
            if (op == 0) handler.killGauge();
            else if (op == 1) handler.reviveGauge();
            else if (op == 2) handler.stake(r >> 8);
            else if (op == 3) handler.withdraw(r >> 16);
            else {
                if (r % 2 == 0) handler.killGauge();
                else handler.reviveGauge();
            }
        }
        _assertAccounting();
    }

    function _assertAccounting() internal view {
        uint256 coll = aeroActivePool.getCollBalance();
        uint256 st = aeroManagerImpl.stakedAmounts(address(gauge));
        uint256 unst = aeroManagerImpl.unstakedAmounts(address(gauge));
        assertEq(coll, st + unst);

        uint256 onGauge = IERC20(address(weth)).balanceOf(address(gauge));
        uint256 onManager = IERC20(address(weth)).balanceOf(address(aeroManagerImpl));
        assertEq(onGauge + onManager, st + unst);
        assertEq(IERC20(address(weth)).balanceOf(address(aeroActivePool)), 0);
        assertEq(aeroManagerImpl.isAeroGaugeAlive(address(gauge)), gauge.aeroVoter().isAlive(address(gauge)));
    }
}
