// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {IERC20 as IERC20_GOV} from "openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StringFormatting} from "test/Utils/StringFormatting.sol";
import {Accounts} from "test/TestContracts/Accounts.sol";
import {ERC20Faucet} from "test/TestContracts/ERC20Faucet.sol";
import "src/Dependencies/Constants.sol";
import {IBorrowerOperations} from "src/Interfaces/IBorrowerOperations.sol";
import "src/AddressesRegistry.sol";
import "src/ActivePool.sol";
import "src/BoldToken.sol";
import "src/BorrowerOperations.sol";
import "src/AeroTroveManager.sol";
import "src/TroveNFT.sol";
import "src/CollSurplusPool.sol";
import "src/DefaultPool.sol";
import "src/GasPool.sol";
import "src/HintHelpers.sol";
import "src/MultiTroveGetter.sol";
import {DebtInFrontHelper, IDebtInFrontHelper} from "src/DebtInFrontHelper.sol";
import {RedemptionHelper, IRedemptionHelper} from "src/RedemptionHelper.sol";
import "src/SortedTroves.sol";
import "src/StabilityPool.sol";
import "src/PriceFeeds/WETHPriceFeed.sol";
import "src/PriceFeeds/WSTETHPriceFeed.sol";
import "src/PriceFeeds/RETHPriceFeed.sol";
import "src/PriceFeeds/cbBTCPriceFeed.sol";
import "src/PriceFeeds/cbETHPriceFeed.sol";
import "src/PriceFeeds/AEROPriceFeed.sol";
import "src/PriceFeeds/AeroLPTokenPriceFeed.sol";
import {IAeroGauge} from "src/Interfaces/IAeroGauge.sol";
import {AeroManager} from "src/AeroManager.sol";
import {IAeroManager} from "src/Interfaces/IAeroManager.sol";
import "src/CollateralRegistry.sol";
import "test/TestContracts/PriceFeedTestnet.sol";
import "test/TestContracts/MetadataDeployment.sol";
import "test/Utils/Logging.sol";
import "test/Utils/StringEquality.sol";
import {WrappedToken} from "src/ERC20Wrappers/WrappedToken.sol";
import {IWrappedToken} from "src/Interfaces/IWrappedToken.sol";
import "src/Zappers/WETHZapper.sol";
import "src/Zappers/GasCompZapper.sol";
import "src/Zappers/LeverageLSTZapper.sol";
import "src/Zappers/LeverageWETHZapper.sol";
import "src/Zappers/WrappedTokenZapper.sol";
import "src/Zappers/Modules/Exchanges/HybridCurveUniV3ExchangeHelpers.sol";
import "src/Zappers/Modules/Exchanges/HybridCurveUniV3ExchangeHelpersV2.sol";
import {BalancerFlashLoan} from "src/Zappers/Modules/FlashLoans/BalancerFlashLoan.sol";
import "src/Zappers/Modules/Exchanges/Curve/ICurveStableswapNGFactory.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/ISwapRouter.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/IQuoterV2.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/IUniswapV3Pool.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/IUniswapV3Factory.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/INonfungiblePositionManager.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/UniPriceConverter.sol";
import "src/Zappers/Modules/Exchanges/HybridCurveUniV3Exchange.sol";
import {WETHTester} from "test/TestContracts/WETHTester.sol";
import "forge-std/console2.sol";
import {IRateProvider, IWeightedPool, IWeightedPoolFactory} from "./Interfaces/Balancer/IWeightedPool.sol";
import {IVault} from "./Interfaces/Balancer/IVault.sol";
import {MockStakingV1} from "V2-gov/test/mocks/MockStakingV1.sol";

import {DeployGovernance} from "./DeployGovernance.s.sol";

function _latestUTCMidnightBetweenWednesdayAndThursday() view returns (uint256) {
    return block.timestamp / 1 weeks * 1 weeks;
}

contract DeployLiquity2Script is DeployGovernance, UniPriceConverter, StdCheats, MetadataDeployment, Logging {
    using Strings for *;
    using StringFormatting for *;
    using StringEquality for string;

    string constant DEPLOYMENT_MODE_COMPLETE = "complete";
    string constant DEPLOYMENT_MODE_BOLD_ONLY = "bold-only";
    string constant DEPLOYMENT_MODE_USE_EXISTING_BOLD = "use-existing-bold";

    uint256 constant NUM_BRANCHES = 5;

    // Base Mainnet addresses
    address WETH_ADDRESS = 0x4200000000000000000000000000000000000006;
    address USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // used for gas compensation and as collateral of the first branch
    // tapping disallowed
    IWETH WETH;
    IERC20Metadata USDC;

    // Collateral token addresses (Base Mainnet)
    address AERO_ADDRESS = 0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee;

    // Aerodrome LP gauge address (for LP token price feed)
    address AERO_LP_GAUGE_ADDRESS = address(0); // No gauge

    // AeroManager treasury address (receives fee from AERO claims)
    address TREASURY_ADDRESS = 0x519CA17DAE2E2A23396eBEC12DA1f645AccEC196;

    // Oracle addresses (Base Mainnet - API3)
    address AERO_USD_ORACLE_ADDRESS = 0x6C655693f733FB26EA28e7757DD4a5Ad59061e75;

    // Staleness thresholds
    uint256 AERO_USD_STALENESS_THRESHOLD = 25 hours;

    // Core Base Dollar contracts on Base
    address BOLD_TOKEN_ADDRESS = 0x252D36F435582EcB01686448d21e8C9eA0B2Ca65;
    address COLLATERAL_REGISTRY_ADDRESS = 0x7551EBFC8340b7F91874942Be9C653733D4fb04f;
    address HINT_HELPERS_ADDRESS = 0x9D8FB1d1e2121e86375c07F0bA65dD54cb6CA333;
    address MULTI_TROVE_GETTER_ADDRESS = 0xad0469046cFCc4806384e3263Ace6C11D005d608;
    address DEBT_IN_FRONT_HELPER_ADDRESS = 0xc4a5393d6b96BC77e5A80098ED08FdeEfF70b974;
    address AERO_MANAGER_ADDRESS = 0xE8900C7aebCa7D212717Fe2f4Df9f567e3f4d7F4;
    address REDEMPTION_HELPER_ADDRESS = 0x438D0eDb577997898BbEF4fe1c798247d7Eb5c4F;

    // V1
    address LQTY_ADDRESS = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D;
    address LQTY_STAKING_ADDRESS = 0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d;
    address LUSD_ADDRESS = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;

    address internal lqty;
    address internal stakingV1;
    address internal lusd;

    address public GOVERNOR_ADDRESS = 0x519CA17DAE2E2A23396eBEC12DA1f645AccEC196;

    uint128 constant BOLD_TOKEN_INDEX = 0;
    uint128 constant OTHER_TOKEN_INDEX = 1;

    bytes32 SALT;
    address deployer;
    bool useTestnetPriceFeeds;

    uint256 lastTroveIndex;

    struct LiquityContracts {
        IAddressesRegistry addressesRegistry;
        IActivePool activePool;
        IBorrowerOperations borrowerOperations;
        ICollSurplusPool collSurplusPool;
        IDefaultPool defaultPool;
        ISortedTroves sortedTroves;
        IStabilityPool stabilityPool;
        ITroveManager troveManager;
        ITroveNFT troveNFT;
        MetadataNFT metadataNFT;
        IPriceFeed priceFeed;
        GasPool gasPool;
        IInterestRouter interestRouter;
        IERC20Metadata collToken;
        WETHZapper wethZapper;
        GasCompZapper gasCompZapper;
        ILeverageZapper leverageZapper;
        WrappedTokenZapper wrappedTokenZapper;
    }

    struct LiquityContractAddresses {
        address activePool;
        address borrowerOperations;
        address collSurplusPool;
        address defaultPool;
        address sortedTroves;
        address stabilityPool;
        address troveManager;
        address troveNFT;
        address metadataNFT;
        address priceFeed;
        address gasPool;
        address interestRouter;
    }

    struct Zappers {
        WETHZapper wethZapper;
        GasCompZapper gasCompZapper;
    }

    struct TroveManagerParams {
        uint256 CCR;
        uint256 MCR;
        uint256 SCR;
        uint256 BCR;
        uint256 debtLimit;
        uint256 LIQUIDATION_PENALTY_SP;
        uint256 LIQUIDATION_PENALTY_REDISTRIBUTION;
        bool isAeroLPCollateral;
        address aeroGauge;
    }

    struct DeploymentVars {
        IERC20Metadata collateral;
        IAddressesRegistry addressesRegistry;
        ITroveManager troveManager;
        LiquityContracts contracts;
        bytes bytecode;
        address boldTokenAddress;
        uint256 i;
    }

    struct DemoTroveParams {
        uint256 collIndex;
        uint256 owner;
        uint256 ownerIndex;
        uint256 coll;
        uint256 debt;
        uint256 annualInterestRate;
    }

    struct DeploymentResult {
        LiquityContracts contracts;
        ICollateralRegistry collateralRegistry;
        IBoldToken boldToken;
        ICurveStableswapNGPool usdcCurvePool;
        HintHelpers hintHelpers;
        MultiTroveGetter multiTroveGetter;
        IDebtInFrontHelper debtInFrontHelper;
        IExchangeHelpers exchangeHelpers;
        IExchangeHelpersV2 exchangeHelpersV2;
        IRedemptionHelper redemptionHelper;
        IAeroManager aeroManager;
    }

    function run() external {
        string memory saltStr = vm.envOr("SALT", block.timestamp.toString());
        SALT = keccak256(bytes(saltStr));

        if (vm.envBytes("DEPLOYER").length == 20) {
            // address
            deployer = vm.envAddress("DEPLOYER");
            vm.startBroadcast(deployer);
        } else {
            // private key
            uint256 privateKey = vm.envUint("DEPLOYER");
            deployer = vm.addr(privateKey);
            vm.startBroadcast(privateKey);
        }

        string memory deploymentMode = vm.envOr("DEPLOYMENT_MODE", DEPLOYMENT_MODE_COMPLETE);
        require(
            deploymentMode.eq(DEPLOYMENT_MODE_COMPLETE) || deploymentMode.eq(DEPLOYMENT_MODE_BOLD_ONLY)
                || deploymentMode.eq(DEPLOYMENT_MODE_USE_EXISTING_BOLD),
            string.concat("Bad deployment mode: ", deploymentMode)
        );

        uint256 epochStart = vm.envOr(
            "EPOCH_START",
            (block.chainid == 1 ? _latestUTCMidnightBetweenWednesdayAndThursday() : block.timestamp) - EPOCH_DURATION
        );

        useTestnetPriceFeeds = vm.envOr("USE_TESTNET_PRICEFEEDS", false);

        _log("Deployer:               ", deployer.toHexString());
        _log("Deployer balance:       ", deployer.balance.decimal());
        _log("Deployment mode:        ", deploymentMode);
        _log("CREATE2 salt:           ", 'keccak256(bytes("', saltStr, '")) = ', uint256(SALT).toHexString());
        _log("Governance epoch start: ", epochStart.toString());
        _log("Use testnet PriceFeeds: ", useTestnetPriceFeeds ? "yes" : "no");

        // Deploy Bold or pick up existing deployment
        address boldAddress = BOLD_TOKEN_ADDRESS;
        BoldToken boldToken;

        require(boldAddress.code.length > 0, string.concat("BOLD not found at ", boldAddress.toHexString()));
        boldToken = BoldToken(boldAddress);

        // Check BOLD is untouched
        require(boldToken.collateralRegistryAddress() == COLLATERAL_REGISTRY_ADDRESS, "Incorrect collateral registry of BOLD");
        require(boldToken.owner() == address(0), "BOLD ownership not renounced");
        require(CollateralRegistry(COLLATERAL_REGISTRY_ADDRESS).governor() == GOVERNOR_ADDRESS, "Incorrect governor address");
        // require(boldToken.totalSupply() == 0, "Some BOLD has been minted!");
        // require(boldToken.collateralRegistryAddress() == address(0), "Collateral registry already set");
        // require(boldToken.owner() == deployer, "Not BOLD owner");

        if (block.chainid == 8453) {
            // Base mainnet
            WETH = IWETH(WETH_ADDRESS);
            USDC = IERC20Metadata(USDC_ADDRESS);
        } else {
            // sepolia, local
            if (block.chainid == 31337) {
                // local
                WETH = new WETHTester({_tapAmount: 100 ether, _tapPeriod: 1 days});
            } else {
                // sepolia
                WETH = new WETHTester({_tapAmount: 0, _tapPeriod: type(uint256).max});
            }
        }

        TroveManagerParams memory troveManagerParams = TroveManagerParams({
            isAeroLPCollateral: false,
            aeroGauge: address(0),
            CCR: CCR_AERO,
            MCR: MCR_AERO,
            SCR: SCR_AERO,
            BCR: BCR_ALL,
            debtLimit: DEBT_LIMIT_AERO,
            LIQUIDATION_PENALTY_SP: LIQUIDATION_PENALTY_SP_AERO,
            LIQUIDATION_PENALTY_REDISTRIBUTION: LIQUIDATION_PENALTY_REDISTRIBUTION_AERO
        });

        string memory collName = "Aero";
        string memory collSymbol = "AERO";

        DeploymentResult memory deployed =
            _deployAndConnectContracts(troveManagerParams, boldAddress);

        if (block.chainid == 84532) {
            // Provide liquidity for zaps if we're on Sepolia
            ERC20Faucet monkeyBalls = new ERC20Faucet("MonkeyBalls", "MB", 0, type(uint256).max);
            
            // Sets AERO price to 0.0001 USD
            PriceFeedTestnet(address(deployed.contracts.priceFeed)).setPrice(0.35 ether);
        }

        vm.stopBroadcast();

        // vm.writeFile("deployment-manifest.json", _getManifestJson(deployed, governanceManifest));
        vm.writeFile("deployment-manifest.json", _getManifestJson(deployed, ""));
    }

    function tapFaucet(uint256[] memory accounts, LiquityContracts memory contracts) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            ERC20Faucet token = ERC20Faucet(address(contracts.collToken));

            vm.startBroadcast(accounts[i]);
            token.tap();
            vm.stopBroadcast();

            console2.log(
                "%s.tap() => %s (balance: %s)",
                token.symbol(),
                vm.addr(accounts[i]),
                string.concat(formatAmount(token.balanceOf(vm.addr(accounts[i])), 18, 2), " ", token.symbol())
            );
        }
    }

    function openDemoTroves(DemoTroveParams[] memory demoTroves, LiquityContracts[] memory contractsArray) internal {
        for (uint256 i = 0; i < demoTroves.length; i++) {
            console2.log(
                "openTrove({ coll: %18e, borrow: %18e, rate: %18e%% })",
                demoTroves[i].coll,
                demoTroves[i].debt,
                demoTroves[i].annualInterestRate * 100
            );

            DemoTroveParams memory trove = demoTroves[i];
            LiquityContracts memory contracts = contractsArray[trove.collIndex];

            vm.startBroadcast(trove.owner);

            IERC20 collToken = IERC20(contracts.collToken);
            IERC20 wethToken = IERC20(contracts.addressesRegistry.WETH());

            // Approve collToken to BorrowerOperations
            if (collToken == wethToken) {
                wethToken.approve(address(contracts.borrowerOperations), trove.coll + ETH_GAS_COMPENSATION);
            } else {
                wethToken.approve(address(contracts.borrowerOperations), ETH_GAS_COMPENSATION);
                collToken.approve(address(contracts.borrowerOperations), trove.coll);
            }

            IBorrowerOperations(contracts.borrowerOperations).openTrove(
                vm.addr(trove.owner), //     _owner
                trove.ownerIndex, //         _ownerIndex
                trove.coll, //               _collAmount
                trove.debt, //               _boldAmount
                0, //                        _upperHint
                0, //                        _lowerHint
                trove.annualInterestRate, // _annualInterestRate
                type(uint256).max, //        _maxUpfrontFee
                address(0), //               _addManager
                address(0), //               _removeManager
                address(0) //                _receiver
            );

            vm.stopBroadcast();
        }
    }

    // See: https://solidity-by-example.org/app/create2/
    function getBytecode(bytes memory _creationCode, address _addressesRegistry) public pure returns (bytes memory) {
        return abi.encodePacked(_creationCode, abi.encode(_addressesRegistry));
    }

    function getBytecode(bytes memory _creationCode, address _addressesRegistry, address _governor) public pure returns (bytes memory) {
        return abi.encodePacked(_creationCode, abi.encode(_addressesRegistry, _governor));
    }

    function getBytecode(bytes memory _creationCode, address _addressesRegistry, bool _isRedemptionProtectedBranch) public pure returns (bytes memory) {
        return abi.encodePacked(_creationCode, abi.encode(_addressesRegistry, _isRedemptionProtectedBranch));
    }

    function getBytecode(bytes memory _creationCode, address _addressesRegistry, bool _isAeroLPCollateral, address _aeroGaugeAddress) public pure returns (bytes memory) {
        return abi.encodePacked(_creationCode, abi.encode(_addressesRegistry, _isAeroLPCollateral, _aeroGaugeAddress));
    }

    function _deployAndConnectContracts(
        TroveManagerParams memory troveManagerParams,
        address _boldToken
    ) internal returns (DeploymentResult memory r) {
        r.boldToken = BoldToken(_boldToken);

        // Collaterals
        IERC20Metadata collateral; 
        if (block.chainid == 8453 && !useTestnetPriceFeeds) {
            // Base mainnet
            // AERO
            collateral = IERC20Metadata(AERO_ADDRESS);
        } else {
            // Sepolia or local
            // Deploy plain ERC20Faucets for the rest of the branches
            // collateral = new ERC20Faucet(
            //     _collName, //   _name
            //     _collSymbol, // _symbol
            //     100 ether, //     _tapAmount
            //     1 days //         _tapPeriod
            // );
            revert("Testnet not supported for this script");
        }

        // Deploy AddressesRegistry and get TroveManager address
        (IAddressesRegistry addressesRegistry, address troveManagerAddress) =
            _deployAddressesRegistry(troveManagerParams);

        r.aeroManager = IAeroManager(AERO_MANAGER_ADDRESS);
        r.collateralRegistry = ICollateralRegistry(COLLATERAL_REGISTRY_ADDRESS);
        r.hintHelpers = HintHelpers(HINT_HELPERS_ADDRESS);
        r.multiTroveGetter = MultiTroveGetter(MULTI_TROVE_GETTER_ADDRESS);
        r.debtInFrontHelper = IDebtInFrontHelper(DEBT_IN_FRONT_HELPER_ADDRESS);
        r.redemptionHelper = IRedemptionHelper(REDEMPTION_HELPER_ADDRESS);

        // Deploy per-branch contracts for each branch (Solely AERO branch)
        r.contracts = _deployAndConnectCollateralContracts(
            collateral,
            r.boldToken,
            r.collateralRegistry,
            r.aeroManager,
            r.usdcCurvePool,
            addressesRegistry,
            troveManagerAddress,
            r.hintHelpers,
            r.multiTroveGetter,
            troveManagerParams,
            GOVERNOR_ADDRESS
        );
    }

    function _deployAddressesRegistry(TroveManagerParams memory _troveManagerParams)
        internal
        returns (IAddressesRegistry, address)
    {
        IAddressesRegistry addressesRegistry = new AddressesRegistry(
            deployer,
            _troveManagerParams.CCR,
            _troveManagerParams.MCR,
            _troveManagerParams.BCR,
            _troveManagerParams.SCR,
            _troveManagerParams.debtLimit,
            _troveManagerParams.LIQUIDATION_PENALTY_SP,
            _troveManagerParams.LIQUIDATION_PENALTY_REDISTRIBUTION
        );
        address troveManagerAddress = vm.computeCreate2Address(
            SALT, keccak256(getBytecode(type(AeroTroveManager).creationCode, address(addressesRegistry)))
        );

        return (addressesRegistry, troveManagerAddress);
    }

    function _deployAndConnectCollateralContracts(
        IERC20Metadata _collToken,
        IBoldToken _boldToken,
        ICollateralRegistry _collateralRegistry,
        IAeroManager _aeroManager,
        ICurveStableswapNGPool _usdcCurvePool,
        IAddressesRegistry _addressesRegistry,
        address _troveManagerAddress,
        IHintHelpers _hintHelpers,
        IMultiTroveGetter _multiTroveGetter,
        TroveManagerParams memory _troveManagerParams,
        address _governance
    ) internal returns (LiquityContracts memory contracts) {
        LiquityContractAddresses memory addresses;
        contracts.collToken = _collToken;

        // Deploy all contracts, using testers for TM and PriceFeed
        contracts.addressesRegistry = _addressesRegistry;

        // Deploy Metadata
        contracts.metadataNFT = deployMetadata(SALT);
        addresses.metadataNFT = vm.computeCreate2Address(
            SALT, keccak256(getBytecode(type(MetadataNFT).creationCode, address(initializedFixedAssetReader)))
        );
        assert(address(contracts.metadataNFT) == addresses.metadataNFT);

        contracts.interestRouter = IInterestRouter(_governance);
        addresses.borrowerOperations = vm.computeCreate2Address(
            SALT, keccak256(getBytecode(type(BorrowerOperations).creationCode, address(contracts.addressesRegistry), false))
        );
        addresses.troveManager = _troveManagerAddress;
        addresses.troveNFT = vm.computeCreate2Address(
            SALT, keccak256(getBytecode(type(TroveNFT).creationCode, address(contracts.addressesRegistry), GOVERNOR_ADDRESS))
        );
        addresses.stabilityPool = vm.computeCreate2Address(
            SALT, keccak256(getBytecode(type(StabilityPool).creationCode, address(contracts.addressesRegistry)))
        );
        addresses.activePool = vm.computeCreate2Address(
            SALT, keccak256(getBytecode(type(ActivePool).creationCode, address(contracts.addressesRegistry), _troveManagerParams.isAeroLPCollateral, _troveManagerParams.aeroGauge))
        );
        addresses.defaultPool = vm.computeCreate2Address(
            SALT, keccak256(getBytecode(type(DefaultPool).creationCode, address(contracts.addressesRegistry)))
        );
        addresses.gasPool = vm.computeCreate2Address(
            SALT, keccak256(getBytecode(type(GasPool).creationCode, address(contracts.addressesRegistry)))
        );
        addresses.collSurplusPool = vm.computeCreate2Address(
            SALT, keccak256(getBytecode(type(CollSurplusPool).creationCode, address(contracts.addressesRegistry)))
        );
        addresses.sortedTroves = vm.computeCreate2Address(
            SALT, keccak256(getBytecode(type(SortedTroves).creationCode, address(contracts.addressesRegistry)))
        );

        contracts.priceFeed = _deployPriceFeed(address(_collToken), addresses.borrowerOperations);

        IAddressesRegistry.AddressVars memory addressVars = IAddressesRegistry.AddressVars({
            collToken: _collToken,
            borrowerOperations: IBorrowerOperations(addresses.borrowerOperations),
            troveManager: ITroveManager(addresses.troveManager),
            troveNFT: ITroveNFT(addresses.troveNFT),
            metadataNFT: IMetadataNFT(addresses.metadataNFT),
            stabilityPool: IStabilityPool(addresses.stabilityPool),
            priceFeed: contracts.priceFeed,
            activePool: IActivePool(addresses.activePool),
            defaultPool: IDefaultPool(addresses.defaultPool),
            gasPoolAddress: addresses.gasPool,
            collSurplusPool: ICollSurplusPool(addresses.collSurplusPool),
            sortedTroves: ISortedTroves(addresses.sortedTroves),
            interestRouter: contracts.interestRouter,
            hintHelpers: _hintHelpers,
            multiTroveGetter: _multiTroveGetter,
            collateralRegistry: _collateralRegistry,
            boldToken: _boldToken,
            WETH: WETH,
            aeroManager: _aeroManager
        });
        contracts.addressesRegistry.setAddresses(addressVars);

        contracts.borrowerOperations = new BorrowerOperations{salt: SALT}(contracts.addressesRegistry, false);
        contracts.troveManager = new AeroTroveManager{salt: SALT}(contracts.addressesRegistry);
        contracts.troveNFT = new TroveNFT{salt: SALT}(contracts.addressesRegistry, GOVERNOR_ADDRESS);
        contracts.stabilityPool = new StabilityPool{salt: SALT}(contracts.addressesRegistry);
        contracts.activePool = new ActivePool{salt: SALT}(contracts.addressesRegistry, _troveManagerParams.isAeroLPCollateral, _troveManagerParams.aeroGauge);
        contracts.defaultPool = new DefaultPool{salt: SALT}(contracts.addressesRegistry);
        contracts.gasPool = new GasPool{salt: SALT}(contracts.addressesRegistry);
        contracts.collSurplusPool = new CollSurplusPool{salt: SALT}(contracts.addressesRegistry);
        contracts.sortedTroves = new SortedTroves{salt: SALT}(contracts.addressesRegistry);

        assert(address(contracts.borrowerOperations) == addresses.borrowerOperations);
        assert(address(contracts.troveManager) == addresses.troveManager);
        assert(address(contracts.troveNFT) == addresses.troveNFT);
        assert(address(contracts.stabilityPool) == addresses.stabilityPool);
        assert(address(contracts.activePool) == addresses.activePool);
        assert(address(contracts.defaultPool) == addresses.defaultPool);
        assert(address(contracts.gasPool) == addresses.gasPool);
        assert(address(contracts.collSurplusPool) == addresses.collSurplusPool);
        assert(address(contracts.sortedTroves) == addresses.sortedTroves);

        // THIS IS A GOVERNOR ACTION POST-DEPLOYMENT
        // Connect contracts
        // _boldToken.setBranchAddresses(
        //     address(contracts.troveManager),
        //     address(contracts.stabilityPool),
        //     address(contracts.borrowerOperations),
        //     address(contracts.activePool)
        // );

        // deploy zappers
        (contracts.gasCompZapper, contracts.wethZapper, contracts.leverageZapper, contracts.wrappedTokenZapper) =
            _deployZappers(contracts.addressesRegistry, contracts.collToken, _boldToken, _usdcCurvePool);
    }

    function _deployPriceFeed(address _collTokenAddress, address _borrowerOperationsAddress)
        internal
        returns (IPriceFeed)
    {
        if (block.chainid == 8453 && !useTestnetPriceFeeds) {
            // Base mainnet
            
            // AERO
            require(_collTokenAddress == AERO_ADDRESS, "Unknown collateral token");
            AEROPriceFeed priceFeed = new AEROPriceFeed(
                _borrowerOperationsAddress,
                AERO_USD_ORACLE_ADDRESS,
                AERO_USD_STALENESS_THRESHOLD
            );
            return priceFeed;
        }

        // Sepolia or local
        return new PriceFeedTestnet();
    }

    function _deployZappers(
        IAddressesRegistry _addressesRegistry,
        IERC20 _collToken,
        IBoldToken _boldToken,
        ICurveStableswapNGPool _usdcCurvePool
    ) internal returns (GasCompZapper gasCompZapper, WETHZapper wethZapper, ILeverageZapper leverageZapper, WrappedTokenZapper wrappedTokenZapper) {
        IFlashLoanProvider flashLoanProvider = IFlashLoanProvider(address(0));
        IExchange hybridExchange = IExchange(address(0));

        bool lst = _collToken != WETH;
        if (lst) {
            gasCompZapper = new GasCompZapper(_addressesRegistry, flashLoanProvider, hybridExchange);
        } else {
            wethZapper = new WETHZapper(_addressesRegistry, flashLoanProvider, hybridExchange);
        }
        leverageZapper = ILeverageZapper(address(0));
    }

    function formatAmount(uint256 amount, uint256 decimals, uint256 digits) internal pure returns (string memory) {
        if (digits > decimals) {
            digits = decimals;
        }

        uint256 scaled = amount / (10 ** (decimals - digits));
        string memory whole = Strings.toString(scaled / (10 ** digits));

        if (digits == 0) {
            return whole;
        }

        string memory fractional = Strings.toString(scaled % (10 ** digits));
        for (uint256 i = bytes(fractional).length; i < digits; i++) {
            fractional = string.concat("0", fractional);
        }
        return string.concat(whole, ".", fractional);
    }

    function _getBranchContractsJson(LiquityContracts memory c) internal view returns (string memory) {
        return string.concat(
            "{",
            string.concat(
                // Avoid stack too deep by chunking concats
                string.concat(
                    string.concat('"collSymbol":"', c.collToken.symbol(), '",'), // purely for human-readability
                    string.concat('"collToken":"', address(c.collToken).toHexString(), '",'),
                    string.concat('"addressesRegistry":"', address(c.addressesRegistry).toHexString(), '",'),
                    string.concat('"activePool":"', address(c.activePool).toHexString(), '",'),
                    string.concat('"borrowerOperations":"', address(c.borrowerOperations).toHexString(), '",'),
                    string.concat('"collSurplusPool":"', address(c.collSurplusPool).toHexString(), '",'),
                    string.concat('"defaultPool":"', address(c.defaultPool).toHexString(), '",'),
                    string.concat('"sortedTroves":"', address(c.sortedTroves).toHexString(), '",')
                ),
                string.concat(
                    string.concat('"stabilityPool":"', address(c.stabilityPool).toHexString(), '",'),
                    string.concat('"troveManager":"', address(c.troveManager).toHexString(), '",'),
                    string.concat('"troveNFT":"', address(c.troveNFT).toHexString(), '",'),
                    string.concat('"metadataNFT":"', address(c.metadataNFT).toHexString(), '",'),
                    string.concat('"priceFeed":"', address(c.priceFeed).toHexString(), '",'),
                    string.concat('"gasPool":"', address(c.gasPool).toHexString(), '",'),
                    string.concat('"interestRouter":"', address(c.interestRouter).toHexString(), '",'),
                    string.concat('"wethZapper":"', address(c.wethZapper).toHexString(), '",')
                ),
                string.concat(
                    string.concat('"gasCompZapper":"', address(c.gasCompZapper).toHexString(), '",'),
                    string.concat('"leverageZapper":"', address(c.leverageZapper).toHexString(), '",')
                )
            ),
            "}"
        );
    }

    function _getDeploymentConstants() internal pure returns (string memory) {
        return string.concat(
            "{",
            string.concat(
                string.concat('"ETH_GAS_COMPENSATION":"', ETH_GAS_COMPENSATION.toString(), '",'),
                string.concat('"INTEREST_RATE_ADJ_COOLDOWN":"', INTEREST_RATE_ADJ_COOLDOWN.toString(), '",'),
                string.concat('"MAX_ANNUAL_INTEREST_RATE":"', MAX_ANNUAL_INTEREST_RATE.toString(), '",'),
                string.concat('"MIN_ANNUAL_INTEREST_RATE":"', MIN_ANNUAL_INTEREST_RATE.toString(), '",'),
                string.concat('"MIN_DEBT":"', MIN_DEBT.toString(), '",'),
                string.concat('"SP_YIELD_SPLIT":"', SP_YIELD_SPLIT.toString(), '",'),
                string.concat('"UPFRONT_INTEREST_PERIOD":"', UPFRONT_INTEREST_PERIOD.toString(), '"') // no comma
            ),
            "}"
        );
    }

    function _getManifestJson(DeploymentResult memory deployed, string memory _governanceManifest)
        internal
        view
        returns (string memory)
    {
        // Poor man's .map()
        string memory branch = _getBranchContractsJson(deployed.contracts);

        return string.concat(
            "{",
            string.concat(
                string.concat('"constants":', _getDeploymentConstants(), ","),
                string.concat('"collateralRegistry":"', address(deployed.collateralRegistry).toHexString(), '",'),
                string.concat('"boldToken":"', address(deployed.boldToken).toHexString(), '",'),
                string.concat('"hintHelpers":"', address(deployed.hintHelpers).toHexString(), '",'),
                string.concat('"multiTroveGetter":"', address(deployed.multiTroveGetter).toHexString(), '",'),
                string.concat('"debtInFrontHelper":"', address(deployed.debtInFrontHelper).toHexString(), '",'),
                string.concat('"exchangeHelpers":"', address(deployed.exchangeHelpers).toHexString(), '",'),
                string.concat('"exchangeHelpersV2":"', address(deployed.exchangeHelpersV2).toHexString(), '",')
            ),
            string.concat(
                string.concat('"redemptionHelper":"', address(deployed.redemptionHelper).toHexString(), '",'),
                string.concat('"aeroManager":"', address(deployed.aeroManager).toHexString(), '",'),
                string.concat('"branch":[', branch, "],"),
                string.concat('"governance":', _governanceManifest, "") // no comma
            ),
            "}"
        );
    }
}
