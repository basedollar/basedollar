// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import {_100pct, DECIMAL_PRECISION} from "./Dependencies/Constants.sol";
import {IAddressesRegistry} from "./Interfaces/IAddressesRegistry.sol";
import {IBoldToken} from "./Interfaces/IBoldToken.sol";
import {ICollateralRegistry} from "./Interfaces/ICollateralRegistry.sol";
import {IRedemptionHelper} from "./Interfaces/IRedemptionHelper.sol";
import {ISortedTroves} from "./Interfaces/ISortedTroves.sol";
import {ITroveManager} from "./Interfaces/ITroveManager.sol";
import {LatestTroveData} from "./Types/LatestTroveData.sol";

contract RedemptionHelper is IRedemptionHelper {
    using SafeERC20 for IERC20;

    struct RedemptionContext {
        IERC20 collToken;
        uint256 collBalanceBefore;
    }

    ICollateralRegistry public immutable collateralRegistry;
    IBoldToken public immutable boldToken;

    constructor(ICollateralRegistry _collateralRegistry) {
        collateralRegistry = _collateralRegistry;
        boldToken = _collateralRegistry.boldToken();
    }

    /// @notice Number of redeemable collateral branches (matches `CollateralRegistry.redeemCollateral` iteration).
    function numBranches() public view returns (uint256) {
        return collateralRegistry.getTroveManagers().length;
    }

    // Meant to be called off-chain
    // Not a view because price fetching has side-effects
    function simulateRedemption(uint256 _bold, uint256 _maxIterationsPerCollateral)
        public
        returns (SimulationContext[] memory branch, uint256 totalProportions)
    {
        uint256 n = numBranches();
        branch = new SimulationContext[](n);

        // First priority: proportional to unbacked debt
        for (uint256 i = 0; i < n; ++i) {
            ITroveManager troveManager = collateralRegistry.getTroveManager(i);
            branch[i].troveManager = address(troveManager);
            branch[i].sortedTroves = address(troveManager.sortedTroves());
            (branch[i].proportion, branch[i].price, branch[i].redeemable) =
                troveManager.getUnbackedPortionPriceAndRedeemability();
            if (branch[i].redeemable) totalProportions += branch[i].proportion;
        }

        // CS-BOLD-013: truncate redemption if it would exceed total unbacked debt
        if (0 < totalProportions && totalProportions < _bold) _bold = totalProportions;

        // Fallback: proportional to total debt
        if (totalProportions == 0) {
            for (uint256 i = 0; i < n; ++i) {
                branch[i].proportion = ITroveManager(branch[i].troveManager).getEntireBranchDebt();
                if (branch[i].redeemable) totalProportions += branch[i].proportion;
            }
        }

        if (totalProportions == 0) return (branch, totalProportions);

        for (uint256 i = 0; i < n; ++i) {
            if (!branch[i].redeemable) continue;

            branch[i].attemptedBold = _bold * branch[i].proportion / totalProportions;
            if (branch[i].attemptedBold == 0) continue;

            uint256 lastZombieTroveId = ITroveManager(branch[i].troveManager).lastZombieTroveId();
            uint256 lastTroveId = ISortedTroves(branch[i].sortedTroves).getLast();

            (uint256 troveId, uint256 nextTroveId) = lastZombieTroveId != 0
                ? (lastZombieTroveId, lastTroveId)
                : (lastTroveId, ISortedTroves(branch[i].sortedTroves).getPrev(lastTroveId));

            for (
                branch[i].iterations = 0;
                branch[i].iterations < _maxIterationsPerCollateral || _maxIterationsPerCollateral == 0;
                ++branch[i].iterations
            ) {
                if (branch[i].redeemedBold == branch[i].attemptedBold || troveId == 0) break;

                LatestTroveData memory trove = ITroveManager(branch[i].troveManager).getLatestTroveData(troveId);
                if (trove.entireColl * branch[i].price / trove.entireDebt >= _100pct) {
                    branch[i].redeemedBold +=
                        Math.min(branch[i].attemptedBold - branch[i].redeemedBold, trove.entireDebt);
                }

                troveId = nextTroveId;
                nextTroveId = ISortedTroves(branch[i].sortedTroves).getPrev(nextTroveId);
            }
        }
    }

    // Meant to be called off-chain
    // Not a view because price fetching has side-effects
    function truncateRedemption(uint256 _bold, uint256 _maxIterationsPerCollateral)
        external
        returns (uint256 truncatedBold, uint256 feePct, Redeemed[] memory redeemed)
    {
        (SimulationContext[] memory branch, uint256 totalProportions) =
            simulateRedemption(_bold, _maxIterationsPerCollateral);

        if (totalProportions == 0) return (0, 0, redeemed);

        uint256 n = numBranches();

        truncatedBold = _bold;
        for (uint256 i = 0; i < n; ++i) {
            if (branch[i].redeemable && branch[i].proportion > 0) {
                // Extrapolate how much the entire redeemed BOLD would
                // have been if this branch was redeemed proportionally.
                uint256 extrapolatedBold = branch[i].redeemedBold * totalProportions / branch[i].proportion;

                // Normally this is no different from `_bold`, but can be less if the redemption on this branch
                // terminated due to hitting the iteration limit. We're looking for the smallest extrapolated value,
                // since that is the maximum amount of BOLD that can be redeemed proportionally within the given
                // iteration limit. Any attempt to redeem more than this would result in a partial redemption, thus
                // paying a higher redemption fee than necessary — since the fee is based on the attempted amount.
                if (extrapolatedBold < truncatedBold) truncatedBold = extrapolatedBold;
            }
        }

        feePct = collateralRegistry.getRedemptionRateForRedeemedAmount(truncatedBold);
        redeemed = new Redeemed[](n);

        for (uint256 i = 0; i < n; ++i) {
            if (branch[i].redeemable && branch[i].proportion > 0) {
                (uint256 redemptionPrice,) = collateralRegistry.getTroveManager(i).getPriceFeed().fetchRedemptionPrice();
                redeemed[i].bold = truncatedBold * branch[i].proportion / totalProportions;
                redeemed[i].coll = redeemed[i].bold * (DECIMAL_PRECISION - feePct) / redemptionPrice;
            }
        }
    }

    function redeemCollateral(
        uint256 _bold,
        uint256 _maxIterationsPerCollateral,
        uint256 _maxFeePct,
        uint256[] memory _minCollRedeemed
    ) external {
        uint256 n = numBranches();
        require(_bold > 0, "Redeemed amount must be non-zero");
        require(_minCollRedeemed.length == n, "Wrong _minCollRedeemed length");

        RedemptionContext[] memory branch = new RedemptionContext[](n);

        for (uint256 i = 0; i < n; ++i) {
            branch[i].collToken = collateralRegistry.getToken(i);
            branch[i].collBalanceBefore = branch[i].collToken.balanceOf(address(this));
        }

        uint256 boldBalanceBefore = boldToken.balanceOf(address(this));

        boldToken.transferFrom(msg.sender, address(this), _bold);
        collateralRegistry.redeemCollateral(_bold, _maxIterationsPerCollateral, _maxFeePct);

        for (uint256 i = 0; i < n; ++i) {
            uint256 collRedeemed = branch[i].collToken.balanceOf(address(this)) - branch[i].collBalanceBefore;
            require(collRedeemed >= _minCollRedeemed[i], "Insufficient collateral redeemed");
            if (collRedeemed > 0) branch[i].collToken.safeTransfer(msg.sender, collRedeemed);
        }

        uint256 boldRemaining = boldToken.balanceOf(address(this)) - boldBalanceBefore;
        if (boldRemaining > 0) boldToken.transfer(msg.sender, boldRemaining);
    }
}
