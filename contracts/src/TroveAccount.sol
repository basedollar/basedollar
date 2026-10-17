// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import {IGauge as IAeroGauge} from "./Interfaces/MetaDEX03/gauges/IGauge.sol";
import {IV2Gauge as IAeroV2Gauge} from "./Interfaces/MetaDEX03/gauges/IV2Gauge.sol";
import {IGaugeFactory as IAeroGaugeFactory} from "./Interfaces/MetaDEX03/factories/IGaugeFactory.sol";
import "./Interfaces/IAeroManager.sol";
import "./Interfaces/ITroveAccount.sol";
import "./Interfaces/IAddressesRegistry.sol";
import "./Interfaces/IActivePool.sol";

/*
 * Holds the Aero LP stake for a single trove. Only ActivePool can move collateral.
 * Claimed emissions are sent to AeroManager for distribution.
 */
contract TroveAccount is ITroveAccount, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public troveId;
    bool private _initialized;
    IActivePool public immutable activePool;
    IERC20 public immutable collToken;
    IAeroV2Gauge public immutable gauge;
    IAeroManager public immutable aeroManager;

    bool public isClosed;

    constructor(IAddressesRegistry _addressesRegistry, IAeroV2Gauge _gauge) {
        // Lock the implementation. Clones have their own uninitialized storage.
        _initialized = true;
        activePool = _addressesRegistry.activePool();
        collToken = _addressesRegistry.collToken();
        gauge = _gauge;
        aeroManager = _addressesRegistry.aeroManager();

        require(_gauge.stakingToken() == address(collToken), "TroveAccount: Staking token mismatch");
    }

    /// @notice Initialized by ActivePool to assign troveId
    function initialize(uint256 _troveId) external {
        _requireCallerIsActivePool();
        require(!_initialized, "TroveAccount: Already initialized");

        _initialized = true;
        troveId = _troveId;
        collToken.safeApprove(address(gauge), type(uint256).max);
    }

    // --- Collateral operations ---

    /// @notice Deposits Aero LP collateral from troveId into Gauge
    function stake(uint256 _amount) external nonReentrant {
        _requireCallerIsActivePool();
        if (_amount == 0) return;

        // Harvest mature emissions before a deposit resets the staking timer.
        _claimEmissions();
        _sendAeroRewards();
        gauge.deposit(_amount);
    }

    /// @notice Withdraws staked Aero LP collateral of troveId from Gauge by ActivePool
    function withdraw(uint256 _amount) external nonReentrant {
        _requireCallerIsActivePool();
        if (_amount == 0) return;

        if (gauge.balanceOf(address(this)) == _amount) {
            isClosed = true;
        }

        // Gauge withdrawals settle emissions, including any early-exit penalty.
        gauge.withdraw(_amount);
        collToken.safeTransfer(address(activePool), _amount);
        _sendAeroRewards();
    }

    // --- Reward operations ---

    /// @notice claims emissions from individual trove's staked amount and sends to AeroManager
    function claimEmissions() external nonReentrant returns (uint256 amount) {
        _requireCallerIsAeroManager();
        _claimEmissions();
        IERC20 _aeroToken = IERC20(aeroManager.aeroTokenAddress());
        amount = _aeroToken.balanceOf(address(this));
        _aeroToken.safeTransfer(msg.sender, amount);
        return amount;
    }

    function recoverRewards() external nonReentrant {
        require(isClosed, "TroveAccount: Cannot recover rewards from active trove");
        _claimEmissions();
        _sendAeroRewards();
    }

    /// @notice Transfers balance of any miscellaneous tokens stranded after trove closed.
    /// This also serves as a recovery method for prior rewards if AERO token address changes.
    /// @dev Only AeroManager governor can call this function.
    function sweep(address token, address to) external nonReentrant {
        require(msg.sender == aeroManager.governor(), "TroveAccount: Caller is not AeroManager governor");
        require(token != address(collToken) && token != aeroManager.aeroTokenAddress(), "TroveAccount: token cannot be collateral or reward address");
        require(to != address(0), "TroveAccount: to address cannot be null");
        require(isClosed, "TroveAccount: Cannot sweep token while trove is active");
        IERC20 erc20 = IERC20(token);
        uint256 balance = erc20.balanceOf(address(this));
        if (balance > 0) {
            erc20.safeTransfer(to, balance);
        }
    }

    /// @dev Only claims emissions if its past minimum stake block since last deposit to avoid reward penalty slash
    function _claimEmissions() internal {
        if (
            gauge.balanceOf(address(this)) > 0 || gauge.rewards(address(this)) > 0
                || gauge.deferredEmissions(address(this)) > 0
        ) {
            IAeroGaugeFactory.PenaltyConfig memory penaltyConfig =
                IAeroGaugeFactory(gauge.gaugeFactory()).effectivePenaltyConfig(address(gauge));
            uint256 depositBlock = gauge.depositBlock(address(this));
            if (penaltyConfig.penaltyRate == 0 || block.number - depositBlock >= penaltyConfig.minStakeBlocks) {
                try gauge.claimEmissions(address(this), address(this)) {} 
                catch {
                  // Ignore claim failures so collateral operations can continue.
                }
            }
        }
    }

    /// @dev Calls AeroManager to transfer and collect claimed emissions from trove account
    function _sendAeroRewards() internal returns (uint256 amount) {
        IERC20 _aeroToken = IERC20(aeroManager.aeroTokenAddress());
        amount = _aeroToken.balanceOf(address(this));
        if (amount == 0) return 0;

        // Collateral exits must still be possible.
        // To handle troves closing while current epoch is closed,
        // rewards are credited to next epoch.

        _aeroToken.safeIncreaseAllowance(address(aeroManager), amount);
        aeroManager.receiveAeroRewards(address(gauge), amount);
        return amount;
    }

    // --- 'require' functions ---

    function _requireCallerIsActivePool() internal view {
        require(msg.sender == address(activePool), "TroveAccount: Caller is not ActivePool");
    }

    function _requireCallerIsAeroManager() internal view {
        require(msg.sender == address(aeroManager), "TroveAccount: Caller is not AeroManager");
    }
}
