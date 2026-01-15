// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "src/AddressesRegistry.sol";
import "src/ActivePool.sol";
import "src/AeroManager.sol";
import "src/BoldToken.sol";
import "src/BorrowerOperations.sol";
import "src/CollSurplusPool.sol";
import "src/DefaultPool.sol";
import "src/GasPool.sol";
import "src/HintHelpers.sol";
import "src/MultiTroveGetter.sol";
import "src/SortedTroves.sol";
import "src/StabilityPool.sol";
import "./BorrowerOperationsTester.t.sol";
import "./TroveManagerTester.t.sol";
import "./CollateralRegistryTester.sol";
import "src/TroveNFT.sol";
import "src/NFTMetadata/MetadataNFT.sol";
import "src/CollateralRegistry.sol";
import "./MockInterestRouter.sol";
import "./PriceFeedTestnet.sol";
import "./MetadataDeployment.sol";
import "src/Zappers/WETHZapper.sol";
import "src/Zappers/GasCompZapper.sol";
import "src/Zappers/LeverageLSTZapper.sol";
import "src/Zappers/LeverageWETHZapper.sol";
import "src/Zappers/Modules/FlashLoans/BalancerFlashLoan.sol";
import "src/Zappers/Interfaces/IFlashLoanProvider.sol";
import "src/Zappers/Interfaces/IExchange.sol";
import "src/Zappers/Modules/Exchanges/Curve/ICurveFactory.sol";
import "src/Zappers/Modules/Exchanges/Curve/ICurveStableswapNGFactory.sol";
import "src/Zappers/Modules/Exchanges/Curve/ICurvePool.sol";
import "src/Zappers/Modules/Exchanges/Curve/ICurveStableswapNGPool.sol";
import "src/Zappers/Modules/Exchanges/CurveExchange.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/ISwapRouter.sol";
import "src/Zappers/Modules/Exchanges/UniV3Exchange.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/INonfungiblePositionManager.sol";
import "src/Zappers/Modules/Exchanges/HybridCurveUniV3Exchange.sol";
import {WETHTester} from "./WETHTester.sol";
import {ERC20Faucet} from "./ERC20Faucet.sol";

import "src/PriceFeeds/WETHPriceFeed.sol";
import "src/PriceFeeds/WSTETHPriceFeed.sol";
import "src/PriceFeeds/RETHPriceFeed.sol";

import "forge-std/console2.sol";

uint256 constant _24_HOURS = 86400;
uint256 constant _48_HOURS = 172800;

// TODO: Split dev and mainnet
contract TestDeployer is MetadataDeployment {
    address constant GOVERNOR_ADDRESS = 0x0000000000000000000000000000000000000000;
    address constant TREASURY_ADDRESS = 0x0000000000000000000000000000000000000000;
    address constant AERO_TOKEN_ADDRESS = 0x0000000000000000000000000000000000000000;

    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IWETH constant WETH_MAINNET = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Curve
    ICurveFactory constant curveFactory = ICurveFactory(0x98EE851a00abeE0d95D08cF4CA2BdCE32aeaAF7F);
    ICurveStableswapNGFactory constant curveStableswapFactory =
        ICurveStableswapNGFactory(0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf);
    uint128 constant BOLD_TOKEN_INDEX = 0;
    uint256 constant COLL_TOKEN_INDEX = 1;
    uint128 constant USDC_INDEX = 1;

    // UniV3
    ISwapRouter constant uniV3Router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    INonfungiblePositionManager constant uniV3PositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    uint24 constant UNIV3_FEE = 3000; // 0.3%
    uint24 constant UNIV3_FEE_USDC_WETH = 500; // 0.05%
    uint24 constant UNIV3_FEE_WETH_COLL = 100; // 0.01%

    bytes32 constant SALT = keccak256("LiquityV2");

    struct LiquityContractsDevPools {
        IDefaultPool defaultPool;
        ICollSurplusPool collSurplusPool;
        GasPool gasPool;
    }

    struct LiquityContractsDev {
        IAddressesRegistry addressesRegistry;
        IBorrowerOperationsTester borrowerOperations; // Tester
        ISortedTroves sortedTroves;
        IActivePool activePool;
        IStabilityPool stabilityPool;
        ITroveManagerTester troveManager; // Tester
        ITroveNFT troveNFT;
        IPriceFeedTestnet priceFeed; // Tester
        IInterestRouter interestRouter;
        IERC20Metadata collToken;
        LiquityContractsDevPools pools;
    }

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
        IPriceFeed priceFeed;
        GasPool gasPool;
        IInterestRouter interestRouter;
        IERC20Metadata collToken;
    }

    struct Zappers {
        WETHZapper wethZapper;
        GasCompZapper gasCompZapper;
        ILeverageZapper leverageZapperCurve;
        ILeverageZapper leverageZapperUniV3;
        ILeverageZapper leverageZapperHybrid;
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

    struct TroveManagerParams {
        uint256 CCR;
        uint256 MCR;
        uint256 BCR;
        uint256 SCR;
        uint256 debtLimit;
        uint256 LIQUIDATION_PENALTY_SP;
        uint256 LIQUIDATION_PENALTY_REDISTRIBUTION;
    }

    struct DeploymentVarsDev {
        uint256 numCollaterals;
        IERC20Metadata[] collaterals;
        IAddressesRegistry[] addressesRegistries;
        ITroveManager[] troveManagers;
        bytes bytecode;
        address boldTokenAddress;
        uint256 i;
    }

    struct DeploymentResultMainnet {
        LiquityContracts[] contractsArray;
        ExternalAddresses externalAddresses;
        CollateralRegistryTester collateralRegistry;
        IBoldToken boldToken;
        IAeroManager aeroManager;
        HintHelpers hintHelpers;
        MultiTroveGetter multiTroveGetter;
        Zappers[] zappersArray;
    }

    struct DeploymentVarsMainnet {
        OracleParams oracleParams;
        uint256 numCollaterals;
        IERC20Metadata[] collaterals;
        IAddressesRegistry[] addressesRegistries;
        ITroveManager[] troveManagers;
        IPriceFeed[] priceFeeds;
        bytes bytecode;
        address boldTokenAddress;
        uint256 i;
    }

    struct DeploymentParamsMainnet {
        uint256 branch;
        IERC20Metadata collToken;
        IPriceFeed priceFeed;
        IBoldToken boldToken;
        ICollateralRegistry collateralRegistry;
        IAeroManager aeroManager;
        IWETH weth;
        IAddressesRegistry addressesRegistry;
        address troveManagerAddress;
        IHintHelpers hintHelpers;
        IMultiTroveGetter multiTroveGetter;
        ICurveStableswapNGPool usdcCurvePool;
        bool isAeroLPCollateral;
        address aeroGaugeAddress;
    }

    struct ExternalAddresses {
        address ETHOracle;
        address STETHOracle;
        address RETHOracle;
        address WSTETHToken;
        address RETHToken;
    }

    struct OracleParams {
        uint256 ethUsdStalenessThreshold;
        uint256 stEthUsdStalenessThreshold;
        uint256 rEthEthStalenessThreshold;
    }

    // See: https://solidity-by-example.org/app/create2/
    function getBytecode(bytes memory _creationCode, address _addressesRegistry) public pure returns (bytes memory) {
        return abi.encodePacked(_creationCode, abi.encode(_addressesRegistry));
    }

    function getBytecode(bytes memory _creationCode, address _addressesRegistry, bool _isAeroLPCollateral, address _aeroGaugeAddress) public pure returns (bytes memory) {
        return abi.encodePacked(_creationCode, abi.encode(_addressesRegistry, _isAeroLPCollateral, _aeroGaugeAddress));
    }

    function getAddress(address _deployer, bytes memory _bytecode, bytes32 _salt) public pure returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), _deployer, _salt, keccak256(_bytecode)));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    function deployAndConnectContracts()
        external
        returns (DeployAndConnectContractsResult memory)
        // returns (
        //     LiquityContractsDev memory contracts,
        //     IAeroManager aeroManager,
        //     ICollateralRegistry collateralRegistry,
        //     IBoldToken boldToken,
        //     HintHelpers hintHelpers,
        //     MultiTroveGetter multiTroveGetter,
        //     IWETH WETH, // for gas compensation
        //     Zappers memory zappers
        // )
    {
        return deployAndConnectContracts(TroveManagerParams(150e16, 110e16, 10e16, 110e16, 5e16, 10e16, 10000 ether));
    }

    struct DeployAndConnectContractsResult {
        LiquityContractsDev contracts;
        IAeroManager aeroManager;
        ICollateralRegistry collateralRegistry;
        IBoldToken boldToken;
        HintHelpers hintHelpers;
        MultiTroveGetter multiTroveGetter;
        IWETH WETH;
        Zappers zappers;
    }

    function deployAndConnectContracts(TroveManagerParams memory troveManagerParams)
        public
        returns (DeployAndConnectContractsResult memory result)
        // returns (
        //     LiquityContractsDev memory, // contractsArray[0] - to prevent stacks too deep
        //     IAeroManager aeroManager,
        //     ICollateralRegistry collateralRegistry,
        //     IBoldToken boldToken,
        //     HintHelpers hintHelpers,
        //     MultiTroveGetter multiTroveGetter,
        //     IWETH WETH, // for gas compensation
        //     Zappers memory // zappersArray[0] - to prevent stacks too deep
        // )
    {
        // LiquityContractsDev[] memory contractsArray;
        TroveManagerParams[] memory troveManagerParamsArray = new TroveManagerParams[](1);
        // Zappers[] memory zappersArray;

        troveManagerParamsArray[0] = troveManagerParams;

        // (contractsArray, result.aeroManager, result.collateralRegistry, result.boldToken, result.hintHelpers, result.multiTroveGetter, result.WETH, zappersArray) =
        //     deployAndConnectContractsMultiColl(troveManagerParamsArray);
        DeployAndConnectContractsMultiCollResult memory deployedContracts = deployAndConnectContractsMultiColl(troveManagerParamsArray);
        result.contracts = deployedContracts.contractsArray[0];
        result.aeroManager = deployedContracts.aeroManager;
        result.collateralRegistry = deployedContracts.collateralRegistry;
        result.boldToken = deployedContracts.boldToken;
        result.hintHelpers = deployedContracts.hintHelpers;
        result.multiTroveGetter = deployedContracts.multiTroveGetter;
        result.WETH = deployedContracts.WETH;
        result.zappers = deployedContracts.zappersArray[0];
        return result;
    }

    struct DeployAndConnectContractsMultiCollResult {
        LiquityContractsDev[] contractsArray;
        IAeroManager aeroManager;
        ICollateralRegistry collateralRegistry;
        IBoldToken boldToken;
        HintHelpers hintHelpers;
        MultiTroveGetter multiTroveGetter;
        IWETH WETH;
        Zappers[] zappersArray;
    }

    function deployAndConnectContractsMultiColl(TroveManagerParams[] memory troveManagerParamsArray)
        public
        returns (DeployAndConnectContractsMultiCollResult memory result)
        // returns (
        //     LiquityContractsDev[] memory contractsArray,
        //     IAeroManager aeroManager,
        //     ICollateralRegistry collateralRegistry,
        //     IBoldToken boldToken,
        //     HintHelpers hintHelpers,
        //     MultiTroveGetter multiTroveGetter,
        //     IWETH WETH, // for gas compensation
        //     Zappers[] memory zappersArray
        // )
    {
        // used for gas compensation and as collateral of the first branch
        result.WETH = new WETHTester(
            100 ether, //     _tapAmount
            1 days //         _tapPeriod
        );
        // (result.contractsArray, result.aeroManager, result.collateralRegistry, result.boldToken, result.hintHelpers, result.multiTroveGetter, result.zappersArray) =
        //     deployAndConnectContracts(troveManagerParamsArray, result.WETH);
        DeployAndConnectContractsResults memory deployedContracts = deployAndConnectContracts(troveManagerParamsArray, result.WETH);
        result.contractsArray = deployedContracts.contractsArray;
        result.aeroManager = deployedContracts.aeroManager;
        result.collateralRegistry = deployedContracts.collateralRegistry;
        result.boldToken = deployedContracts.boldToken;
        result.hintHelpers = deployedContracts.hintHelpers;
        result.multiTroveGetter = deployedContracts.multiTroveGetter;
        result.zappersArray = deployedContracts.zappersArray;
        return result;
    }

    function _nameToken(uint256 _index) internal pure returns (string memory) {
        if (_index == 1) return "Wrapped Staked Ether";
        if (_index == 2) return "Rocket Pool ETH";
        return "LST Tester";
    }

    function _symboltoken(uint256 _index) internal pure returns (string memory) {
        if (_index == 1) return "wstETH";
        if (_index == 2) return "rETH";
        return "LST";
    }

    struct DeployAndConnectContractsResults {
        LiquityContractsDev[] contractsArray;
        IAeroManager aeroManager;
        ICollateralRegistry collateralRegistry;
        IBoldToken boldToken;
        HintHelpers hintHelpers;
        MultiTroveGetter multiTroveGetter;
        Zappers[] zappersArray;
    }

    function deployAndConnectContracts(TroveManagerParams[] memory troveManagerParamsArray, IWETH _WETH)
        public
        returns (DeployAndConnectContractsResults memory result)
        // returns (
        //     LiquityContractsDev[] memory contractsArray,
        //     IAeroManager aeroManager,
        //     ICollateralRegistry collateralRegistry,
        //     IBoldToken boldToken,
        //     HintHelpers hintHelpers,
        //     MultiTroveGetter multiTroveGetter,
        //     Zappers[] memory zappersArray
        // )
    {
        DeploymentVarsDev memory vars;
        vars.numCollaterals = troveManagerParamsArray.length;
        // Deploy Bold
        vars.bytecode = abi.encodePacked(type(BoldToken).creationCode, abi.encode(address(this)));
        vars.boldTokenAddress = getAddress(address(this), vars.bytecode, SALT);
        result.boldToken = new BoldToken{salt: SALT}(address(this));
        assert(address(result.boldToken) == vars.boldTokenAddress);

        result.contractsArray = new LiquityContractsDev[](vars.numCollaterals);
        result.zappersArray = new Zappers[](vars.numCollaterals);
        vars.collaterals = new IERC20Metadata[](vars.numCollaterals);
        vars.addressesRegistries = new IAddressesRegistry[](vars.numCollaterals);
        vars.troveManagers = new ITroveManager[](vars.numCollaterals);

        // Deploy the first branch with WETH collateral
        vars.collaterals[0] = _WETH;
        (IAddressesRegistry addressesRegistry, address troveManagerAddress) =
            _deployAddressesRegistryDev(troveManagerParamsArray[0]);
        vars.addressesRegistries[0] = addressesRegistry;
        vars.troveManagers[0] = ITroveManager(troveManagerAddress);
        for (vars.i = 1; vars.i < vars.numCollaterals; vars.i++) {
            IERC20Metadata collToken = new ERC20Faucet(
                _nameToken(vars.i), // _name
                _symboltoken(vars.i), // _symbol
                100 ether, //     _tapAmount
                1 days //         _tapPeriod
            );
            vars.collaterals[vars.i] = collToken;
            // Addresses registry and TM address
            (addressesRegistry, troveManagerAddress) = _deployAddressesRegistryDev(troveManagerParamsArray[vars.i]);
            vars.addressesRegistries[vars.i] = addressesRegistry;
            vars.troveManagers[vars.i] = ITroveManager(troveManagerAddress);
        }

        result.aeroManager = new AeroManager(AERO_TOKEN_ADDRESS, GOVERNOR_ADDRESS, TREASURY_ADDRESS);
        result.collateralRegistry = new CollateralRegistry(result.boldToken, vars.collaterals, vars.troveManagers, result.aeroManager, GOVERNOR_ADDRESS); //TODO: fix this later
        result.hintHelpers = new HintHelpers(result.collateralRegistry);
        result.multiTroveGetter = new MultiTroveGetter(result.collateralRegistry);

        (result.contractsArray[0], result.zappersArray[0]) = _deployAndConnectCollateralContractsDev(
            _WETH,
            result.boldToken,
            result.collateralRegistry,
            _WETH,
            vars.addressesRegistries[0],
            address(vars.troveManagers[0]),
            result.hintHelpers,
            result.multiTroveGetter,
            AeroParams(result.aeroManager, false, address(0)) // TODO: add isAeroLPCollateral and aero gauge address
        );

        // Deploy the remaining branches with LST collateral
        for (vars.i = 1; vars.i < vars.numCollaterals; vars.i++) {
            (result.contractsArray[vars.i], result.zappersArray[vars.i]) = _deployAndConnectCollateralContractsDev(
                vars.collaterals[vars.i],
                result.boldToken,
                result.collateralRegistry,
                _WETH,
                vars.addressesRegistries[vars.i],
                address(vars.troveManagers[vars.i]),
                result.hintHelpers,
                result.multiTroveGetter,
                AeroParams(result.aeroManager, false, address(0)) // TODO: add isAeroLPCollateral and aero gauge address
            );
        }

        result.boldToken.setCollateralRegistry(address(result.collateralRegistry));
        result.aeroManager.setAddresses(result.collateralRegistry);
    }

    function _deployAddressesRegistryDev(TroveManagerParams memory _troveManagerParams)
        internal
        returns (IAddressesRegistry, address)
    {
        IAddressesRegistry addressesRegistry = new AddressesRegistry(
            address(this),
            _troveManagerParams.CCR,
            _troveManagerParams.MCR,
            _troveManagerParams.BCR,
            _troveManagerParams.SCR,
            _troveManagerParams.debtLimit,
            _troveManagerParams.LIQUIDATION_PENALTY_SP,
            _troveManagerParams.LIQUIDATION_PENALTY_REDISTRIBUTION
        );
        address troveManagerAddress = getAddress(
            address(this), getBytecode(type(TroveManagerTester).creationCode, address(addressesRegistry)), SALT
        );

        return (addressesRegistry, troveManagerAddress);
    }

    struct AeroParams {
        IAeroManager aeroManager;
        bool isAeroLPCollateral;
        address aeroGaugeAddress;
    }

    function _deployAndConnectCollateralContractsDev(
        IERC20Metadata _collToken,
        IBoldToken _boldToken,
        ICollateralRegistry _collateralRegistry,
        IWETH _weth,
        IAddressesRegistry _addressesRegistry,
        address _troveManagerAddress,
        IHintHelpers _hintHelpers,
        IMultiTroveGetter _multiTroveGetter,
        AeroParams memory _aeroParams
    ) internal returns (LiquityContractsDev memory contracts, Zappers memory zappers) {
        LiquityContractAddresses memory addresses;
        contracts.collToken = _collToken;

        // Deploy all contracts, using testers for TM and PriceFeed
        contracts.addressesRegistry = _addressesRegistry;
        contracts.priceFeed = new PriceFeedTestnet();
        contracts.interestRouter = new MockInterestRouter();

        // Deploy Metadata
        MetadataNFT metadataNFT = deployMetadata(SALT);
        addresses.metadataNFT = getAddress(
            address(this), getBytecode(type(MetadataNFT).creationCode, address(initializedFixedAssetReader)), SALT
        );
        assert(address(metadataNFT) == addresses.metadataNFT);

        // Pre-calc addresses
        addresses.borrowerOperations = getAddress(
            address(this),
            getBytecode(type(BorrowerOperationsTester).creationCode, address(contracts.addressesRegistry)),
            SALT
        );
        addresses.troveManager = _troveManagerAddress;
        addresses.troveNFT = getAddress(
            address(this), getBytecode(type(TroveNFT).creationCode, address(contracts.addressesRegistry)), SALT
        );
        addresses.stabilityPool = getAddress(
            address(this), getBytecode(type(StabilityPool).creationCode, address(contracts.addressesRegistry)), SALT
        );
        addresses.activePool = getAddress(
            address(this), getBytecode(type(ActivePool).creationCode, address(contracts.addressesRegistry), _aeroParams.isAeroLPCollateral, _aeroParams.aeroGaugeAddress), SALT
        );
        addresses.defaultPool = getAddress(
            address(this), getBytecode(type(DefaultPool).creationCode, address(contracts.addressesRegistry)), SALT
        );
        addresses.gasPool = getAddress(
            address(this), getBytecode(type(GasPool).creationCode, address(contracts.addressesRegistry)), SALT
        );
        addresses.collSurplusPool = getAddress(
            address(this), getBytecode(type(CollSurplusPool).creationCode, address(contracts.addressesRegistry)), SALT
        );
        addresses.sortedTroves = getAddress(
            address(this), getBytecode(type(SortedTroves).creationCode, address(contracts.addressesRegistry)), SALT
        );

        // Deploy contracts
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
            WETH: _weth,
            aeroManager: _aeroParams.aeroManager
        });
        contracts.addressesRegistry.setAddresses(addressVars);

        contracts.borrowerOperations = new BorrowerOperationsTester{salt: SALT}(contracts.addressesRegistry);
        contracts.troveManager = new TroveManagerTester{salt: SALT}(contracts.addressesRegistry);
        contracts.troveNFT = new TroveNFT{salt: SALT}(contracts.addressesRegistry);
        contracts.stabilityPool = new StabilityPool{salt: SALT}(contracts.addressesRegistry);
        contracts.activePool = new ActivePool{salt: SALT}(contracts.addressesRegistry, _aeroParams.isAeroLPCollateral, _aeroParams.aeroGaugeAddress);
        contracts.pools.defaultPool = new DefaultPool{salt: SALT}(contracts.addressesRegistry);
        contracts.pools.gasPool = new GasPool{salt: SALT}(contracts.addressesRegistry);
        contracts.pools.collSurplusPool = new CollSurplusPool{salt: SALT}(contracts.addressesRegistry);
        contracts.sortedTroves = new SortedTroves{salt: SALT}(contracts.addressesRegistry);

        assert(address(contracts.borrowerOperations) == addresses.borrowerOperations);
        assert(address(contracts.troveManager) == addresses.troveManager);
        assert(address(contracts.troveNFT) == addresses.troveNFT);
        assert(address(contracts.stabilityPool) == addresses.stabilityPool);
        assert(address(contracts.activePool) == addresses.activePool);
        assert(address(contracts.pools.defaultPool) == addresses.defaultPool);
        assert(address(contracts.pools.gasPool) == addresses.gasPool);
        assert(address(contracts.pools.collSurplusPool) == addresses.collSurplusPool);
        assert(address(contracts.sortedTroves) == addresses.sortedTroves);

        // Connect contracts
        _boldToken.setBranchAddresses(
            address(contracts.troveManager),
            address(contracts.stabilityPool),
            address(contracts.borrowerOperations),
            address(contracts.activePool)
        );

        // deploy zappers
        _deployZappers(
            contracts.addressesRegistry,
            contracts.collToken,
            _boldToken,
            _weth,
            contracts.priceFeed,
            ICurveStableswapNGPool(address(0)),
            false,
            zappers
        );
    }

    // Creates individual PriceFeed contracts based on oracle addresses.
    // Still uses mock collaterals rather than real mainnet WETH and LST addresses.

    function deployAndConnectContractsMainnet(TroveManagerParams[] memory _troveManagerParamsArray)
        public
        returns (DeploymentResultMainnet memory result)
    {
        DeploymentVarsMainnet memory vars;

        result.externalAddresses.ETHOracle = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        result.externalAddresses.RETHOracle = 0x536218f9E9Eb48863970252233c8F271f554C2d0;
        result.externalAddresses.STETHOracle = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8;
        result.externalAddresses.WSTETHToken = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

        result.externalAddresses.RETHToken = 0xae78736Cd615f374D3085123A210448E74Fc6393;

        vars.oracleParams.ethUsdStalenessThreshold = _24_HOURS;
        vars.oracleParams.stEthUsdStalenessThreshold = _24_HOURS;
        vars.oracleParams.rEthEthStalenessThreshold = _48_HOURS;

        // Colls: WETH, WSTETH, RETH
        vars.numCollaterals = 3;
        result.contractsArray = new LiquityContracts[](vars.numCollaterals);
        result.zappersArray = new Zappers[](vars.numCollaterals);
        vars.collaterals = new IERC20Metadata[](vars.numCollaterals);
        vars.addressesRegistries = new IAddressesRegistry[](vars.numCollaterals);
        vars.troveManagers = new ITroveManager[](vars.numCollaterals);
        address troveManagerAddress;

        // Deploy Bold
        vars.bytecode = abi.encodePacked(type(BoldToken).creationCode, abi.encode(address(this)));
        vars.boldTokenAddress = getAddress(address(this), vars.bytecode, SALT);
        result.boldToken = new BoldToken{salt: SALT}(address(this));
        assert(address(result.boldToken) == vars.boldTokenAddress);

        // WETH
        IWETH WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        vars.collaterals[0] = WETH;
        (vars.addressesRegistries[0], troveManagerAddress) =
            _deployAddressesRegistryMainnet(_troveManagerParamsArray[0]);
        vars.troveManagers[0] = ITroveManager(troveManagerAddress);

        // RETH
        vars.collaterals[1] = IERC20Metadata(0xae78736Cd615f374D3085123A210448E74Fc6393);
        (vars.addressesRegistries[1], troveManagerAddress) =
            _deployAddressesRegistryMainnet(_troveManagerParamsArray[1]);
        vars.troveManagers[1] = ITroveManager(troveManagerAddress);

        // WSTETH
        vars.collaterals[2] = IERC20Metadata(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        (vars.addressesRegistries[2], troveManagerAddress) =
            _deployAddressesRegistryMainnet(_troveManagerParamsArray[2]);
        vars.troveManagers[2] = ITroveManager(troveManagerAddress);

        // Deploy AeroManager
        result.aeroManager = new AeroManager(AERO_TOKEN_ADDRESS, GOVERNOR_ADDRESS, TREASURY_ADDRESS);

        // Deploy registry and register the TMs
        result.collateralRegistry = new CollateralRegistryTester(result.boldToken, vars.collaterals, vars.troveManagers, result.aeroManager, GOVERNOR_ADDRESS); //TODO: fix this later

        result.hintHelpers = new HintHelpers(result.collateralRegistry);
        result.multiTroveGetter = new MultiTroveGetter(result.collateralRegistry);

        ICurveStableswapNGPool usdcCurvePool = _deployCurveBoldUsdcPool(result.boldToken, true);

        // Deploy each set of core contracts
        for (vars.i = 0; vars.i < vars.numCollaterals; vars.i++) {
            DeploymentParamsMainnet memory params;
            params.branch = vars.i;
            params.collToken = vars.collaterals[vars.i];
            params.boldToken = result.boldToken;
            params.collateralRegistry = result.collateralRegistry;
            params.weth = WETH;
            params.addressesRegistry = vars.addressesRegistries[vars.i];
            params.troveManagerAddress = address(vars.troveManagers[vars.i]);
            params.hintHelpers = result.hintHelpers;
            params.multiTroveGetter = result.multiTroveGetter;
            params.usdcCurvePool = usdcCurvePool;
            params.isAeroLPCollateral = false; // TODO: add isAeroLPCollateral
            params.aeroGaugeAddress = address(0); // TODO: add aero gauge address
            params.aeroManager = result.aeroManager;
            (result.contractsArray[vars.i], result.zappersArray[vars.i]) =
                _deployAndConnectCollateralContractsMainnet(params, result.externalAddresses, vars.oracleParams);
        }

        result.boldToken.setCollateralRegistry(address(result.collateralRegistry));
        result.aeroManager.setAddresses(result.collateralRegistry);
    }

    function _deployAddressesRegistryMainnet(TroveManagerParams memory _troveManagerParams)
        internal
        returns (IAddressesRegistry, address)
    {
        IAddressesRegistry addressesRegistry = new AddressesRegistry(
            address(this),
            _troveManagerParams.CCR,
            _troveManagerParams.MCR,
            _troveManagerParams.BCR,
            _troveManagerParams.SCR,
            _troveManagerParams.debtLimit,
            _troveManagerParams.LIQUIDATION_PENALTY_SP,
            _troveManagerParams.LIQUIDATION_PENALTY_REDISTRIBUTION
        );
        address troveManagerAddress =
            getAddress(address(this), getBytecode(type(TroveManager).creationCode, address(addressesRegistry)), SALT);

        return (addressesRegistry, troveManagerAddress);
    }

    function _deployAndConnectCollateralContractsMainnet(
        DeploymentParamsMainnet memory _params,
        ExternalAddresses memory _externalAddresses,
        OracleParams memory _oracleParams
    ) internal returns (LiquityContracts memory contracts, Zappers memory zappers) {
        LiquityContractAddresses memory addresses;
        contracts.collToken = _params.collToken;
        contracts.interestRouter = new MockInterestRouter();

        contracts.addressesRegistry = _params.addressesRegistry;

        // Deploy Metadata
        MetadataNFT metadataNFT = deployMetadata(SALT);
        addresses.metadataNFT = getAddress(
            address(this), getBytecode(type(MetadataNFT).creationCode, address(initializedFixedAssetReader)), SALT
        );
        assert(address(metadataNFT) == addresses.metadataNFT);

        // Pre-calc addresses
        addresses.borrowerOperations = getAddress(
            address(this),
            getBytecode(type(BorrowerOperationsTester).creationCode, address(contracts.addressesRegistry)),
            SALT
        );
        addresses.troveManager = _params.troveManagerAddress;
        addresses.troveNFT = getAddress(
            address(this), getBytecode(type(TroveNFT).creationCode, address(contracts.addressesRegistry)), SALT
        );
        addresses.stabilityPool = getAddress(
            address(this), getBytecode(type(StabilityPool).creationCode, address(contracts.addressesRegistry)), SALT
        );
        addresses.activePool = getAddress(
            address(this), getBytecode(type(ActivePool).creationCode, address(contracts.addressesRegistry), _params.isAeroLPCollateral, _params.aeroGaugeAddress), SALT
        );
        addresses.defaultPool = getAddress(
            address(this), getBytecode(type(DefaultPool).creationCode, address(contracts.addressesRegistry)), SALT
        );
        addresses.gasPool = getAddress(
            address(this), getBytecode(type(GasPool).creationCode, address(contracts.addressesRegistry)), SALT
        );
        addresses.collSurplusPool = getAddress(
            address(this), getBytecode(type(CollSurplusPool).creationCode, address(contracts.addressesRegistry)), SALT
        );
        addresses.sortedTroves = getAddress(
            address(this), getBytecode(type(SortedTroves).creationCode, address(contracts.addressesRegistry)), SALT
        );

        contracts.priceFeed =
            _deployPriceFeed(_params.branch, _externalAddresses, _oracleParams, addresses.borrowerOperations);

        // Deploy contracts
        IAddressesRegistry.AddressVars memory addressVars = IAddressesRegistry.AddressVars({
            collToken: _params.collToken,
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
            hintHelpers: _params.hintHelpers,
            multiTroveGetter: _params.multiTroveGetter,
            collateralRegistry: _params.collateralRegistry,
            boldToken: _params.boldToken,
            WETH: _params.weth,
            aeroManager: _params.aeroManager
        });
        contracts.addressesRegistry.setAddresses(addressVars);

        contracts.borrowerOperations = new BorrowerOperationsTester{salt: SALT}(contracts.addressesRegistry);
        contracts.troveManager = new TroveManager{salt: SALT}(contracts.addressesRegistry);
        contracts.troveNFT = new TroveNFT{salt: SALT}(contracts.addressesRegistry);
        contracts.stabilityPool = new StabilityPool{salt: SALT}(contracts.addressesRegistry);
        contracts.activePool = new ActivePool{salt: SALT}(contracts.addressesRegistry, _params.isAeroLPCollateral, _params.aeroGaugeAddress);
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

        // Connect contracts
        _params.boldToken.setBranchAddresses(
            address(contracts.troveManager),
            address(contracts.stabilityPool),
            address(contracts.borrowerOperations),
            address(contracts.activePool)
        );

        // deploy zappers
        _deployZappers(
            contracts.addressesRegistry,
            contracts.collToken,
            _params.boldToken,
            _params.weth,
            contracts.priceFeed,
            _params.usdcCurvePool,
            true,
            zappers
        );
    }

    function _deployPriceFeed(
        uint256 _branch,
        ExternalAddresses memory _externalAddresses,
        OracleParams memory _oracleParams,
        address _borrowerOperationsAddress
    ) internal returns (IPriceFeed) {
        //assert(_branch < vars.numCollaterals);
        // Price feeds
        // ETH
        if (_branch == 0) {
            return new WETHPriceFeed(
                _externalAddresses.ETHOracle, _oracleParams.ethUsdStalenessThreshold, _borrowerOperationsAddress
            );
        } else if (_branch == 1) {
            // RETH
            return new RETHPriceFeed(
                _externalAddresses.ETHOracle,
                _externalAddresses.RETHOracle,
                _externalAddresses.RETHToken,
                _oracleParams.ethUsdStalenessThreshold,
                _oracleParams.rEthEthStalenessThreshold,
                _borrowerOperationsAddress
            );
        }

        // wstETH
        return new WSTETHPriceFeed(
            _externalAddresses.ETHOracle,
            _externalAddresses.STETHOracle,
            _externalAddresses.WSTETHToken,
            _oracleParams.ethUsdStalenessThreshold,
            _oracleParams.stEthUsdStalenessThreshold,
            _borrowerOperationsAddress
        );
    }

    function _deployZappers(
        IAddressesRegistry _addressesRegistry,
        IERC20 _collToken,
        IBoldToken _boldToken,
        IWETH _weth,
        IPriceFeed _priceFeed,
        ICurveStableswapNGPool _usdcCurvePool,
        bool _mainnet,
        Zappers memory zappers // result
    ) internal {
        IFlashLoanProvider flashLoanProvider = new BalancerFlashLoan();
        IExchange curveExchange = _deployCurveExchange(_collToken, _boldToken, _priceFeed, _mainnet);

        // TODO: Deploy base zappers versions with Uni V3 exchange
        bool lst = _collToken != _weth;
        if (lst) {
            zappers.gasCompZapper = new GasCompZapper(_addressesRegistry, flashLoanProvider, curveExchange);
        } else {
            zappers.wethZapper = new WETHZapper(_addressesRegistry, flashLoanProvider, curveExchange);
        }

        if (_mainnet) {
            _deployLeverageZappers(
                _addressesRegistry,
                _collToken,
                _boldToken,
                _priceFeed,
                flashLoanProvider,
                curveExchange,
                _usdcCurvePool,
                lst,
                zappers
            );
        }
    }

    function _deployCurveExchange(IERC20 _collToken, IBoldToken _boldToken, IPriceFeed _priceFeed, bool _mainnet)
        internal
        returns (IExchange)
    {
        if (!_mainnet) return new CurveExchange(_collToken, _boldToken, ICurvePool(address(0)), 1, 0);

        (uint256 price,) = _priceFeed.fetchPrice();

        // deploy Curve Twocrypto NG pool
        address[2] memory coins;
        coins[BOLD_TOKEN_INDEX] = address(_boldToken);
        coins[COLL_TOKEN_INDEX] = address(_collToken);
        ICurvePool curvePool = curveFactory.deploy_pool(
            "LST-Bold pool",
            "LBLD",
            coins,
            0, // implementation id
            400000, // A
            145000000000000, // gamma
            26000000, // mid_fee
            45000000, // out_fee
            230000000000000, // fee_gamma
            2000000000000, // allowed_extra_profit
            146000000000000, // adjustment_step
            600, // ma_exp_time
            price // initial_price
        );

        IExchange curveExchange = new CurveExchange(_collToken, _boldToken, curvePool, 1, 0);

        return curveExchange;
    }

    function _deployLeverageZappers(
        IAddressesRegistry _addressesRegistry,
        IERC20 _collToken,
        IBoldToken _boldToken,
        IPriceFeed _priceFeed,
        IFlashLoanProvider _flashLoanProvider,
        IExchange _curveExchange,
        ICurveStableswapNGPool _usdcCurvePool,
        bool _lst,
        Zappers memory zappers // result
    ) internal {
        zappers.leverageZapperCurve =
            _deployCurveLeverageZapper(_addressesRegistry, _flashLoanProvider, _curveExchange, _lst);
        zappers.leverageZapperUniV3 =
            _deployUniV3LeverageZapper(_addressesRegistry, _collToken, _boldToken, _priceFeed, _flashLoanProvider, _lst);
        zappers.leverageZapperHybrid = _deployHybridLeverageZapper(
            _addressesRegistry, _collToken, _boldToken, _flashLoanProvider, _usdcCurvePool, _lst
        );
    }

    function _deployCurveLeverageZapper(
        IAddressesRegistry _addressesRegistry,
        IFlashLoanProvider _flashLoanProvider,
        IExchange _curveExchange,
        bool _lst
    ) internal returns (ILeverageZapper) {
        ILeverageZapper leverageZapperCurve;
        if (_lst) {
            leverageZapperCurve = new LeverageLSTZapper(_addressesRegistry, _flashLoanProvider, _curveExchange);
        } else {
            leverageZapperCurve = new LeverageWETHZapper(_addressesRegistry, _flashLoanProvider, _curveExchange);
        }

        return leverageZapperCurve;
    }

    struct UniV3Vars {
        IExchange uniV3Exchange;
        uint256 price;
        address[2] tokens;
    }

    function _deployUniV3LeverageZapper(
        IAddressesRegistry _addressesRegistry,
        IERC20 _collToken,
        IBoldToken _boldToken,
        IPriceFeed _priceFeed,
        IFlashLoanProvider _flashLoanProvider,
        bool _lst
    ) internal returns (ILeverageZapper) {
        UniV3Vars memory vars;
        vars.uniV3Exchange = new UniV3Exchange(_collToken, _boldToken, UNIV3_FEE, uniV3Router);
        ILeverageZapper leverageZapperUniV3;
        if (_lst) {
            leverageZapperUniV3 = new LeverageLSTZapper(_addressesRegistry, _flashLoanProvider, vars.uniV3Exchange);
        } else {
            leverageZapperUniV3 = new LeverageWETHZapper(_addressesRegistry, _flashLoanProvider, vars.uniV3Exchange);
        }

        // Create Uni V3 pool
        (vars.price,) = _priceFeed.fetchPrice();
        if (address(_boldToken) < address(_collToken)) {
            //console2.log("b < c");
            vars.tokens[0] = address(_boldToken);
            vars.tokens[1] = address(_collToken);
        } else {
            //console2.log("c < b");
            vars.tokens[0] = address(_collToken);
            vars.tokens[1] = address(_boldToken);
        }
        uniV3PositionManager.createAndInitializePoolIfNecessary(
            vars.tokens[0], // token0,
            vars.tokens[1], // token1,
            UNIV3_FEE, // fee,
            UniV3Exchange(address(vars.uniV3Exchange)).priceToSqrtPrice(_boldToken, _collToken, vars.price) // sqrtPriceX96
        );

        return leverageZapperUniV3;
    }

    function _deployHybridLeverageZapper(
        IAddressesRegistry _addressesRegistry,
        IERC20 _collToken,
        IBoldToken _boldToken,
        IFlashLoanProvider _flashLoanProvider,
        ICurveStableswapNGPool _usdcCurvePool,
        bool _lst
    ) internal returns (ILeverageZapper) {
        IExchange hybridExchange = new HybridCurveUniV3Exchange(
            _collToken,
            _boldToken,
            USDC,
            WETH_MAINNET,
            _usdcCurvePool,
            USDC_INDEX, // USDC Curve pool index
            BOLD_TOKEN_INDEX, // BOLD Curve pool index
            UNIV3_FEE_USDC_WETH,
            UNIV3_FEE_WETH_COLL,
            uniV3Router
        );

        ILeverageZapper leverageZapperHybrid;
        if (_lst) {
            leverageZapperHybrid = new LeverageLSTZapper(_addressesRegistry, _flashLoanProvider, hybridExchange);
        } else {
            leverageZapperHybrid = new LeverageWETHZapper(_addressesRegistry, _flashLoanProvider, hybridExchange);
        }

        return leverageZapperHybrid;
    }

    function _deployCurveBoldUsdcPool(IBoldToken _boldToken, bool _mainnet) internal returns (ICurveStableswapNGPool) {
        if (!_mainnet) return ICurveStableswapNGPool(address(0));

        // deploy Curve Stableswap pool
        /*
        address[2] memory coins;
        coins[BOLD_TOKEN_INDEX] = address(_boldToken);
        coins[USDC_INDEX] = address(USDC);
        ICurvePool curvePool = curveStableswapFactory.deploy_plain_pool(
            "USDC-Bold pool",
            "USDCBOLD",
            coins,
            4000, // A
            0, // asset type: USD
            1000000, // fee
            0 // implementation id
        );
        */
        // deploy Curve StableswapNG pool
        address[] memory coins = new address[](2);
        coins[BOLD_TOKEN_INDEX] = address(_boldToken);
        coins[USDC_INDEX] = address(USDC);
        uint8[] memory assetTypes = new uint8[](2); // 0: standard
        bytes4[] memory methodIds = new bytes4[](2);
        address[] memory oracles = new address[](2);
        ICurveStableswapNGPool curvePool = curveStableswapFactory.deploy_plain_pool(
            "USDC-BOLD",
            "USDCBOLD",
            coins,
            4000, // A
            1000000, // fee
            20000000000, // _offpeg_fee_multiplier
            865, // _ma_exp_time
            0, // implementation id
            assetTypes,
            methodIds,
            oracles
        );

        return curvePool;
    }
}
