// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {AddressesRegistry} from "src/AddressesRegistry.sol";
import {ActivePool} from "src/ActivePool.sol";
import {AeroTroveManager} from "src/AeroTroveManager.sol";
import {BoldToken} from "src/BoldToken.sol";
import {BorrowerOperations} from "src/BorrowerOperations.sol";
import {CollSurplusPool} from "src/CollSurplusPool.sol";
import {CollateralRegistry} from "src/CollateralRegistry.sol";
import {DefaultPool} from "src/DefaultPool.sol";
import {GasPool} from "src/GasPool.sol";
import {IAddressesRegistry} from "src/Interfaces/IAddressesRegistry.sol";
import {AEROPriceFeed} from "src/PriceFeeds/AEROPriceFeed.sol";
import {SortedTroves} from "src/SortedTroves.sol";
import {StabilityPool} from "src/StabilityPool.sol";
import {TroveNFT} from "src/TroveNFT.sol";
import {
    BCR_ALL,
    CCR_AERO,
    MCR_AERO,
    SCR_AERO,
    DEBT_LIMIT_AERO,
    LIQUIDATION_PENALTY_SP_AERO,
    LIQUIDATION_PENALTY_REDISTRIBUTION_AERO
} from "src/Dependencies/Constants.sol";

/// @notice Deploys an AERO token branch against an existing Base Dollar deployment.
/// @dev Registration is a separate collateral-governor action unless the broadcaster is that governor.
contract DeployAeroBranch is Script {
    address internal constant BASE_AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address internal constant BASE_AERO_USD_ORACLE = 0x6C655693f733FB26EA28e7757DD4a5Ad59061e75;

    struct Config {
        CollateralRegistry collateralRegistry;
        IAddressesRegistry referenceRegistry;
        IERC20Metadata aero;
        address oracle;
        address deployer;
        address nftGovernor;
        bytes32 salt;
        uint256 oracleStaleness;
        bool registerBranch;
    }

    struct BranchAddresses {
        address borrowerOperations;
        address troveManager;
        address troveNFT;
        address stabilityPool;
        address activePool;
        address defaultPool;
        address gasPool;
        address collSurplusPool;
        address sortedTroves;
    }

    function run() external returns (IAddressesRegistry branchRegistry) {
        require(block.chainid == 8453, "AERO branch: Base only");

        uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        Config memory config = Config({
            collateralRegistry: CollateralRegistry(vm.envAddress("COLLATERAL_REGISTRY")),
            referenceRegistry: IAddressesRegistry(vm.envAddress("REFERENCE_ADDRESSES_REGISTRY")),
            aero: IERC20Metadata(vm.envOr("AERO_TOKEN", BASE_AERO)),
            oracle: vm.envOr("AERO_USD_ORACLE", BASE_AERO_USD_ORACLE),
            deployer: vm.addr(privateKey),
            nftGovernor: address(0),
            salt: vm.envBytes32("AERO_BRANCH_SALT"),
            oracleStaleness: vm.envOr("AERO_ORACLE_STALENESS", uint256(25 hours)),
            registerBranch: vm.envOr("REGISTER_BRANCH", false)
        });

        _validate(config);
        config.nftGovernor = TroveNFT(address(config.referenceRegistry.troveNFT())).governor();
        require(config.nftGovernor != address(0), "AERO branch: NFT governor missing");

        vm.startBroadcast(privateKey);
        BranchAddresses memory branch;
        address priceFeed;
        (branchRegistry, branch, priceFeed) = _deploy(config);
        if (config.registerBranch) {
            config.collateralRegistry.createNewBranch(branchRegistry, true);
        }
        vm.stopBroadcast();

        console2.log("AERO AddressesRegistry:", address(branchRegistry));
        console2.log("AERO TroveManager:", branch.troveManager);
        console2.log("AERO PriceFeed:", priceFeed);
        console2.log("CollateralRegistry:", address(config.collateralRegistry));
        console2.log("Registered:", config.registerBranch);
        if (!config.registerBranch) {
            console2.log("Collateral governor calldata for createNewBranch(registry, true):");
            console2.logBytes(abi.encodeCall(CollateralRegistry.createNewBranch, (branchRegistry, true)));
        }
    }

    function _validate(Config memory config) internal view {
        require(address(config.collateralRegistry).code.length > 0, "AERO branch: registry missing");
        require(address(config.referenceRegistry).code.length > 0, "AERO branch: reference missing");
        require(address(config.aero).code.length > 0, "AERO branch: token missing");
        require(config.oracle.code.length > 0, "AERO branch: oracle missing");
        require(config.oracleStaleness > 0, "AERO branch: oracle staleness is zero");
        require(config.aero.decimals() == 18, "AERO branch: token must have 18 decimals");
        require(
            address(config.referenceRegistry.collateralRegistry()) == address(config.collateralRegistry),
            "AERO branch: wrong reference registry"
        );
        require(
            address(config.referenceRegistry.boldToken()) == address(config.collateralRegistry.boldToken()),
            "AERO branch: wrong BOLD token"
        );
        require(
            address(config.referenceRegistry.aeroManager()) == address(config.collateralRegistry.aeroManager()),
            "AERO branch: wrong AeroManager"
        );
        require(address(config.referenceRegistry.metadataNFT()).code.length > 0, "AERO branch: metadata missing");
        require(
            address(config.referenceRegistry.interestRouter()) != address(0), "AERO branch: interest router missing"
        );
        require(
            BoldToken(address(config.collateralRegistry.boldToken())).collateralRegistryAddress()
                == address(config.collateralRegistry),
            "AERO branch: BOLD points to another registry"
        );
        if (config.registerBranch) {
            require(
                config.deployer == config.collateralRegistry.collateralGovernor(),
                "AERO branch: deployer is not collateral governor"
            );
        }

        uint256 redeemableCount = config.collateralRegistry.getTroveManagers().length;
        require(redeemableCount < 10, "AERO branch: redeemable branch limit reached");
        for (uint256 i = 0; i < redeemableCount; i++) {
            require(
                address(config.collateralRegistry.getToken(i)) != address(config.aero),
                "AERO branch: token already registered"
            );
        }
        uint256 nonRedeemableCount = config.collateralRegistry.getNonRedeemableTroveManagers().length;
        for (uint256 i = 0; i < nonRedeemableCount; i++) {
            require(
                address(config.collateralRegistry.getNonRedeemableToken(i)) != address(config.aero),
                "AERO branch: token already registered"
            );
        }
    }

    function _deploy(Config memory config)
        internal
        returns (IAddressesRegistry branchRegistry, BranchAddresses memory branch, address priceFeed)
    {
        branchRegistry = new AddressesRegistry(
            config.deployer,
            CCR_AERO,
            MCR_AERO,
            BCR_ALL,
            SCR_AERO,
            DEBT_LIMIT_AERO,
            LIQUIDATION_PENALTY_SP_AERO,
            LIQUIDATION_PENALTY_REDISTRIBUTION_AERO
        );

        branch = _predict(branchRegistry, config.nftGovernor, config.salt);
        AEROPriceFeed feed = new AEROPriceFeed(branch.borrowerOperations, config.oracle, config.oracleStaleness);
        priceFeed = address(feed);

        IAddressesRegistry.AddressVars memory vars;
        vars.collToken = config.aero;
        vars.borrowerOperations = BorrowerOperations(branch.borrowerOperations);
        vars.troveManager = AeroTroveManager(branch.troveManager);
        vars.troveNFT = TroveNFT(branch.troveNFT);
        vars.metadataNFT = config.referenceRegistry.metadataNFT();
        vars.stabilityPool = StabilityPool(branch.stabilityPool);
        vars.priceFeed = feed;
        vars.activePool = ActivePool(branch.activePool);
        vars.defaultPool = DefaultPool(branch.defaultPool);
        vars.gasPoolAddress = branch.gasPool;
        vars.collSurplusPool = CollSurplusPool(branch.collSurplusPool);
        vars.sortedTroves = SortedTroves(branch.sortedTroves);
        vars.interestRouter = config.referenceRegistry.interestRouter();
        vars.hintHelpers = config.referenceRegistry.hintHelpers();
        vars.multiTroveGetter = config.referenceRegistry.multiTroveGetter();
        vars.collateralRegistry = config.collateralRegistry;
        vars.boldToken = config.collateralRegistry.boldToken();
        vars.WETH = config.referenceRegistry.WETH();
        vars.aeroManager = config.collateralRegistry.aeroManager();
        branchRegistry.setAddresses(vars);

        require(
            address(new BorrowerOperations{salt: config.salt}(branchRegistry, false)) == branch.borrowerOperations,
            "AERO branch: BorrowerOperations address mismatch"
        );
        require(
            address(new AeroTroveManager{salt: config.salt}(branchRegistry)) == branch.troveManager,
            "AERO branch: TroveManager address mismatch"
        );
        require(
            address(new TroveNFT{salt: config.salt}(branchRegistry, config.nftGovernor)) == branch.troveNFT,
            "AERO branch: TroveNFT address mismatch"
        );
        require(
            address(new StabilityPool{salt: config.salt}(branchRegistry)) == branch.stabilityPool,
            "AERO branch: StabilityPool address mismatch"
        );
        require(
            address(new ActivePool{salt: config.salt}(branchRegistry, false, address(0))) == branch.activePool,
            "AERO branch: ActivePool address mismatch"
        );
        require(
            address(new DefaultPool{salt: config.salt}(branchRegistry)) == branch.defaultPool,
            "AERO branch: DefaultPool address mismatch"
        );
        require(
            address(new GasPool{salt: config.salt}(branchRegistry)) == branch.gasPool,
            "AERO branch: GasPool address mismatch"
        );
        require(
            address(new CollSurplusPool{salt: config.salt}(branchRegistry)) == branch.collSurplusPool,
            "AERO branch: CollSurplusPool address mismatch"
        );
        require(
            address(new SortedTroves{salt: config.salt}(branchRegistry)) == branch.sortedTroves,
            "AERO branch: SortedTroves address mismatch"
        );
    }

    function _predict(IAddressesRegistry registry, address nftGovernor, bytes32 salt)
        internal
        pure
        returns (BranchAddresses memory branch)
    {
        branch.borrowerOperations = _compute(salt, type(BorrowerOperations).creationCode, abi.encode(registry, false));
        branch.troveManager = _compute(salt, type(AeroTroveManager).creationCode, abi.encode(registry));
        branch.troveNFT = _compute(salt, type(TroveNFT).creationCode, abi.encode(registry, nftGovernor));
        branch.stabilityPool = _compute(salt, type(StabilityPool).creationCode, abi.encode(registry));
        branch.activePool = _compute(salt, type(ActivePool).creationCode, abi.encode(registry, false, address(0)));
        branch.defaultPool = _compute(salt, type(DefaultPool).creationCode, abi.encode(registry));
        branch.gasPool = _compute(salt, type(GasPool).creationCode, abi.encode(registry));
        branch.collSurplusPool = _compute(salt, type(CollSurplusPool).creationCode, abi.encode(registry));
        branch.sortedTroves = _compute(salt, type(SortedTroves).creationCode, abi.encode(registry));
    }

    function _compute(bytes32 salt, bytes memory creationCode, bytes memory args) internal pure returns (address) {
        return vm.computeCreate2Address(salt, keccak256(bytes.concat(creationCode, args)));
    }
}
