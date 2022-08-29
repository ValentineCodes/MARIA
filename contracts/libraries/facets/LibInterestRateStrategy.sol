// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {IERC20} from "../../dependencies/openzeppelin/contracts/ERC20.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {Errors} from "../utils/Errors.sol";
import {Query} from "../utils/Query.sol";
import {LayoutTypes} from "../types/LayoutTypes.sol";

library InterestRateStrategy {
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    /**
     * @dev This constant represents the usage ratio at which the pool aims to obtain most competitive borrow rates.
     * Expressed in ray
     **/
    uint256 public immutable OPTIMAL_USAGE_RATIO;

    /**
     * @dev This constant represents the optimal stable debt to total debt ratio of the reserve.
     * Expressed in ray
     */
    uint256 public immutable OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO;

    /**
     * @dev This constant represents the excess usage ratio above the optimal. It's always equal to
     * 1-optimal usage ratio. Added as a constant here for gas optimizations.
     * Expressed in ray
     **/
    uint256 public immutable MAX_EXCESS_USAGE_RATIO;

    /**
     * @dev This constant represents the excess stable debt ratio above the optimal. It's always equal to
     * 1-optimal stable to total debt ratio. Added as a constant here for gas optimizations.
     * Expressed in ray
     **/
    uint256 public immutable MAX_EXCESS_STABLE_TO_TOTAL_DEBT_RATIO;

    // Base variable borrow rate when usage rate = 0. Expressed in ray
    uint256 internal immutable _baseVariableBorrowRate;

    // Slope of the variable interest curve when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO. Expressed in ray
    uint256 internal immutable _variableRateSlope1;

    // Slope of the variable interest curve when usage ratio > OPTIMAL_USAGE_RATIO. Expressed in ray
    uint256 internal immutable _variableRateSlope2;

    // Slope of the stable interest curve when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO. Expressed in ray
    uint256 internal immutable _stableRateSlope1;

    // Slope of the stable interest curve when usage ratio > OPTIMAL_USAGE_RATIO. Expressed in ray
    uint256 internal immutable _stableRateSlope2;

    // Premium on top of `_variableRateSlope1` for base stable borrowing rate
    uint256 internal immutable _baseStableRateOffset;

    // Additional premium applied to stable rate when stable debt surpass `OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO`
    uint256 internal immutable _stableRateExcessOffset;

    bytes32 internal constant STORAGE_SLOT =
        keccak256("interestRateStrategy.storage");

    modifier initializer(LayoutTypes.InterestRateStrategyLayout storage s) {
        uint256 revision = 0x1;
        require(
            s.initializing ||
                Query.isConstructor() ||
                revision > s.lastInitializedRevision,
            "Contract instance has already been initialized"
        );

        bool isTopLevelCall = !s.initializing;
        if (isTopLevelCall) {
            s.initializing = true;
            s.lastInitializedRevision = revision;
        }

        _;

        if (isTopLevelCall) {
            s.initializing = false;
        }
    }

    function layout()
        internal
        pure
        returns (LayoutTypes.InterestRateStrategyLayout storage s)
    {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    function initializeInterestRateStrategy(
        LayoutTypes.InterestRateStrategyLayout storage s,
        uint256 optimalUsageRatio,
        uint256 baseVariableBorrowRate,
        uint256 variableRateSlope1,
        uint256 variableRateSlope2,
        uint256 stableRateSlope1,
        uint256 stableRateSlope2,
        uint256 baseStableRateOffset,
        uint256 stableRateExcessOffset,
        uint256 optimalStableToTotalDebtRatio
    ) internal initializer(s) {
        require(
            WadRayMath.RAY >= optimalUsageRatio,
            Errors.INVALID_OPTIMAL_USAGE_RATIO
        );
        require(
            WadRayMath.RAY >= optimalStableToTotalDebtRatio,
            Errors.INVALID_OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO
        );

        OPTIMAL_USAGE_RATIO = optimalUsageRatio;
        MAX_EXCESS_USAGE_RATIO = WadRayMath.RAY - optimalUsageRatio;
        OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO = optimalStableToTotalDebtRatio;
        MAX_EXCESS_STABLE_TO_TOTAL_DEBT_RATIO =
            WadRayMath.RAY -
            optimalStableToTotalDebtRatio;
        ADDRESSES_PROVIDER = provider;
        _baseVariableBorrowRate = baseVariableBorrowRate;
        _variableRateSlope1 = variableRateSlope1;
        _variableRateSlope2 = variableRateSlope2;
        _stableRateSlope1 = stableRateSlope1;
        _stableRateSlope2 = stableRateSlope2;
        _baseStableRateOffset = baseStableRateOffset;
        _stableRateExcessOffset = stableRateExcessOffset;
    }

    function getVariableRateSlope1() internal view returns (uint256) {
        return _variableRateSlope1;
    }

    function getVariableRateSlope2() internal view returns (uint256) {
        return _variableRateSlope2;
    }

    function getStableRateSlope1() internal view returns (uint256) {
        return _stableRateSlope1;
    }

    function getStableRateSlope2() internal view returns (uint256) {
        return _stableRateSlope2;
    }

    function getStableRateExcessOffset() internal view returns (uint256) {
        return _stableRateExcessOffset;
    }

    function getBaseStableBorrowRate() internal view returns (uint256) {
        return _variableRateSlope1 + _baseStableRateOffset;
    }

    function getBaseVariableBorrowRate()
        internal
        view
        override
        returns (uint256)
    {
        return _baseVariableBorrowRate;
    }

    function getMaxVariableBorrowRate()
        internal
        view
        override
        returns (uint256)
    {
        return
            _baseVariableBorrowRate + _variableRateSlope1 + _variableRateSlope2;
    }

    struct CalcInterestRatesLocalVars {
        uint256 availableLiquidity;
        uint256 totalDebt;
        uint256 currentVariableBorrowRate;
        uint256 currentStableBorrowRate;
        uint256 currentLiquidityRate;
        uint256 borrowUsageRatio;
        uint256 supplyUsageRatio;
        uint256 stableToTotalDebtRatio;
        uint256 availableLiquidityPlusDebt;
    }

    function calculateInterestRates(
        DataTypes.CalculateInterestRatesParams calldata params
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        CalcInterestRatesLocalVars memory vars;

        vars.totalDebt = params.totalStableDebt + params.totalVariableDebt;

        vars.currentLiquidityRate = 0;
        vars.currentVariableBorrowRate = _baseVariableBorrowRate;
        vars.currentStableBorrowRate = getBaseStableBorrowRate();

        if (vars.totalDebt != 0) {
            vars.stableToTotalDebtRatio = params.totalStableDebt.rayDiv(
                vars.totalDebt
            );
            vars.availableLiquidity =
                IERC20(params.reserve).balanceOf(params.aToken) +
                params.liquidityAdded -
                params.liquidityTaken;

            vars.availableLiquidityPlusDebt =
                vars.availableLiquidity +
                vars.totalDebt;
            vars.borrowUsageRatio = vars.totalDebt.rayDiv(
                vars.availableLiquidityPlusDebt
            );
            vars.supplyUsageRatio = vars.totalDebt.rayDiv(
                vars.availableLiquidityPlusDebt + params.unbacked
            );
        }

        if (vars.borrowUsageRatio > OPTIMAL_USAGE_RATIO) {
            uint256 excessBorrowUsageRatio = (vars.borrowUsageRatio -
                OPTIMAL_USAGE_RATIO).rayDiv(MAX_EXCESS_USAGE_RATIO);

            vars.currentStableBorrowRate +=
                _stableRateSlope1 +
                _stableRateSlope2.rayMul(excessBorrowUsageRatio);

            vars.currentVariableBorrowRate +=
                _variableRateSlope1 +
                _variableRateSlope2.rayMul(excessBorrowUsageRatio);
        } else {
            vars.currentStableBorrowRate += _stableRateSlope1
                .rayMul(vars.borrowUsageRatio)
                .rayDiv(OPTIMAL_USAGE_RATIO);

            vars.currentVariableBorrowRate += _variableRateSlope1
                .rayMul(vars.borrowUsageRatio)
                .rayDiv(OPTIMAL_USAGE_RATIO);
        }

        if (vars.stableToTotalDebtRatio > OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO) {
            uint256 excessStableDebtRatio = (vars.stableToTotalDebtRatio -
                OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO).rayDiv(
                    MAX_EXCESS_STABLE_TO_TOTAL_DEBT_RATIO
                );
            vars.currentStableBorrowRate += _stableRateExcessOffset.rayMul(
                excessStableDebtRatio
            );
        }

        vars.currentLiquidityRate = getOverallBorrowRate(
            params.totalStableDebt,
            params.totalVariableDebt,
            vars.currentVariableBorrowRate,
            params.averageStableBorrowRate
        ).rayMul(vars.supplyUsageRatio).percentMul(
                PercentageMath.PERCENTAGE_FACTOR - params.reserveFactor
            );

        return (
            vars.currentLiquidityRate,
            vars.currentStableBorrowRate,
            vars.currentVariableBorrowRate
        );
    }

    /**
     * @dev Calculates the overall borrow rate as the weighted average between the total variable debt and total stable
     * debt
     * @param totalStableDebt The total borrowed from the reserve at a stable rate
     * @param totalVariableDebt The total borrowed from the reserve at a variable rate
     * @param currentVariableBorrowRate The current variable borrow rate of the reserve
     * @param currentAverageStableBorrowRate The current weighted average of all the stable rate loans
     * @return The weighted averaged borrow rate
     **/
    function getOverallBorrowRate(
        uint256 totalStableDebt,
        uint256 totalVariableDebt,
        uint256 currentVariableBorrowRate,
        uint256 currentAverageStableBorrowRate
    ) internal pure returns (uint256) {
        uint256 totalDebt = totalStableDebt + totalVariableDebt;

        if (totalDebt == 0) return 0;

        uint256 weightedVariableRate = totalVariableDebt.wadToRay().rayMul(
            currentVariableBorrowRate
        );

        uint256 weightedStableRate = totalStableDebt.wadToRay().rayMul(
            currentAverageStableBorrowRate
        );

        uint256 overallBorrowRate = (weightedVariableRate + weightedStableRate)
            .rayDiv(totalDebt.wadToRay());

        return overallBorrowRate;
    }
}
