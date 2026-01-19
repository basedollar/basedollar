// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "./Interfaces/IActivePool.sol";
import "./Interfaces/ICollateralRegistry.sol";
import "./Interfaces/IAeroManager.sol";
import "./Interfaces/IAeroGauge.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/Constants.sol";

contract AeroManager is IAeroManager, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct AeroRecipient {
        address borrower;
        uint256 amount;
    }

    ICollateralRegistry public collateralRegistry;
    address public aeroTokenAddress;
    address public governor;

    address public treasuryAddress;

    mapping(address gauge => uint256) public stakedAmounts;
    mapping(address activePool => bool) public activePools;

    mapping(address gauge => uint256 epoch) public currentEpochs;
    mapping(uint256 epoch => mapping(address gauge => uint256 amount)) public claimedAeroPerEpoch;

    mapping(address user => uint256 amount) public claimableRewards;

    uint256 public claimedAero;
    
    uint256 public claimFee;

    uint256 public pendingNewClaimFee;

    uint256 public pendingNewClaimFeeTimestamp;
    
    uint256 public claimFeeChangeDelayPeriod = 7 days;

    event Staked(address indexed gauge, address token, uint256 amount);
    event ActivePoolAdded(address indexed activePool);
    event Claimed(address indexed gauge, uint256 total, uint256 claimFee, uint256 indexed epoch);
    event AeroDistributed(address indexed gauge, uint256 recipients, uint256 totalRewardAmount, uint256 indexed epoch);
    event RewardsClaimed(address indexed user, uint256 amount);
    event CollateralRegistryAdded(address collateralRegistry);
    event ClaimFeeUpdated(uint256 oldFee, uint256 newFee);
    event ClaimFeeUpdatePending(uint256 oldFee, uint256 newFee, uint256 timestamp, uint256 delayPeriod);

    constructor(address _aeroTokenAddress, address _governor, address _treasuryAddress) Ownable(msg.sender) {
        require(_treasuryAddress != address(0), "AeroManager: Treasury address cannot be 0");
        require(_aeroTokenAddress != address(0), "AeroManager: Aero token address cannot be 0");
        _requireClaimFeeLimit(AERO_MANAGER_FEE);

        aeroTokenAddress = _aeroTokenAddress;
        governor = _governor;
        treasuryAddress = _treasuryAddress;
        claimFee = AERO_MANAGER_FEE;
    }

    //require functions
    modifier onlyGovernor() {
        require(msg.sender == governor, "AeroManager: Caller is not the governor");
        _;
    }

    //Manage Aero, Interact with gauges, anything else we need to do here.

    // This function is only called once by the deployer
    function setAddresses(ICollateralRegistry _collateralRegistry) external onlyOwner {
        require(address(_collateralRegistry) != address(0), "AeroManager: Collateral registry cannot be 0");

        collateralRegistry = _collateralRegistry;
        emit CollateralRegistryAdded(address(_collateralRegistry));

        // Add all activepools from collateral registry
        ITroveManager[] memory redeemableTroveManagers = _collateralRegistry.getTroveManagers();
        ITroveManager[] memory nonRedeemableTroveManagers = _collateralRegistry.getNonRedeemableTroveManagers();
        for (uint256 i; i < redeemableTroveManagers.length; i++) {
            IActivePool activePool = IActivePool(redeemableTroveManagers[i].activePool());
            if (activePool.isAeroLPCollateral()) {
                _addActivePool(address(activePool));
            }
        }
        for (uint256 i; i < nonRedeemableTroveManagers.length; i++) {
            IActivePool activePool = IActivePool(nonRedeemableTroveManagers[i].activePool());
            if (activePool.isAeroLPCollateral()) {
                _addActivePool(address(activePool));
            }
        }

        _renounceOwnership();
    }

    //admin functions
    function setAeroTokenAddress(address _aeroTokenAddress) external onlyGovernor {
        aeroTokenAddress = _aeroTokenAddress;
        emit AeroTokenAddressUpdated(_aeroTokenAddress);
    }

    function setGovernor(address _governor) external onlyGovernor {
        governor = _governor;
        emit GovernorUpdated(_governor);
    }

    function addActivePool(address activePool) external {
        _requireCallerIsCollateralRegistry();
        _addActivePool(activePool);
    }

    //TODO vote with AERO tokens on any gauges that governance chooses.

    // MAYBE TODO?:
    // Users claim their AERO rewards directly here
    // When users claim, a percentage is sent to timelock treasury address
    // For this, add a mapping of claim amounts for each user based on their collateral amount, collateral type (APY differs depending on LP token), + interest rate, etc.

    // AeroManager stakes and claims AERO on behalf of all non-redeemable branches (that are LP token collaterals)
    function stake(address gauge, address token, uint256 amount) external {
        _requireCallerIsActivePool();

        // Pull LP tokens from ActivePool
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        // Stake LP tokens into AeroGauge
        IAeroGauge(gauge).deposit(amount);
        // Log amount staked
        stakedAmounts[gauge] += amount;
        emit Staked(gauge, token, amount);
    }

    function withdraw(address gauge, address token, uint256 amount) external {
        _requireCallerIsActivePool();
        // Withdraw LP tokens from AeroGauge
        IAeroGauge(gauge).withdraw(amount);
        // Transfer LP tokens to ActivePool
        IERC20(token).safeTransfer(msg.sender, amount);
        // Log amount withdrawn
        stakedAmounts[gauge] -= amount;
    }

    function claim(address gauge) external nonReentrant {
        // Claim AERO from AeroGauge
        uint256 preBalance = IERC20(aeroTokenAddress).balanceOf(address(this));
        IAeroGauge(gauge).getReward(address(this));
        uint256 postBalance = IERC20(aeroTokenAddress).balanceOf(address(this));
        uint256 claimedAmount = postBalance - preBalance;

        // Send a percentage of AERO to timelock treasury address
        uint256 _claimFee = _getClaimFee(claimedAmount);
        IERC20(aeroTokenAddress).safeTransfer(treasuryAddress, _claimFee);

        // Keep the remaining AERO for the AeroManager (this will be distributed to users later)
        uint256 rewardAmount = claimedAmount - _claimFee;
        claimedAero += rewardAmount; // Subtract the fee from the total claimed amount
        
        uint256 currentEpoch = currentEpochs[gauge];
        claimedAeroPerEpoch[currentEpoch][gauge] += rewardAmount;

        emit Claimed(gauge, claimedAmount, _claimFee, currentEpoch);
    }

    function distributeAero(address gauge, AeroRecipient[] memory recipients) external onlyGovernor {
        require(recipients.length > 0, "AeroManager: No recipients");
        uint256 currentEpoch = currentEpochs[gauge];
        uint256 rewardAmount = claimedAeroPerEpoch[currentEpoch][gauge];
        for (uint256 i; i < recipients.length; i++) {
            require(recipients[i].amount <= rewardAmount, "AeroManager: Total amount exceeds reward amount");
            rewardAmount -= recipients[i].amount;
            claimableRewards[recipients[i].borrower] += recipients[i].amount;
        }
        require(rewardAmount == 0, "AeroManager: Reward amount not fully distributed");
        emit AeroDistributed(gauge, recipients.length, rewardAmount, currentEpoch);
        currentEpoch++;
        currentEpochs[gauge] = currentEpoch;
    }

    function claimRewards(address user) external nonReentrant {
        uint256 amount = claimableRewards[user];
        require(amount > 0, "AeroManager: No rewards to claim");
        claimableRewards[user] = 0;
        IERC20(aeroTokenAddress).safeTransfer(user, amount);
        emit RewardsClaimed(user, amount);
    }

    function updateClaimFee(uint256 newFee) external onlyGovernor {
        require(newFee != claimFee, "AeroManager: New fee is the same as the current fee");
        _requireClaimFeeLimit(newFee);
        if (newFee > claimFee) {
            pendingNewClaimFee = newFee;
            pendingNewClaimFeeTimestamp = block.timestamp;
            emit ClaimFeeUpdatePending(claimFee, newFee, pendingNewClaimFeeTimestamp, claimFeeChangeDelayPeriod);
        } else {
            uint256 oldFee = claimFee;
            claimFee = newFee;
            emit ClaimFeeUpdated(oldFee, newFee);
        }
    }

    function acceptClaimFeeUpdate() external onlyGovernor {
        require(pendingNewClaimFee > 0, "AeroManager: No pending claim fee update");
        require(block.timestamp >= pendingNewClaimFeeTimestamp + claimFeeChangeDelayPeriod, "AeroManager: Claim fee update delay period not passed");
        uint256 oldFee = claimFee;
        claimFee = pendingNewClaimFee;
        pendingNewClaimFee = 0;
        pendingNewClaimFeeTimestamp = 0;
        emit ClaimFeeUpdated(oldFee, claimFee);
    }

    // Fee is a percentage of the total claimed amount
    // _100pct is 1e18, so AERO_MANAGER_FEE is 10 * _1pct = 10e16
    function _getClaimFee(uint256 amount) internal view returns (uint256) {
        return amount * claimFee / _100pct;
    }


    function _addActivePool(address activePool) internal {
        require(!activePools[activePool], "AeroManager: ActivePool already added");

        // Double check stakingToken and rewardToken addresses from ActivePool matches in Gauge
        IActivePool ap = IActivePool(activePool);
        require(ap.isAeroLPCollateral(), "AeroManager: ActivePool is not an AERO LP collateral");
        require(ap.aeroManagerAddress() == address(this), "AeroManager: ActivePool is not linked to this AeroManager");

        IAeroGauge gauge = IAeroGauge(ap.aeroGaugeAddress());
        require(gauge.stakingToken() == address(ap.collToken()), "AeroManager: Staking token does not match");
        require(gauge.rewardToken() == aeroTokenAddress, "AeroManager: Reward token does not match");

        activePools[activePool] = true;
        emit ActivePoolAdded(activePool);
    }

    function _requireClaimFeeLimit(uint256 newFee) internal view {
        require(newFee <= MAX_AERO_MANAGER_FEE, "AeroManager: Fee is greater than max aero manager fee limit");
    }

    function _requireCallerIsActivePool() internal view {
        require(activePools[msg.sender], "AeroManager: Caller is not an active pool");
    }

    function _requireCallerIsCollateralRegistry() internal view {
        require(msg.sender == address(collateralRegistry), "AeroManager: Caller is not the collateral registry");
    }
}