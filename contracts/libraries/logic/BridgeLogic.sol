// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import { IERC20 } from "../../../dependencies/openzeppelin/contracts/IERC20.sol";
import { GPv2SafeERC20 } from "../../../dependencies/gnosis/contracts/GPv2SafeERC20.sol";
import { SafeCast } from "../../../dependencies/openzeppelin/contracts/SafeCast.sol";
import { IMToken } from "../../../interfaces/IMToken.sol";
import { DataTypes } from "../types/DataTypes.sol";
import { UserConfiguration } from "../configuration/UserConfiguration.sol";
import { ReserveConfiguration } from "../configuration/ReserveConfiguration.sol";
import { WadRayMath } from "../math/WadRayMath.sol";
import { PercentageMath } from "../math/PercentageMath.sol";
import { Errors } from "../helpers/Errors.sol";
import { ValidationLogic } from "./ValidationLogic.sol";
import { ReserveLogic } from "./ReserveLogic.sol";

library BridgeLogic {
  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for uint256;
  using GPv2SafeERC20 for IERC20;

  // See `IPool` for descriptions
  event ReserveUsedAsCollateralEnabled(
    address indexed reserve,
    address indexed user
  );
  event MintUnbacked(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );
  event BackUnbacked(
    address indexed reserve,
    address indexed backer,
    uint256 amount,
    uint256 fee
  );

  /**
   * @notice Mint unbacked aTokens to a user and updates the unbacked for the reserve.
   * @dev Essentially a supply without transferring the underlying.
   * @dev Emits the `MintUnbacked` event
   * @dev Emits the `ReserveUsedAsCollateralEnabled` if asset is set as collateral
   * @param reservesData The state of all the reserves
   * @param reservesList The addresses of all the active reserves
   * @param userConfig The user configuration mapping that tracks the supplied/borrowed assets
   * @param asset The address of the underlying asset to mint aTokens of
   * @param amount The amount to mint
   * @param onBehalfOf The address that will receive the aTokens
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function executeMintUnbacked(
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(uint256 => address) storage reservesList,
    DataTypes.UserConfigurationMap storage userConfig,
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external {
    DataTypes.ReserveData storage reserve = reservesData[asset];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    // Updates the liquidity index and the variable borrow index
    reserve.updateState(reserveCache);

    ValidationLogic.validateSupply(reserveCache, amount);

    uint256 unbackedMintCap = reserveCache
      .reserveConfiguration
      .getUnbackedMintCap();
    uint256 reserveDecimals = reserveCache.reserveConfiguration.getDecimals();

    // Stores aToken amount in reserve and total unbacked aToken amount in memory
    uint256 unbacked = reserve.unbacked += amount.toUint128();

    // Ensures the current unbacked aTokens count does not exceed the mint cap
    require(
      unbacked <= unbackedMintCap * (10**reserveDecimals),
      Errors.UNBACKED_MINT_CAP_EXCEEDED
    );

    // Updates the liquidity, borrow and supply interest rates
    reserve.updateInterestRates(reserveCache, asset, 0, 0);

    // Mint aTokens to recipient and returns true if previous recipient balance was 0
    bool isFirstSupply = IMToken(reserveCache.mTokenAddress).mint(
      msg.sender,
      onBehalfOf,
      amount,
      reserveCache.nextLiquidityIndex
    );

    if (isFirstSupply) {
      // Enables asset to be used as collateral if asset is not in isolation mode and debt ceiling is 0
      if (
        ValidationLogic.validateUseAsCollateral(
          reservesData,
          reservesList,
          userConfig,
          reserveCache.reserveConfiguration
        )
      ) {
        userConfig.setUsingAsCollateral(reserve.id, true);
        emit ReserveUsedAsCollateralEnabled(asset, onBehalfOf);
      }
    }

    emit MintUnbacked(asset, msg.sender, onBehalfOf, amount, referralCode);
  }

  /**
   * @notice Back the current unbacked with `amount` and pay `fee`.
   * @dev Emits the `BackUnbacked` event
   * @param reserve The reserve to back unbacked for
   * @param asset The address of the underlying asset to repay
   * @param amount The amount to back
   * @param fee The amount paid in fees
   * @param protocolFeeBps The fraction of fees in basis points paid to the protocol
   **/
  function executeBackUnbacked(
    DataTypes.ReserveData storage reserve,
    address asset,
    uint256 amount,
    uint256 fee,
    uint256 protocolFeeBps
  ) external {
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    // Updates the liquidity index and the variable borrow index
    reserve.updateState(reserveCache);

    uint256 backingAmount = (amount < reserve.unbacked)
      ? amount
      : reserve.unbacked;

    uint256 feeToProtocol = fee.percentMul(protocolFeeBps);
    uint256 feeToLP = fee - feeToProtocol;
    uint256 added = backingAmount + fee; // Amount of aTokens to back plus fee

    // Accumulate fee to the reserve
    reserveCache.nextLiquidityIndex = reserve.cumulateToLiquidityIndex(
      IERC20(reserveCache.mTokenAddress).totalSupply(),
      feeToLP
    );

    reserve.accruedToTreasury += feeToProtocol
      .rayDiv(reserveCache.nextLiquidityIndex)
      .toUint128();

    reserve.unbacked -= backingAmount.toUint128();

    // Updates the liquidity, borrow and supply interest rates
    reserve.updateInterestRates(reserveCache, asset, added, 0);

    // Transfers the asset to the mTokenAddress
    IERC20(asset).safeTransferFrom(
      msg.sender,
      reserveCache.mTokenAddress,
      added
    );

    emit BackUnbacked(asset, msg.sender, backingAmount, fee);
  }
}
