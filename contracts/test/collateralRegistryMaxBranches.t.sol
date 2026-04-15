// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TestContracts/Accounts.sol";
import "./TestContracts/Deployment.t.sol";
import {ERC20Faucet} from "./TestContracts/ERC20Faucet.sol";
import "src/CollateralRegistry.sol";
import "src/Interfaces/IBoldToken.sol";
import "src/Interfaces/ICollateralRegistry.sol";
import "src/Interfaces/IAeroManager.sol";
import "src/Interfaces/IWETH.sol";
import "src/MultiTroveGetter.sol";
import "src/HintHelpers.sol";
import "src/Interfaces/IMultiTroveGetter.sol";
import "src/Interfaces/IHintHelpers.sol";

/// @dev Ten redeemable branches are allowed at deployment; the eleventh redeemable `createNewBranch` must revert.
contract CollateralRegistryMaxBranchesTest is TestAccounts {
    TestDeployer internal deployer;
    IBoldToken internal boldToken;
    ICollateralRegistry internal collateralRegistry;
    IWETH internal weth;
    IHintHelpers internal hintHelpers;
    IMultiTroveGetter internal multiTroveGetter;
    IAeroManager internal aeroManager;

    address internal gov = makeAddr("GOVERNOR");

    function setUp() external {
        vm.warp(block.timestamp + 600);

        accounts = new Accounts();
        createAccounts();

        TestDeployer.TroveManagerParams[] memory params = new TestDeployer.TroveManagerParams[](10);
        for (uint256 i = 0; i < 10; i++) {
            params[i] = TestDeployer.TroveManagerParams({
                CCR: 160e16,
                MCR: 120e16,
                BCR: 10e16,
                SCR: 120e16,
                debtLimit: 100_000_000 ether,
                LIQUIDATION_PENALTY_SP: 5e16,
                LIQUIDATION_PENALTY_REDISTRIBUTION: 10e16,
                isAeroLPCollateral: false,
                aeroGaugeAddress: address(0)
            });
        }

        deployer = new TestDeployer();
        TestDeployer.DeployAndConnectContractsMultiCollResult memory result = deployer.deployAndConnectContractsMultiColl(params);
        boldToken = result.boldToken;
        collateralRegistry = result.collateralRegistry;
        weth = result.WETH;
        hintHelpers = result.hintHelpers;
        aeroManager = result.aeroManager;
        multiTroveGetter = IMultiTroveGetter(address(new MultiTroveGetter(collateralRegistry)));
    }

    function test_createNewBranch_revertsWhenMaxRedeemableBranchesReached() public {
        IERC20Metadata lst11 = new ERC20Faucet("LST Tester", "L11", 100 ether, 1 days);
        TestDeployer.AeroParams memory ap = TestDeployer.AeroParams(aeroManager, false, address(0));
        TestDeployer.TroveManagerParams memory p = TestDeployer.TroveManagerParams({
            CCR: 160e16,
            MCR: 120e16,
            BCR: 10e16,
            SCR: 120e16,
            debtLimit: 100_000_000 ether,
            LIQUIDATION_PENALTY_SP: 5e16,
            LIQUIDATION_PENALTY_REDISTRIBUTION: 10e16,
            isAeroLPCollateral: false,
            aeroGaugeAddress: address(0)
        });
        (TestDeployer.LiquityContractsDev memory c11,) =
            deployer.deployAdditionalBranchDev(p, lst11, boldToken, collateralRegistry, weth, hintHelpers, multiTroveGetter, ap);

        vm.prank(gov);
        vm.expectRevert("CR: Max 10 redeemable branches");
        CollateralRegistry(address(collateralRegistry)).createNewBranch(c11.addressesRegistry, true);
    }
}
