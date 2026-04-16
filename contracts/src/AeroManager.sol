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

/// @title AeroManager
/// @notice Stakes Aero LP collateral in gauges, claims AERO rewards, routes a configurable fee to treasury, and lets governance split the remainder across borrowers for withdrawal via `claimRewards`.
contract AeroManager is IAeroManager, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /// @param borrower Trove owner address credited in `claimableRewards`
    /// @param amount AERO amount assigned to that borrower for the closed epoch
    struct AeroRecipient {
        address borrower;
        uint256 amount;
    }

    ICollateralRegistry public collateralRegistry;
    address public aeroTokenAddress;
    address public pendingAeroTokenAddress;
    uint256 public pendingAeroTokenAddressTimestamp;
    address public governor;

    address public treasuryAddress;

    mapping(address gauge => uint256) public stakedAmounts;
    mapping(address activePool => bool) public activePools;

    mapping(address gauge => uint256 epoch) public currentEpochs;
    mapping(address gauge => mapping(uint256 epoch => bool isClosed)) public epochClosed;
    mapping(uint256 epoch => mapping(address gauge => uint256 amount)) public claimedAeroPerEpoch;

    mapping(address user => uint256 amount) public claimableRewards;

    /// @notice Cumulative AERO retained by this contract after treasury fees are deducted
    uint256 public claimedAero;

    /// @notice Fee on gauge claims, expressed as a fraction of `_100pct` (1e18 = 100%)
    uint256 public claimFee;

    uint256 public pendingNewClaimFee;

    uint256 public pendingNewClaimFeeTimestamp;

    /// @notice Delay before a pending fee increase or AERO token address change can be accepted
    uint256 public claimFeeChangeDelayPeriod = 7 days;
    uint256 public aeroTokenChangeDelayPeriod = 7 days;

    event Staked(address indexed gauge, address token, uint256 amount);
    event ActivePoolAdded(address indexed activePool);
    event Claimed(address indexed gauge, uint256 total, uint256 claimFee, uint256 indexed epoch);
    event AeroDistributed(address indexed gauge, uint256 recipients, uint256 totalRewardAmount, uint256 indexed epoch);
    event RewardsClaimed(address indexed user, uint256 amount);
    event CollateralRegistryAdded(address collateralRegistry);
    event ClaimFeeUpdated(uint256 oldFee, uint256 newFee);
    event ClaimFeeUpdatePending(uint256 oldFee, uint256 newFee, uint256 timestamp, uint256 delayPeriod);
    event AeroTokenAddressUpdated(address oldAeroTokenAddress, address newAeroTokenAddress);
    event AeroTokenAddressUpdatePending(address oldAeroTokenAddress, address newAeroTokenAddress, uint256 timestamp, uint256 delayPeriod);
    event EpochClosed(address indexed gauge, uint256 indexed epoch);

    /// @param _aeroTokenAddress AERO (reward) token the gauges must pay out
    /// @param _governor Account allowed to change token address, fee, epochs, and distributions
    /// @param _treasuryAddress Recipient of the claim fee portion of each `claim`
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

    /// @notice One-time wiring to the collateral registry and its current list of all Aero LP active pools, then renounces ownership
    /// @param _collateralRegistry Collateral registry
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

    /// @notice Set a new pending AERO token address
    /// @dev The new address becomes active after the timelock elapses and accepted by the governor
    /// @param _aeroTokenAddress New reward token address to use after acceptance
    function setAeroTokenAddress(address _aeroTokenAddress) external onlyGovernor {
        require(_aeroTokenAddress != address(0), "AeroManager: Aero token address cannot be 0");
        require(aeroTokenAddress != _aeroTokenAddress, "AeroManager: New aero token address is the same as the current aero token address");

        pendingAeroTokenAddress = _aeroTokenAddress;
        pendingAeroTokenAddressTimestamp = block.timestamp;
        emit AeroTokenAddressUpdatePending(aeroTokenAddress, _aeroTokenAddress, block.timestamp, aeroTokenChangeDelayPeriod);
    }

    /// @notice Finalize a pending AERO token address after the timelock elapses
    function acceptAeroTokenAddressUpdate() external onlyGovernor {
        require(pendingAeroTokenAddress != address(0), "AeroManager: No pending aero token address update");
        require(block.timestamp >= pendingAeroTokenAddressTimestamp + aeroTokenChangeDelayPeriod, "AeroManager: Aero token address update delay period not passed");
        address oldAeroTokenAddress = aeroTokenAddress;
        aeroTokenAddress = pendingAeroTokenAddress;
        pendingAeroTokenAddress = address(0);
        pendingAeroTokenAddressTimestamp = 0;
        emit AeroTokenAddressUpdated(oldAeroTokenAddress, aeroTokenAddress);
    }

    /// @notice Transfer governor role to a new account
    /// @param _governor New governor address
    function setGovernor(address _governor) external onlyGovernor {
        governor = _governor;
        emit GovernorUpdated(_governor);
    }

    /// @notice Add an `ActivePool` of an AERO LP collateral type by the collateral registry
    /// @param activePool Address of the `ActivePool` to add
    function addActivePool(address activePool) external {
        _requireCallerIsCollateralRegistry();
        _addActivePool(activePool);
    }

    //TODO vote with AERO tokens on any gauges that governance chooses.

    // MAYBE TODO?:
    // Users claim their AERO rewards directly here
    // When users claim, a percentage is sent to timelock treasury address
    // For this, add a mapping of claim amounts for each user based on their collateral amount, collateral type (APY differs depending on LP token), + interest rate, etc.

    /// @notice Pull LP token amount from ActivePool and stake into gauge
    /// @dev AeroManager stakes and claims AERO on behalf of all non-redeemable branches (that are LP token collaterals)
    /// @param gauge Aero gauge staking `token`
    /// @param token LP token address (must match the pool collateral token)
    /// @param amount LP amount to stake
    function stake(address gauge, address token, uint256 amount) external {
        _requireCallerIsActivePool();

        // Pull LP tokens from ActivePool
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        // Allow the gauge to pull tokens from the AeroManager on deposit()
        IERC20(token).safeIncreaseAllowance(gauge, amount);
        // Stake LP tokens into AeroGauge
        IAeroGauge(gauge).deposit(amount);
        // Log amount staked
        stakedAmounts[gauge] += amount;
        emit Staked(gauge, token, amount);
    }

    /// @notice Withdraw LP from the gauge and return it to the caller `ActivePool`
    /// @param gauge Aero gauge the LP was staked in
    /// @param token LP token being returned
    /// @param amount LP amount to withdraw
    function withdraw(address gauge, address token, uint256 amount) external {
        _requireCallerIsActivePool();
        // Withdraw LP tokens from AeroGauge
        IAeroGauge(gauge).withdraw(amount);
        // Transfer LP tokens to ActivePool
        IERC20(token).safeTransfer(msg.sender, amount);
        // Log amount withdrawn
        stakedAmounts[gauge] -= amount;
    }

    /// @notice Pull accrued AERO from a gauge, pay the treasury fee, and credit the net to the current epoch bucket
    /// @dev Callable by anyone; reverts if the gauge's current epoch is already closed or reward token mismatches `aeroTokenAddress`
    /// @param gauge Gauge to claim rewards from
    function claim(address gauge) external nonReentrant {
        uint256 currentEpoch = currentEpochs[gauge];
        require(!epochClosed[gauge][currentEpoch], "AeroManager: Current epoch is already closed");
        require(IAeroGauge(gauge).rewardToken() == aeroTokenAddress, "AeroManager: Reward token does not match");

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
        
        claimedAeroPerEpoch[currentEpoch][gauge] += rewardAmount;

        emit Claimed(gauge, claimedAmount, _claimFee, currentEpoch);
    }

    /// @notice Mark the gauge's current epoch closed so its rewards can be distributed
    /// @param gauge Gauge whose `currentEpochs[gauge]` is sealed
    function closeCurrentEpoch(address gauge) external onlyGovernor {
        uint256 currentEpoch = currentEpochs[gauge];
        require(!epochClosed[gauge][currentEpoch], "AeroManager: Current epoch is already closed");
        epochClosed[gauge][currentEpoch] = true;
        emit EpochClosed(gauge, currentEpoch);
    }

    /// @notice Split a closed epoch's AERO for `gauge` across borrowers; advances the gauge epoch when the bucket is fully allocated
    /// @dev Sum of `recipients[i].amount` must equal `claimedAeroPerEpoch[currentEpoch][gauge]` for that gauge/epoch
    /// @param gauge Gauge whose closed epoch is being paid out
    /// @param recipients Borrower addresses and AERO amounts; must exhaust the epoch balance exactly
    function distributeAero(address gauge, AeroRecipient[] memory recipients) external onlyGovernor {
        uint256 currentEpoch = currentEpochs[gauge];
        require(epochClosed[gauge][currentEpoch], "AeroManager: Current epoch is not closed yet to distribute rewards");
        require(recipients.length > 0, "AeroManager: No recipients");
        
        uint256 rewardAmount = claimedAeroPerEpoch[currentEpoch][gauge];
        uint256 remainingRewardAmount = rewardAmount;
        for (uint256 i; i < recipients.length; i++) {
            require(recipients[i].amount <= remainingRewardAmount, "AeroManager: Total amount exceeds reward amount");
            remainingRewardAmount -= recipients[i].amount;
            claimableRewards[recipients[i].borrower] += recipients[i].amount;
        }
        require(remainingRewardAmount == 0, "AeroManager: Reward amount not fully distributed");
        emit AeroDistributed(gauge, recipients.length, rewardAmount, currentEpoch);
        currentEpoch++;
        currentEpochs[gauge] = currentEpoch;
    }

    /// @notice Withdraw previously allocated AERO for `user` (via `distributeAero`) to the user wallet
    /// @param user Account that received a credit in `claimableRewards`
    function claimRewards(address user) external nonReentrant {
        uint256 amount = claimableRewards[user];
        require(amount > 0, "AeroManager: No rewards to claim");
        claimableRewards[user] = 0;
        IERC20(aeroTokenAddress).safeTransfer(user, amount);
        emit RewardsClaimed(user, amount);
    }

    /// @notice Update the treasury cut on gauge claims; increases are delayed, decreases apply immediately
    /// @param newFee New fee as a fraction of `_100pct`, capped by `MAX_AERO_MANAGER_FEE`
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

    /// @notice Finalize a pending fee increase after `claimFeeChangeDelayPeriod`
    function acceptClaimFeeUpdate() external onlyGovernor {
        require(pendingNewClaimFee > 0, "AeroManager: No pending claim fee update");
        require(block.timestamp >= pendingNewClaimFeeTimestamp + claimFeeChangeDelayPeriod, "AeroManager: Claim fee update delay period not passed");
        uint256 oldFee = claimFee;
        claimFee = pendingNewClaimFee;
        pendingNewClaimFee = 0;
        pendingNewClaimFeeTimestamp = 0;
        emit ClaimFeeUpdated(oldFee, claimFee);
    }

    /// @notice Treasury fee as percentage of total claimed amount (`amount * claimFee / _100pct`)
    /// _100pct is 1e18, so AERO_MANAGER_FEE is 10 * _1pct = 10e16
    /// @param amount Total AERO claimed from the gauge in this transaction
    /// @return Fee portion sent to `treasuryAddress`
    function _getClaimFee(uint256 amount) internal view returns (uint256) {
        return amount * claimFee / _100pct;
    }

    /// @notice Register an active pool after validating it is Aero LP collateral wired to this manager and gauge tokens match
    /// @param activePool Address of the `ActivePool` to whitelist for stake/withdraw
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

    /// @dev Reverts if `newFee` exceeds `MAX_AERO_MANAGER_FEE`
    function _requireClaimFeeLimit(uint256 newFee) internal pure {
        require(newFee <= MAX_AERO_MANAGER_FEE, "AeroManager: Fee is greater than max aero manager fee limit");
    }

    /// @dev Ensures `msg.sender` is a registered Aero LP `ActivePool`
    function _requireCallerIsActivePool() internal view {
        require(activePools[msg.sender], "AeroManager: Caller is not an active pool");
    }

    /// @dev Ensures `msg.sender` is the configured `collateralRegistry`
    function _requireCallerIsCollateralRegistry() internal view {
        require(msg.sender == address(collateralRegistry), "AeroManager: Caller is not the collateral registry");
    }
}