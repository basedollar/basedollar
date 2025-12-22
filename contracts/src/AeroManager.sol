// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "./Interfaces/IActivePool.sol";
import "./Interfaces/ICollateralRegistry.sol";
import "./Interfaces/IAeroManager.sol";
import "./Interfaces/IAeroGauge.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./Dependencies/Constants.sol";

contract AeroManager is IAeroManager, ReentrancyGuard {
    using SafeERC20 for IERC20;

    ICollateralRegistry public immutable collateralRegistry;
    address public aeroTokenAddress;
    address public governor;

    address public treasuryAddress;

    mapping(address gauge => uint256) public stakedAmounts;
    mapping(address activePool => bool) public activePools;

    uint256 public claimedAero;

    event Staked(address indexed gauge, address token, uint256 amount);
    event ActivePoolAdded(address indexed activePool);
    event Claimed(address indexed gauge, uint256 total, uint256 claimFee);

    constructor(ICollateralRegistry _collateralRegistry, address _aeroTokenAddress, address[] memory _activePools, address _governor, address _treasuryAddress) {
        require(_treasuryAddress != address(0), "AeroManager: Treasury address cannot be 0");
        require(_aeroTokenAddress != address(0), "AeroManager: Aero token address cannot be 0");
        require(address(_collateralRegistry) != address(0), "AeroManager: Collateral registry cannot be 0");

        collateralRegistry = _collateralRegistry;
        aeroTokenAddress = _aeroTokenAddress;
        governor = _governor;
        treasuryAddress = _treasuryAddress;
        for (uint256 i; i < _activePools.length; i++) {
            _addActivePool(_activePools[i]);
        }
    }

    //require functions
    modifier onlyGovernor() {
        require(msg.sender == governor, "AeroManager: Caller is not the governor");
        _;
    }

    //Manage Aero, Interact with gauges, anything else we need to do here.

    //admin functions
    function setAeroTokenAddress(address _aeroTokenAddress) external onlyGovernor {
        aeroTokenAddress = _aeroTokenAddress;
        emit AeroTokenAddressUpdated(_aeroTokenAddress);
    }

    function setGovernor(address _governor) external onlyGovernor {
        governor = _governor;
        emit GovernorUpdated(_governor);
    }

    function addActivePool(address activePool) external onlyGovernor {
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
        uint256 claimFee = _getClaimFee(claimedAmount);
        IERC20(aeroTokenAddress).safeTransfer(treasuryAddress, claimFee);

        // Keep the remaining AERO for the AeroManager (this will be distributed to users later)
        claimedAero += claimedAmount - claimFee; // Subtract the fee from the total claimed amount

        emit Claimed(gauge, claimedAmount, claimFee);
    }

    // Fee is a percentage of the total claimed amount
    // _100pct is 1e18, so AERO_MANAGER_FEE is 10 * _1pct = 10e16
    function _getClaimFee(uint256 amount) internal pure returns (uint256) {
        return amount * AERO_MANAGER_FEE / _100pct;
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

    function _requireCallerIsActivePool() internal view {
        require(activePools[msg.sender], "AeroManager: Caller is not an active pool");
    }
}