// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {DeployAeroBranch} from "script/DeployAeroBranch.s.sol";
import {AeroTroveManager} from "src/AeroTroveManager.sol";
import {CollateralRegistry} from "src/CollateralRegistry.sol";
import {IAddressesRegistry} from "src/Interfaces/IAddressesRegistry.sol";
import {ITroveManager} from "src/Interfaces/ITroveManager.sol";
import {AEROPriceFeed} from "src/PriceFeeds/AEROPriceFeed.sol";
import {ERC20Faucet} from "./TestContracts/ERC20Faucet.sol";
import {ChainlinkOracleMock} from "./TestContracts/ChainlinkOracleMock.sol";
import {TestDeployer} from "./TestContracts/Deployment.t.sol";

contract AeroTroveManagerHarness is AeroTroveManager {
    constructor(IAddressesRegistry registry) AeroTroveManager(registry) {}

    function collateralGasCompensation(uint256 collateral) external pure returns (uint256) {
        return _getCollGasCompensation(collateral);
    }
}

contract DeployAeroBranchTest is Test {
    uint256 internal constant DEPLOYER_KEY = 0xA11CE;

    CollateralRegistry internal collateralRegistry;
    IAddressesRegistry internal referenceRegistry;
    ERC20Faucet internal aero;
    ChainlinkOracleMock internal oracle;

    function setUp() public {
        vm.warp(200_000);
        TestDeployer deployer = new TestDeployer();
        TestDeployer.DeployAndConnectContractsResult memory existing = deployer.deployAndConnectContracts();
        collateralRegistry = CollateralRegistry(address(existing.collateralRegistry));
        referenceRegistry = existing.contracts.addressesRegistry;

        aero = new ERC20Faucet("Aerodrome", "AERO", 0, type(uint256).max);
        oracle = new ChainlinkOracleMock();
        oracle.setDecimals(8);
        oracle.setPrice(50_000_000); // $0.50
        oracle.setUpdatedAt(block.timestamp);
    }

    function test_collateralGasCompensationUsesAeroCap() public {
        AeroTroveManagerHarness troveManager = new AeroTroveManagerHarness(referenceRegistry);

        assertEq(troveManager.collateralGasCompensation(100e18), 0.5e18);
        assertEq(troveManager.collateralGasCompensation(100_000e18), 500e18);
        assertEq(troveManager.collateralGasCompensation(200_000e18), 500e18);
    }

    function _setDeploymentEnv() internal {
        vm.chainId(8453);
        vm.setEnv("DEPLOYER_PRIVATE_KEY", vm.toString(DEPLOYER_KEY));
        vm.setEnv("COLLATERAL_REGISTRY", vm.toString(address(collateralRegistry)));
        vm.setEnv("REFERENCE_ADDRESSES_REGISTRY", vm.toString(address(referenceRegistry)));
        vm.setEnv("AERO_TOKEN", vm.toString(address(aero)));
        vm.setEnv("AERO_USD_ORACLE", vm.toString(address(oracle)));
        vm.setEnv("AERO_BRANCH_SALT", vm.toString(keccak256("test-aero-branch")));
        vm.setEnv("REGISTER_BRANCH", "true");
    }

    function test_deploysAndRegistersRedeemableBranchWithGovernor() public {
        vm.prank(collateralRegistry.governor());
        collateralRegistry.updateCollateralGovernor(vm.addr(DEPLOYER_KEY));
        _setDeploymentEnv();

        IAddressesRegistry branchRegistry = new DeployAeroBranch().run();

        assertEq(collateralRegistry.getTroveManagers().length, 2);
        assertEq(address(collateralRegistry.getToken(1)), address(aero));
        assertEq(branchRegistry.CCR(), 185e16);
        assertEq(branchRegistry.MCR(), 140e16);
        assertEq(branchRegistry.SCR(), 140e16);
        assertEq(branchRegistry.debtLimit(), 1_000_000e18);
        assertEq(branchRegistry.LIQUIDATION_PENALTY_SP(), 5e16);
        assertEq(branchRegistry.LIQUIDATION_PENALTY_REDISTRIBUTION(), 20e16);

        ITroveManager troveManager = collateralRegistry.getTroveManager(1);
        assertEq(troveManager.getInitialDebtLimit(), 1_000_000e18);
        assertFalse(troveManager.activePool().isAeroLPCollateral());
        assertEq(AEROPriceFeed(address(troveManager.getPriceFeed())).lastGoodPrice(), 0.5e18);
    }
}
