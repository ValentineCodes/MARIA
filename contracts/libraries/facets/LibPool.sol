// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { LayoutTypes } from "../types/LayoutTypes.sol";
import { DataTypes } from "../types/DataTypes.sol";
import { Query } from "../utils/Query.sol";
import { IERC20 } from "../../dependencies/openzeppelin/contracts/IERC20.sol";
import { GPv2SafeERC20 } from "../../dependencies/gnosis/contracts/GPv2SafeERC20.sol";
import { IMToken } from "../../interfaces/IMToken.sol";
import { IStableDebtToken } from "../../interfaces/IStableDebtToken.sol";
import { IVariableDebtToken } from "../../interfaces/IVariableDebtToken.sol";
import { Errors } from "../utils/Errors.sol";
import { Helpers } from "../utils/Helpers.sol";
import { MathUtils } from "../math/MathUtils.sol";
import { WadRayMath } from "../math/WadRayMath.sol";
import { PercentageMath } from "../math/PercentageMath.sol";
import { ValidationLogic } from "../logic/ValidationLogic.sol";
import { ReserveLogic } from "../logic/ReserveLogic.sol";
import { IsolationModeLogic } from "../logic/IsolationModeLogic.sol";
import { ReserveConfiguration } from "../configuration/ReserveConfiguration.sol";
import { UserConfiguration } from "../configuration/UserConfiguration.sol";

library LibPool {
  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;
  using GPv2SafeERC20 for IERC20;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  bytes32 internal constant STORAGE_SLOT = keccak256("pool.storage");

  event ReserveUsedAsCollateralEnabled(
    address indexed reserve,
    address indexed user
  );
  event ReserveUsedAsCollateralDisabled(
    address indexed reserve,
    address indexed user
  );

  event RebalanceStableBorrowRate(
    address indexed reserve,
    address indexed user
  );
  event SwapBorrowRateMode(
    address indexed reserve,
    address indexed user,
    DataTypes.InterestRateMode interestRateMode
  );
  event IsolationModeTotalDebtUpdated(address indexed asset, uint256 totalDebt);
  event Withdraw(
    address indexed reserve,
    address indexed user,
    address indexed to,
    uint256 amount
  );
  event Supply(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );

  event Borrow(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    DataTypes.InterestRateMode interestRateMode,
    uint256 borrowRate,
    uint16 indexed referralCode
  );
  event Repay(
    address indexed reserve,
    address indexed user,
    address indexed repayer,
    uint256 amount,
    bool useMTokens
  );

  modifier initializer(LayoutTypes.PoolLayout storage s) {
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

  function layout() internal pure returns (LayoutTypes.PoolLayout storage s) {
    bytes32 slot = STORAGE_SLOT;
    assembly {
      s.slot := slot
    }
  }

  /**
   * @notice Initializes the Pool.
   **/
  function initializePool() internal initializer(s) {
    LayoutTypes.PoolLayout storage s = layout();

    s._maxStableRateBorrowSizePercent = 0.25e4;
    s._flashLoanPremiumTotal = 0.0009e4;
    s._flashLoanPremiumToProtocol = 0;
  }

  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) internal {
    LayoutTypes.PoolLayout storage s = layout();

    DataTypes.UserConfigurationMap storage userConfig = s._usersConfig[
      onBehalfOf
    ];
    DataTypes.ReserveData storage reserve = s._reserves[asset];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    reserve.updateState(reserveCache);

    ValidationLogic.validateSupply(reserveCache, amount);

    reserve.updateInterestRates(reserveCache, asset, amount, 0);

    IERC20(asset).safeTransferFrom(
      msg.sender,
      reserveCache.mTokenAddress,
      amount
    );

    bool isFirstSupply = IMToken(reserveCache.mTokenAddress).mint(
      msg.sender,
      onBehalfOf,
      amount,
      reserveCache.nextLiquidityIndex
    );

    if (isFirstSupply) {
      if (
        ValidationLogic.validateUseAsCollateral(
          s,
          userConfig,
          reserveCache.reserveConfiguration
        )
      ) {
        userConfig.setUsingAsCollateral(reserve.id, true);
        emit ReserveUsedAsCollateralEnabled(asset, onBehalfOf);
      }
    }

    emit Supply(asset, msg.sender, onBehalfOf, amount, referralCode);
  }

  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) internal returns (uint256) {
    LayoutTypes.PoolLayout storage s = layout();

    DataTypes.UserConfigurationMap storage userConfig = s._usersConfig[
      onBehalfOf
    ];
    DataTypes.ReserveData storage reserve = s._reserves[asset];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    reserve.updateState(reserveCache);

    uint256 userBalance = IMToken(reserveCache.mTokenAddress)
      .scaledBalanceOf(msg.sender)
      .rayMul(reserveCache.nextLiquidityIndex);

    uint256 amountToWithdraw = amount;

    if (amount == type(uint256).max) {
      amountToWithdraw = userBalance;
    }

    ValidationLogic.validateWithdraw(
      reserveCache,
      amountToWithdraw,
      userBalance
    );

    reserve.updateInterestRates(reserveCache, asset, 0, amountToWithdraw);

    IMToken(reserveCache.mTokenAddress).burn(
      msg.sender,
      to,
      amountToWithdraw,
      reserveCache.nextLiquidityIndex
    );

    if (userConfig.isUsingAsCollateral(reserve.id)) {
      if (userConfig.isBorrowingAny()) {
        ValidationLogic.validateHFAndLtv(
          s,
          userConfig,
          asset,
          msg.sender,
          s._reservesCount,
          oracle,
          s._usersEModeCategory[msg.sender]
        );
      }

      if (amountToWithdraw == userBalance) {
        userConfig.setUsingAsCollateral(reserve.id, false);
        emit ReserveUsedAsCollateralDisabled(asset, msg.sender);
      }
    }

    emit Withdraw(asset, msg.sender, to, amountToWithdraw);

    return amountToWithdraw;
  }

  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf,
    bool releaseUnderlying
  ) internal {
    LayoutTypes.PoolLayout storage s = layout();

    DataTypes.UserConfigurationMap storage userConfig = s._usersConfig[
      onBehalfOf
    ];
    DataTypes.ReserveData storage reserve = s._reserves[asset];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    reserve.updateState(reserveCache);

    (
      bool isolationModeActive,
      address isolationModeCollateralAddress,
      uint256 isolationModeDebtCeiling
    ) = userConfig.getIsolationModeState();

    ValidationLogic.validateBorrow(
      s,
      DataTypes.ValidateBorrowParams({
        reserveCache: reserveCache,
        userConfig: userConfig,
        asset: asset,
        userAddress: onBehalfOf,
        amount: amount,
        interestRateMode: interestRateMode,
        maxStableLoanPercent: s._maxStableRateBorrowSizePercent,
        reservesCount: s._reservesCount,
        oracle: oracle,
        userEModeCategory: s._usersEModeCategory[onBehalfOf],
        priceOracleSentinel: priceOracleSentinel,
        isolationModeActive: isolationModeActive,
        isolationModeCollateralAddress: isolationModeCollateralAddress,
        isolationModeDebtCeiling: isolationModeDebtCeiling
      })
    );

    uint256 currentStableRate = 0;
    bool isFirstBorrowing = false;

    if (interestRateMode == DataTypes.InterestRateMode.STABLE) {
      currentStableRate = reserve.currentStableBorrowRate;

      (
        isFirstBorrowing,
        reserveCache.nextTotalStableDebt,
        reserveCache.nextAvgStableBorrowRate
      ) = IStableDebtToken(reserveCache.stableDebtTokenAddress).mint(
        user,
        onBehalfOf,
        amount,
        currentStableRate
      );
    } else {
      (
        isFirstBorrowing,
        reserveCache.nextScaledVariableDebt
      ) = IVariableDebtToken(reserveCache.variableDebtTokenAddress).mint(
        user,
        onBehalfOf,
        amount,
        reserveCache.nextVariableBorrowIndex
      );
    }

    if (isFirstBorrowing) {
      userConfig.setBorrowing(reserve.id, true);
    }

    if (isolationModeActive) {
      uint256 nextIsolationModeTotalDebt = s
        ._reserves[isolationModeCollateralAddress]
        .isolationModeTotalDebt += (amount /
        10 **
          (reserveCache.reserveConfiguration.getDecimals() -
            ReserveConfiguration.DEBT_CEILING_DECIMALS)).toUint128();
      emit IsolationModeTotalDebtUpdated(
        isolationModeCollateralAddress,
        nextIsolationModeTotalDebt
      );
    }

    reserve.updateInterestRates(
      reserveCache,
      asset,
      0,
      releaseUnderlying ? amount : 0
    );

    if (releaseUnderlying) {
      IMToken(reserveCache.mTokenAddress).transferUnderlyingTo(user, amount);
    }

    emit Borrow(
      asset,
      user,
      onBehalfOf,
      amount,
      interestRateMode,
      interestRateMode == DataTypes.InterestRateMode.STABLE
        ? currentStableRate
        : reserve.currentVariableBorrowRate,
      referralCode
    );
  }

  function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf,
    bool useMTokens
  ) internal returns (uint256) {
    LayoutTypes.PoolLayout storage s = layout();

    DataTypes.UserConfigurationMap storage userConfig = s._usersConfig[
      onBehalfOf
    ];
    DataTypes.ReserveData storage reserve = s._reserves[asset];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    reserve.updateState(reserveCache);

    (uint256 stableDebt, uint256 variableDebt) = Helpers.getUserCurrentDebt(
      onBehalfOf,
      reserveCache
    );

    ValidationLogic.validateRepay(
      reserveCache,
      amount,
      interestRateMode,
      onBehalfOf,
      stableDebt,
      variableDebt
    );

    uint256 paybackAmount = interestRateMode ==
      DataTypes.InterestRateMode.STABLE
      ? stableDebt
      : variableDebt;

    // Allows a user to repay with aTokens without leaving dust from interest.
    if (useMTokens && amount == type(uint256).max) {
      amount = IMToken(reserveCache.mTokenAddress).balanceOf(msg.sender);
    }

    if (amount < paybackAmount) {
      paybackAmount = amount;
    }

    if (interestRateMode == DataTypes.InterestRateMode.STABLE) {
      (
        reserveCache.nextTotalStableDebt,
        reserveCache.nextAvgStableBorrowRate
      ) = IStableDebtToken(reserveCache.stableDebtTokenAddress).burn(
        onBehalfOf,
        paybackAmount
      );
    } else {
      reserveCache.nextScaledVariableDebt = IVariableDebtToken(
        reserveCache.variableDebtTokenAddress
      ).burn(onBehalfOf, paybackAmount, reserveCache.nextVariableBorrowIndex);
    }

    reserve.updateInterestRates(
      reserveCache,
      asset,
      useMTokens ? 0 : paybackAmount,
      0
    );

    if (stableDebt + variableDebt - paybackAmount == 0) {
      userConfig.setBorrowing(reserve.id, false);
    }

    IsolationModeLogic.updateIsolatedDebtIfIsolated(
      s,
      userConfig,
      reserveCache,
      paybackAmount
    );

    if (useMTokens) {
      IMToken(reserveCache.mTokenAddress).burn(
        msg.sender,
        reserveCache.mTokenAddress,
        paybackAmount,
        reserveCache.nextLiquidityIndex
      );
    } else {
      IERC20(asset).safeTransferFrom(
        msg.sender,
        reserveCache.mTokenAddress,
        paybackAmount
      );
      IMToken(reserveCache.mTokenAddress).handleRepayment(
        msg.sender,
        paybackAmount
      );
    }

    emit Repay(asset, onBehalfOf, msg.sender, paybackAmount, useMTokens);

    return paybackAmount;
  }

  function getReserveNormalizedIncome(
    LayoutTypes.PoolLayout storage s,
    address asset
  ) internal view returns (uint256) {
    DataTypes.ReserveData memory reserve = s._reserves[asset];

    if (reserve.lastUpdateTimestamp == block.timestamp) {
      return reserve.liquidityIndex;
    } else {
      return
        MathUtils
          .calculateLinearInterest(
            reserve.currentLiquidityRate,
            reserve.lastUpdateTimestamp
          )
          .rayMul(reserve.liquidityIndex);
    }
  }

  /**
   * @notice Returns the ongoing normalized variable debt for the reserve.
   * @dev A value of 1e27 means there is no debt. As time passes, the debt is accrued
   * @dev A value of 2*1e27 means that for each unit of debt, one unit worth of interest has been accumulated
   * @param asset Underlying asset of reserve
   * @return The normalized variable debt, expressed in ray
   **/
  function getNormalizedDebt(LayoutTypes.PoolLayout storage s, address asset)
    internal
    view
    returns (uint256)
  {
    DataTypes.ReserveData memory reserve = s._reserves[asset];

    uint40 timestamp = reserve.lastUpdateTimestamp;

    //solium-disable-next-line
    if (timestamp == block.timestamp) {
      //if the index was updated in the same block, no need to perform any calculation
      return reserve.variableBorrowIndex;
    } else {
      return
        MathUtils
          .calculateCompoundedInterest(
            reserve.currentVariableBorrowRate,
            timestamp
          )
          .rayMul(reserve.variableBorrowIndex);
    }
  }
}
