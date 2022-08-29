// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {OwnableInternal} from "../../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import {LibInterestRateStrategy} from "../../../libraries/facets/LibInterestRateStrategy.sol";
import {LayoutTypes} from "../../../libraries/types/LayoutTypes.sol";

contract InterestRateStrategy is OwnableInternal {
    using LibInterestRateStrategy for LayoutTypes.InterestRateStrategyLayout;
    /**
     * @param optimalUsageRatio The optimal usage ratio
     * @param baseVariableBorrowRate The base variable borrow rate
     * @param variableRateSlope1 The variable rate slope below optimal usage ratio
     * @param variableRateSlope2 The variable rate slope above optimal usage ratio
     * @param stableRateSlope1 The stable rate slope below optimal usage ratio
     * @param stableRateSlope2 The stable rate slope above optimal usage ratio
     * @param baseStableRateOffset The premium on top of variable rate for base stable borrowing rate
     * @param stableRateExcessOffset The premium on top of stable rate when there stable debt surpass the threshold
     * @param optimalStableToTotalDebtRatio The optimal stable debt to total debt ratio of the reserve
     */
    function initializeInterestRateStrategy(
        uint256 optimalUsageRatio,
        uint256 baseVariableBorrowRate,
        uint256 variableRateSlope1,
        uint256 variableRateSlope2,
        uint256 stableRateSlope1,
        uint256 stableRateSlope2,
        uint256 baseStableRateOffset,
        uint256 stableRateExcessOffset,
        uint256 optimalStableToTotalDebtRatio
    ) external onlyOwner {
        LibInterestRateStrategy.layout().initializeInterestRateStrategy(   
            optimalUsageRatio,
            baseVariableBorrowRate,
            variableRateSlope1,
            variableRateSlope2,
            stableRateSlope1,
            stableRateSlope2,
            baseStableRateOffset,
            stableRateExcessOffset,
            optimalStableToTotalDebtRatio
         )
    }

      /**
   * @notice Returns the variable rate slope below optimal usage ratio
   * @dev Its the variable rate when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO
   * @return The variable rate slope
   **/
  function getVariableRateSlope1() external view returns (uint256) {
      return LibInterestRateStrategy.getVariableRateSlope1();
  }

  /**
   * @notice Returns the variable rate slope above optimal usage ratio
   * @dev Its the variable rate when usage ratio > OPTIMAL_USAGE_RATIO
   * @return The variable rate slope
   **/
  function getVariableRateSlope2() external view returns (uint256) {
    return LibInterestRateStrategy.getVariableRateSlope2();
  }

  /**
   * @notice Returns the stable rate slope below optimal usage ratio
   * @dev Its the stable rate when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO
   * @return The stable rate slope
   **/
  function getStableRateSlope1() external view returns (uint256) {
    return LibInterestRateStrategy.getStableRateSlope1();
  }

  /**
   * @notice Returns the stable rate slope above optimal usage ratio
   * @dev Its the variable rate when usage ratio > OPTIMAL_USAGE_RATIO
   * @return The stable rate slope
   **/
  function getStableRateSlope2() external view returns (uint256) {
    return LibInterestRateStrategy.getStableRateSlope2();
  }

  /**
   * @notice Returns the stable rate excess offset
   * @dev An additional premium applied to the stable when stable debt > OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO
   * @return The stable rate excess offset
   */
  function getStableRateExcessOffset() external view returns (uint256) {
    return LibInterestRateStrategy.getStableRateExcessOffset();
  }

  /**
   * @notice Returns the base stable borrow rate
   * @return The base stable borrow rate
   **/
  function getBaseStableBorrowRate() external view returns (uint256) {
    return LibInterestRateStrategy.getBaseStableBorrowRate();
  }

  /// @inheritdoc IReserveInterestRateStrategy
  function getBaseVariableBorrowRate() external view returns (uint256) {
    return LibInterestRateStrategy.getBaseVariableBorrowRate();
  }

  /// @inheritdoc IReserveInterestRateStrategy
  function getMaxVariableBorrowRate() external view returns (uint256) {
    return LibInterestRateStrategy.getMaxVariableBorrowRate();
  }

    function calculateInterestRates(
        DataTypes.CalculateInterestRatesParams calldata params
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return LibInterestRateStrategy.calculateInterestRates(params);
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
    ) external pure returns (uint256) {
        return LibInterestRateStrategy.getOverallBorrowRate(     
            totalStableDebt,
            totalVariableDebt,
            currentVariableBorrowRate,
            currentAverageStableBorrowRate
         )
    }
}
