// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { LayoutTypes } from "../types/LayoutTypes.sol";
import { DataTypes } from "../types/DataTypes.sol";
import { Query } from "../utils/Query.sol";
import { IERC20 } from "../../dependencies/openzeppelin/contracts/IERC20.sol";
import { GPv2SafeERC20 } from "../../dependencies/gnosis/contracts/GPv2SafeERC20.sol";
import { IMToken } from "../../interfaces/IMToken.sol";
import { Errors } from "../utils/Errors.sol";
import { MathUtils } from "../math/MathUtils.sol";
import { WadRayMath } from "../math/WadRayMath.sol";
import { PercentageMath } from "../math/PercentageMath.sol";
import { ValidationLogic } from "../logic/ValidationLogic.sol";
import { ReserveLogic } from "../logic/ReserveLogic.sol";
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
          reservesCount,
          oracle,
          userEModeCategory
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
