// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./Interfaces/ITroveManager.sol";
import "./Interfaces/IBoldToken.sol";
import "./Dependencies/Constants.sol";
import "./Dependencies/LiquityMath.sol";

import "./Interfaces/ICollateralRegistry.sol";

contract CollateralRegistry is ICollateralRegistry {
    // See: https://github.com/ethereum/solidity/issues/12587
    uint256 public totalCollaterals;

    uint256 private constant MAX_REDEEMABLE_BRANCHES = 10;

    //standard, redeemable branches are capped at 10 total
    IERC20Metadata[] internal redeemableBranchesTokens;
    ITroveManager[] internal redeemableBranchesTroveManagers;

    //special, non-redeemable branches
    IERC20Metadata[] internal nonRedeemableBranchesTokens;
    ITroveManager[] internal nonRedeemableBranchesTroveManagers;

    IBoldToken public immutable boldToken;

    uint256 public baseRate;

    address public collateralGovernor;

    // The timestamp of the latest fee operation (redemption or new Bold issuance)
    uint256 public lastFeeOperationTime = block.timestamp;

    event BaseRateUpdated(uint256 _baseRate);
    event LastFeeOpTimeUpdated(uint256 _lastFeeOpTime);
    event CollateralBranchAdded(uint256 _totalCollaterals, uint256 _index, IERC20Metadata _token, ITroveManager _troveManager, bool _isRedeemable);

    constructor(IBoldToken _boldToken, IERC20Metadata[] memory _tokens, ITroveManager[] memory _troveManagers, address _collateralGovernor) {
        uint256 numTokens = _tokens.length;
        require(numTokens > 0, "Collateral list cannot be empty");
        require(numTokens <= MAX_REDEEMABLE_BRANCHES, "Collateral list too long");
        totalCollaterals = numTokens;

        boldToken = _boldToken;

        require(_tokens.length == _troveManagers.length, "Tokens and trove managers must have the same length");
        //standard, redeemable branches
        for(uint256 i = 0; i < _tokens.length; i++){
            redeemableBranchesTokens.push(_tokens[i]);
            redeemableBranchesTroveManagers.push(_troveManagers[i]);
        }

        collateralGovernor = _collateralGovernor;

        governor = _governor;

        // Initialize the baseRate state variable
        baseRate = INITIAL_BASE_RATE;
        emit BaseRateUpdated(INITIAL_BASE_RATE);
    }

    /*
    @notice Creates a new branch for the collateral registry
    @param _token The collateral token for the new branch
    @param _troveManager The trove manager for the new branch
    @param _isRedeemable Whether the new branch is redeemable

    @dev If the new branch is redeemable, it will be added to the redeemable branches array, but only 10 are allowed
    Alos, make sure that is doesnt already exist. Do not add a new branch using an existing known trove manager. Governor is expected to be trusted on this.
    */
    function createNewBranch(IERC20Metadata _token, ITroveManager _troveManager, bool _isRedeemable) external onlyGovernor {
        require(msg.sender == collateralGovernor, "CR: Only collateral governor can create new branches");
        require(address(_token) != address(0), "CR: Token cannot be the zero address");
        require(address(_troveManager) != address(0), "CR: Trove manager cannot be the zero address");
        require(address(_token) != address(boldToken), "CR: Token cannot be the bold token");

        uint256 index;
        if(_isRedeemable){
            require(redeemableBranchesTokens.length < MAX_REDEEMABLE_BRANCHES, "CR: Max 10 redeemable branches");
            index = redeemableBranchesTokens.length;
            redeemableBranchesTokens.push(_token);
            redeemableBranchesTroveManagers.push(_troveManager);
        } else {
            index = nonRedeemableBranchesTokens.length;
            nonRedeemableBranchesTokens.push(_token);
            nonRedeemableBranchesTroveManagers.push(_troveManager);
        }
        totalCollaterals++;
        emit CollateralBranchAdded(totalCollaterals, index, _token, _troveManager, _isRedeemable);
    }

    struct RedemptionTotals {
        uint256 numCollaterals;
        uint256 boldSupplyAtStart;
        uint256 unbacked;
        uint256 redeemedAmount;
    }

    function redeemCollateral(uint256 _boldAmount, uint256 _maxIterationsPerCollateral, uint256 _maxFeePercentage)
        external
    {
        _requireValidMaxFeePercentage(_maxFeePercentage);
        _requireAmountGreaterThanZero(_boldAmount);

        RedemptionTotals memory totals;

        totals.numCollaterals = redeemableBranchesTokens.length;
        uint256[] memory unbackedPortions = new uint256[](totals.numCollaterals);
        uint256[] memory prices = new uint256[](totals.numCollaterals);

        // Gather and accumulate unbacked portions
        for (uint256 index = 0; index < totals.numCollaterals; index++) {
            ITroveManager troveManager = getTroveManager(index);
            (uint256 unbackedPortion, uint256 price, bool redeemable) =
                troveManager.getUnbackedPortionPriceAndRedeemability();
            prices[index] = price;
            if (redeemable) {
                totals.unbacked += unbackedPortion;
                unbackedPortions[index] = unbackedPortion;
            }
        }

        // There’s an unlikely scenario where all the normally redeemable branches (i.e. having TCR > SCR) have 0 unbacked
        // In that case, we redeem proportionally to branch size
        if (totals.unbacked == 0) {
            unbackedPortions = new uint256[](totals.numCollaterals);
            for (uint256 index = 0; index < totals.numCollaterals; index++) {
                ITroveManager troveManager = getTroveManager(index);
                (,, bool redeemable) = troveManager.getUnbackedPortionPriceAndRedeemability();
                if (redeemable) {
                    uint256 unbackedPortion = troveManager.getEntireBranchDebt();
                    totals.unbacked += unbackedPortion;
                    unbackedPortions[index] = unbackedPortion;
                }
            }
        } else {
            // Don't allow redeeming more than the total unbacked in one go, as that would result in a disproportionate
            // redemption (see CS-BOLD-013). Instead, truncate the redemption to total unbacked. If this happens, the
            // redeemer can call `redeemCollateral()` a second time to redeem the remainder of their BOLD.
            if (_boldAmount > totals.unbacked) {
                _boldAmount = totals.unbacked;
            }
        }

        totals.boldSupplyAtStart = boldToken.totalSupply();
        // Decay the baseRate due to time passed, and then increase it according to the size of this redemption.
        // Use the saved total Bold supply value, from before it was reduced by the redemption.
        // We only compute it here, and update it at the end,
        // because the final redeemed amount may be less than the requested amount
        // Redeemers should take this into account in order to request the optimal amount to not overpay
        uint256 redemptionRate =
            _calcRedemptionRate(_getUpdatedBaseRateFromRedemption(_boldAmount, totals.boldSupplyAtStart));
        require(redemptionRate <= _maxFeePercentage, "CR: Fee exceeded provided maximum");
        // Implicit by the above and the _requireValidMaxFeePercentage checks
        //require(newBaseRate < DECIMAL_PRECISION, "CR: Fee would eat up all collateral");

        // Compute redemption amount for each collateral and redeem against the corresponding TroveManager
        for (uint256 index = 0; index < totals.numCollaterals; index++) {
            //uint256 unbackedPortion = unbackedPortions[index];
            if (unbackedPortions[index] > 0) {
                uint256 redeemAmount = _boldAmount * unbackedPortions[index] / totals.unbacked;
                if (redeemAmount > 0) {
                    ITroveManager troveManager = getTroveManager(index);
                    uint256 redeemedAmount = troveManager.redeemCollateral(
                        msg.sender, redeemAmount, prices[index], redemptionRate, _maxIterationsPerCollateral
                    );
                    totals.redeemedAmount += redeemedAmount;
                }

                // Ensure that per-branch redeems add up to `_boldAmount` exactly
                _boldAmount -= redeemAmount;
                totals.unbacked -= unbackedPortions[index];
            }
        }

        _updateBaseRateAndGetRedemptionRate(totals.redeemedAmount, totals.boldSupplyAtStart);

        // Burn the total Bold that is cancelled with debt
        if (totals.redeemedAmount > 0) {
            boldToken.burn(msg.sender, totals.redeemedAmount);
        }
    }

    // --- Internal fee functions ---

    // Update the last fee operation time only if time passed >= decay interval. This prevents base rate griefing.
    function _updateLastFeeOpTime() internal {
        uint256 minutesPassed = _minutesPassedSinceLastFeeOp();

        if (minutesPassed > 0) {
            lastFeeOperationTime += ONE_MINUTE * minutesPassed;
            emit LastFeeOpTimeUpdated(lastFeeOperationTime);
        }
    }

    function _minutesPassedSinceLastFeeOp() internal view returns (uint256) {
        return (block.timestamp - lastFeeOperationTime) / ONE_MINUTE;
    }

    // Updates the `baseRate` state with math from `_getUpdatedBaseRateFromRedemption`
    function _updateBaseRateAndGetRedemptionRate(uint256 _boldAmount, uint256 _totalBoldSupplyAtStart) internal {
        uint256 newBaseRate = _getUpdatedBaseRateFromRedemption(_boldAmount, _totalBoldSupplyAtStart);

        //assert(newBaseRate <= DECIMAL_PRECISION); // This is already enforced in `_getUpdatedBaseRateFromRedemption`

        // Update the baseRate state variable
        baseRate = newBaseRate;
        emit BaseRateUpdated(newBaseRate);

        _updateLastFeeOpTime();
    }

    /*
     * This function calculates the new baseRate in the following way:
     * 1) decays the baseRate based on time passed since last redemption or Bold borrowing operation.
     * then,
     * 2) increases the baseRate based on the amount redeemed, as a proportion of total supply
     */
    function _getUpdatedBaseRateFromRedemption(uint256 _redeemAmount, uint256 _totalBoldSupply)
        internal
        view
        returns (uint256)
    {
        // decay the base rate
        uint256 decayedBaseRate = _calcDecayedBaseRate();

        // get the fraction of total supply that was redeemed
        uint256 redeemedBoldFraction = _redeemAmount * DECIMAL_PRECISION / _totalBoldSupply;

        uint256 newBaseRate = decayedBaseRate + redeemedBoldFraction / REDEMPTION_BETA;
        newBaseRate = LiquityMath._min(newBaseRate, DECIMAL_PRECISION); // cap baseRate at a maximum of 100%

        return newBaseRate;
    }

    function _calcDecayedBaseRate() internal view returns (uint256) {
        uint256 minutesPassed = _minutesPassedSinceLastFeeOp();
        uint256 decayFactor = LiquityMath._decPow(REDEMPTION_MINUTE_DECAY_FACTOR, minutesPassed);

        return baseRate * decayFactor / DECIMAL_PRECISION;
    }

    function _calcRedemptionRate(uint256 _baseRate) internal pure returns (uint256) {
        return LiquityMath._min(
            REDEMPTION_FEE_FLOOR + _baseRate,
            DECIMAL_PRECISION // cap at a maximum of 100%
        );
    }

    function _calcRedemptionFee(uint256 _redemptionRate, uint256 _amount) internal pure returns (uint256) {
        uint256 redemptionFee = _redemptionRate * _amount / DECIMAL_PRECISION;
        return redemptionFee;
    }

    // external redemption rate/fee getters

    function getRedemptionRate() external view override returns (uint256) {
        return _calcRedemptionRate(baseRate);
    }

    function getRedemptionRateWithDecay() public view override returns (uint256) {
        return _calcRedemptionRate(_calcDecayedBaseRate());
    }

    function getRedemptionRateForRedeemedAmount(uint256 _redeemAmount) external view returns (uint256) {
        uint256 totalBoldSupply = boldToken.totalSupply();
        uint256 newBaseRate = _getUpdatedBaseRateFromRedemption(_redeemAmount, totalBoldSupply);
        return _calcRedemptionRate(newBaseRate);
    }

    function getRedemptionFeeWithDecay(uint256 _ETHDrawn) external view override returns (uint256) {
        return _calcRedemptionFee(getRedemptionRateWithDecay(), _ETHDrawn);
    }

    function getEffectiveRedemptionFeeInBold(uint256 _redeemAmount) external view override returns (uint256) {
        uint256 totalBoldSupply = boldToken.totalSupply();
        uint256 newBaseRate = _getUpdatedBaseRateFromRedemption(_redeemAmount, totalBoldSupply);
        return _calcRedemptionFee(_calcRedemptionRate(newBaseRate), _redeemAmount);
    }

    // getters

    function getToken(uint256 _index) external view returns (IERC20Metadata) {
        return redeemableBranchesTokens[_index];
    }

    function getNonRedeemableToken(uint256 _index) external view returns(IERC20Metadata){
        return nonRedeemableBranchesTokens[_index];
    }

    //@param _index The index of the redeemable branch
    //@return The trove manager for the redeemable branch
    //@dev ONLY returns the redeemable troves. Since this is only used for redemptions this is ideal.
    function getTroveManager(uint256 _index) public view returns (ITroveManager) {
        return redeemableBranchesTroveManagers[_index];
    }

    function getNonRedeemableTroveManager(uint256 _index) external view returns(ITroveManager){
        return nonRedeemableBranchesTroveManagers[_index];
    }

    //returns all trove managers, just used for front end as a helper and is not a core feature.
    function getAllTroveManagers() external view returns(ITroveManager[] memory){
        ITroveManager[] memory allTroveManagers = new ITroveManager[](redeemableBranchesTroveManagers.length + nonRedeemableBranchesTroveManagers.length);
        for(uint256 i = 0; i < redeemableBranchesTroveManagers.length; i++){
            allTroveManagers[i] = redeemableBranchesTroveManagers[i];
        }
        for(uint256 i = 0; i < nonRedeemableBranchesTroveManagers.length; i++){
            allTroveManagers[redeemableBranchesTroveManagers.length + i] = nonRedeemableBranchesTroveManagers[i];
        }
        return allTroveManagers;
    }

        // Update the debt limit for a specific TroveManager
    function updateDebtLimit(uint256 _indexTroveManager, uint256 _newDebtLimit) external onlyGovernor {
        //limited to increasing by 2x at a time, maximum. Decrease by any amount.
        uint256 currentDebtLimit = getTroveManager(_indexTroveManager).getDebtLimit();
        if (_newDebtLimit > currentDebtLimit) {
            require(_newDebtLimit <= currentDebtLimit * 2 || _newDebtLimit <= getTroveManager(_indexTroveManager).getInitalDebtLimit(), "CollateralRegistry: Debt limit increase by more than 2x is not allowed");
        }
        getTroveManager(_indexTroveManager).setDebtLimit(_newDebtLimit);
    }

    function getDebtLimit(uint256 _indexTroveManager) external view returns (uint256) {
        return getTroveManager(_indexTroveManager).getDebtLimit();
    }

    // require functions

    function _requireValidMaxFeePercentage(uint256 _maxFeePercentage) internal pure {
        require(
            _maxFeePercentage >= REDEMPTION_FEE_FLOOR && _maxFeePercentage <= DECIMAL_PRECISION,
            "Max fee percentage must be between 0.5% and 100%"
        );
    }

    function _requireAmountGreaterThanZero(uint256 _amount) internal pure {
        require(_amount > 0, "CollateralRegistry: Amount must be greater than zero");
    }

    function updateGovernor(address _newGovernor) external onlyGovernor {
        governor = _newGovernor;
    }

    modifier onlyGovernor() {
        require(msg.sender == governor, "CollateralRegistry: Only governor can call this function");
        _;
    }
}
