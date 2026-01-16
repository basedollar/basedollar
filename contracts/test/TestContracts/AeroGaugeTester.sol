// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "src/Interfaces/IAeroGauge.sol";

contract MockAeroToken is ERC20 {
    constructor() ERC20("Mock AERO", "MAERO") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract AeroGaugeTester is IAeroGauge {

    address public stakingToken;
    MockAeroToken public aeroToken;
    mapping(address user => uint256 amount) public balanceOf;

    address nullAddress = address(0);
    uint256 nullUint256 = 0;

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = _stakingToken;
        aeroToken = _rewardToken == address(0) ? new MockAeroToken() : MockAeroToken(_rewardToken);
    }

    /// @notice Address of the token (AERO) rewarded to stakers
    function rewardToken() external view returns (address) {
        return address(aeroToken);
    }

    /// @notice Address of the FeesVotingReward contract linked to the gauge
    function feesVotingReward() external view returns (address) {
        return nullAddress;
    }

    /// @notice Address of Protocol Voter
    function voter() external view returns (address) {
        return nullAddress;
    }

    /// @notice Address of Protocol Voting Escrow
    function ve() external view returns (address) {
        return nullAddress;
    }

    /// @notice Returns if gauge is linked to a legitimate Protocol pool
    function isPool() external view returns (bool) {
        // Filler logic avoid view compiler warning
        return stakingToken != nullAddress && address(aeroToken) != nullAddress;
    }

    /// @notice Timestamp end of current rewards period
    function periodFinish() external view returns (uint256) {
        return block.timestamp + 1 weeks;
    }

    /// @notice Current reward rate of rewardToken to distribute per second
    function rewardRate() external view returns (uint256) {
        return 1e18 + nullUint256;
    }

    /// @notice Most recent timestamp contract has updated state
    function lastUpdateTime() external view returns (uint256) {
        return block.timestamp;
    }

    /// @notice Most recent stored value of rewardPerToken
    function rewardPerTokenStored() external view returns (uint256) {
        return 1e18 + nullUint256;
    }

    /// @notice Amount of stakingToken deposited for rewards
    function totalSupply() external view returns (uint256) {
        return IERC20(stakingToken).totalSupply();
    }

    /// @notice Cached rewardPerTokenStored for an account based on their most recent action
    function userRewardPerTokenPaid(address) external view returns (uint256) {
        return nullUint256;
    }

    /// @notice Cached amount of rewardToken earned for an account
    function rewards(address) external view returns (uint256) {
        return nullUint256;
    }

    /// @notice View to see the rewardRate given the timestamp of the start of the epoch
    function rewardRateByEpoch(uint256) external view returns (uint256) {
        return 1e18 + nullUint256;
    }

    /// @notice Cached amount of fees generated from the Pool linked to the Gauge of token0
    function fees0() external view returns (uint256) {
        return nullUint256;
    }

    /// @notice Cached amount of fees generated from the Pool linked to the Gauge of token1
    function fees1() external view returns (uint256) {
        return nullUint256;
    }

    /// @notice Get the current reward rate per unit of stakingToken deposited
    function rewardPerToken() external view returns (uint256 _rewardPerToken) {
        return 1e18 + nullUint256;
    }

    /// @notice Returns the last time the reward was modified or periodFinish if the reward has ended
    function lastTimeRewardApplicable() external view returns (uint256 _time) {
        return block.timestamp;
    }

    /// @notice Returns accrued balance to date from last claim / first deposit.
    function earned(address _account) external view returns (uint256 _earned) {
        return balanceOf[_account];
    }

    /// @notice Total amount of rewardToken to distribute for the current rewards period
    function left() external view returns (uint256 _left) {
        return 1e18 + nullUint256;
    }

    /// @notice Retrieve rewards for an address.
    /// @dev Throws if not called by same address or voter.
    /// @param _account .
    function getReward(address _account) external {
        aeroToken.mint(_account, balanceOf[_account]);
    }

    /// @notice Deposit LP tokens into gauge for msg.sender
    /// @param _amount .
    function deposit(uint256 _amount) external {
        balanceOf[msg.sender] += _amount;
        IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Deposit LP tokens into gauge for any user
    /// @param _amount .
    /// @param _recipient Recipient to give balance to
    function deposit(uint256 _amount, address _recipient) external {
        balanceOf[_recipient] += _amount;
        IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Withdraw LP tokens for user
    /// @param _amount .
    function withdraw(uint256 _amount) external {
        balanceOf[msg.sender] -= _amount;
        IERC20(stakingToken).transfer(msg.sender, _amount);
    }

    /// @dev Notifies gauge of gauge rewards. Assumes gauge reward tokens is 18 decimals.
    ///      If not 18 decimals, rewardRate may have rounding issues.
    function notifyRewardAmount(uint256 amount) external {}

    /// @dev Notifies gauge of gauge rewards without distributing its fees.
    ///      Assumes gauge reward tokens is 18 decimals.
    ///      If not 18 decimals, rewardRate may have rounding issues.
    function notifyRewardWithoutClaim(uint256 amount) external {}
}