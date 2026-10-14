// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./Interfaces/IAeroV2Gauge.sol";
import "./Interfaces/IAeroGauge.sol";
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

    function initialize(uint256 _troveId) external {
        _requireCallerIsActivePool();
        require(!_initialized, "TroveAccount: Already initialized");

        _initialized = true;
        troveId = _troveId;
        collToken.safeApprove(address(gauge), type(uint256).max);
    }

    // --- Collateral operations ---

    function stake(uint256 _amount) external nonReentrant {
        _requireCallerIsActivePool();
        if (_amount == 0) return;

        // Harvest mature emissions before a deposit resets the staking timer.
        _claimEmissions();
        _sendAeroRewards();
        gauge.deposit(_amount);
    }

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
