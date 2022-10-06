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
import { IAddressProvider } from '../../interfaces/IAddressProvider.sol';
import { Errors } from "../utils/Errors.sol";
import { Helpers } from "../utils/Helpers.sol";
import { MathUtils } from "../math/MathUtils.sol";
import { WadRayMath } from "../math/WadRayMath.sol";
import { PercentageMath } from "../math/PercentageMath.sol";
import { ValidationLogic } from "../logic/ValidationLogic.sol";
import { ReserveLogic } from "../logic/ReserveLogic.sol";
import { EModeLogic } from '../logic/EModeLogic.sol';
import { SupplyLogic } from '../logic/SupplyLogic.sol';
import { FlashLoanLogic } from '../logic/FlashLoanLogic.sol';
import { BorrowLogic } from '../logic/BorrowLogic.sol';
import { LiquidationLogic } from '../logic/LiquidationLogic.sol';
import { BridgeLogic } from '../logic/BridgeLogic.sol';
import { PoolLogic } from "../logic/PoolLogic.sol";
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

  IAddressProvider internal immutable ADDRESS_PROVIDER;

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
  function initialize(address addressProvider) internal initializer(s) {
    LayoutTypes.PoolLayout storage s = layout();

    ADDRESS_PROVIDER = IAddressProvider(addressProvider);

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

    SupplyLogic.executeSupply(
      s._reserves,
      s._reservesList,
      s._usersConfig[onBehalfOf],
      DataTypes.ExecuteSupplyParams({
          asset: asset,
          amount: amount,
          onBehalfOf: onBehalfOf,
          referralCode: referralCode
    })
  }

  function withdraw(
        address asset,
        uint256 amount,
        address to
    ) internal returns (uint256) {
    LayoutTypes.PoolLayout storage s = layout();

    return
      SupplyLogic.executeWithdraw(
        s._reserves,
        s._reservesList,
        s._eModeCategories,
        s._usersConfig[msg.sender],
        DataTypes.ExecuteWithdrawParams({
          asset: asset,
          amount: amount,
          to: to,
          reservesCount: s._reservesCount,
          oracle: ADDRESS._PROVIDER.getPriceOracle(),
          userEModeCategory: s._usersEModeCategory[msg.sender]
        })
      );
  }

  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) internal {
    LayoutTypes.PoolLayout storage s = layout();

    BorrowLogic.executeBorrow(
      s._reserves,
      s._reservesList,
      s._eModeCategories,
      s._usersConfig[onBehalfOf],
      DataTypes.ExecuteBorrowParams({
        asset: asset,
        user: msg.sender,
        onBehalfOf: onBehalfOf,
        amount: amount,
        interestRateMode: DataTypes.InterestRateMode(interestRateMode),
        referralCode: referralCode,
        releaseUnderlying: true,
        maxStableRateBorrowSizePercent: s._maxStableRateBorrowSizePercent,
        reservesCount: s._reservesCount,
        oracle: ADDRESS_PROVIDER.getPriceOracle(),
        userEModeCategory: s._usersEModeCategory[onBehalfOf],
        priceOracleSentinel: ADDRESS_PROVIDER.getPriceOracleSentinel()
      })
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

    return
      BorrowLogic.executeRepay(
        s._reserves,
        s._reservesList,
        s._usersConfig[onBehalfOf],
        DataTypes.ExecuteRepayParams({
          asset: asset,
          amount: amount,
          interestRateMode: DataTypes.InterestRateMode(interestRateMode),
          onBehalfOf: onBehalfOf,
          useMTokens: useMTokens
        })
      );
  }

  function swapBorrowRateMode(
    address asset, uint256 interestRateMode
  ) internal {
    LayoutTypes.PoolLayout storage s = layout();

    BorrowLogic.executeSwapBorrowRateMode(
      s._reserves[asset],
      s._usersConfig[msg.sender],
      asset,
      DataTypes.InterestRateMode(interestRateMode)
    );
  }

  function rebalanceStableBorrowRate(address asset, address user) internal {
    LayoutTypes.PoolLayout storage s = layout();

    BorrowLogic.executeRebalanceStableBorrowRate(s._reserves[asset], asset, user);
  }

  
  function setUserUseReserveAsCollateral(address asset, bool useAsCollateral)
    internal
  {
    LayoutTypes.PoolLayout storage s = layout();

    SupplyLogic.executeUseReserveAsCollateral(
      s._reserves,
      s._reservesList,
      s._eModeCategories,
      s._usersConfig[msg.sender],
      asset,
      useAsCollateral,
      s._reservesCount,
      ADDRESS_PROVIDER.getPriceOracle(),
      s._usersEModeCategory[msg.sender]
    );
  }

  
  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveAToken
  ) internal {
    LayoutTypes.PoolLayout storage s = layout();

    LiquidationLogic.executeLiquidationCall(
      s._reserves,
      s._reservesList,
      s._usersConfig,
      s._eModeCategories,
      DataTypes.ExecuteLiquidationCallParams({
        reservesCount: s._reservesCount,
        debtToCover: debtToCover,
        collateralAsset: collateralAsset,
        debtAsset: debtAsset,
        user: user,
        receiveAToken: receiveAToken,
        priceOracle: ADDRESS_PROVIDER.getPriceOracle(),
        userEModeCategory: s._usersEModeCategory[user],
        priceOracleSentinel: ADDRESS_PROVIDER.getPriceOracleSentinel()
      })
    );
  }

  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata interestRateModes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) internal {
    LayoutTypes.PoolLayout storage s = layout();

    DataTypes.FlashloanParams memory flashParams = DataTypes.FlashloanParams({
      receiverAddress: receiverAddress,
      assets: assets,
      amounts: amounts,
      interestRateModes: interestRateModes,
      onBehalfOf: onBehalfOf,
      params: params,
      referralCode: referralCode,
      flashLoanPremiumToProtocol: s._flashLoanPremiumToProtocol,
      flashLoanPremiumTotal: s._flashLoanPremiumTotal,
      maxStableRateBorrowSizePercent: s._maxStableRateBorrowSizePercent,
      reservesCount: s._reservesCount,
      addressesProvider: address(ADDRESS_PROVIDER),
      userEModeCategory: s._usersEModeCategory[onBehalfOf],
      isAuthorizedFlashBorrower: IACLManager(ADDRESS_PROVIDER.getACLManager()).isFlashBorrower(
        msg.sender
      )
    });

    FlashLoanLogic.executeFlashLoan(
      s._reserves,
      s._reservesList,
      s._eModeCategories,
      s._usersConfig[onBehalfOf],
      flashParams
    );
  }

  function flashLoanSimple(
    address receiverAddress,
    address asset,
    uint256 amount,
    bytes calldata params,
    uint16 referralCode
  ) internal {
    LayoutTypes.PoolLayout storage s = layout();

    DataTypes.FlashloanSimpleParams memory flashParams = DataTypes.FlashloanSimpleParams({
      receiverAddress: receiverAddress,
      asset: asset,
      amount: amount,
      params: params,
      referralCode: referralCode,
      flashLoanPremiumToProtocol: s._flashLoanPremiumToProtocol,
      flashLoanPremiumTotal: s._flashLoanPremiumTotal
    });

    FlashLoanLogic.executeFlashLoanSimple(s._reserves[asset], flashParams);
  }

  function mintToTreasury(address[] calldata assets) internal {
    LayoutTypes.PoolLayout storage s = layout();

    PoolLogic.executeMintToTreasury(s._reserves, assets);
  }

  
  function getReserveData(address asset)
    internal
    returns (DataTypes.ReserveData memory)
  {
    LayoutTypes.PoolLayout storage s = layout();

    return s._reserves[asset];
  }

  
  function getUserAccountData(address user)
    internal
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    )
  {
    LayoutTypes.PoolLayout storage s = layout();

    return
      PoolLogic.executeGetUserAccountData(
        s._reserves,
        s._reservesList,
        s._eModeCategories,
        DataTypes.CalculateUserAccountDataParams({
          userConfig: s._usersConfig[user],
          reservesCount: s._reservesCount,
          user: user,
          oracle: ADDRESS_PROVIDER.getPriceOracle(),
          userEModeCategory: s._usersEModeCategory[user]
        })
      );
  }

  
  function getConfiguration(address asset)
    internal
    returns (DataTypes.ReserveConfigurationMap memory)
  {
    LayoutTypes.PoolLayout storage s = layout();

    return s._reserves[asset].configuration;
  }

  
  function getUserConfiguration(address user)
    internal
    returns (DataTypes.UserConfigurationMap memory)
  {
    LayoutTypes.PoolLayout storage s = layout();

    return s._usersConfig[user];
  }

  
  function getReserveNormalizedIncome(address asset)
    internal
    returns (uint256)
  {
    LayoutTypes.PoolLayout storage s = layout();

    return s._reserves[asset].getNormalizedIncome();
  }

  
  function getReserveNormalizedVariableDebt(address asset)
    internal
    returns (uint256)
  {
    LayoutTypes.PoolLayout storage s = layout();

    return s._reserves[asset].getNormalizedDebt();
  }

  
  function getReservesList() internal returns (address[] memory) {
    LayoutTypes.PoolLayout storage s = layout();

    uint256 reservesListCount = s._reservesCount;
    uint256 droppedReservesCount = 0;
    address[] memory reservesList = new address[](reservesListCount);

    for (uint256 i = 0; i < reservesListCount; i++) {
      if (s._reservesList[i] != address(0)) {
        reservesList[i - droppedReservesCount] = s._reservesList[i];
      } else {
        droppedReservesCount++;
      }
    }

    // Reduces the length of the reserves array by `droppedReservesCount`
    assembly {
      mstore(reservesList, sub(reservesListCount, droppedReservesCount))
    }
    return reservesList;
  }

  
  function getReserveAddressById(uint16 id) internal view returns (address) {
    LayoutTypes.PoolLayout storage s = layout();

    return s._reservesList[id];
  }

  
  function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() internal returns (uint256) {
    LayoutTypes.PoolLayout storage s = layout();

    return s._maxStableRateBorrowSizePercent;
  }

  
  function BRIDGE_PROTOCOL_FEE() internal returns (uint256) {
    LayoutTypes.PoolLayout storage s = layout();

    return s._bridgeProtocolFee;
  }

  
  function FLASHLOAN_PREMIUM_TOTAL() internal returns (uint128) {
    LayoutTypes.PoolLayout storage s = layout();

    return s._flashLoanPremiumTotal;
  }

  
  function FLASHLOAN_PREMIUM_TO_PROTOCOL() internal returns (uint128) {
    LayoutTypes.PoolLayout storage s = layout();

    return s._flashLoanPremiumToProtocol;
  }

  
  function MAX_NUMBER_RESERVES() internal returns (uint16) {
    return ReserveConfiguration.MAX_RESERVES_COUNT;
  }

  
  function finalizeTransfer(
    address asset,
    address from,
    address to,
    uint256 amount,
    uint256 balanceFromBefore,
    uint256 balanceToBefore
  ) internal {
    LayoutTypes.PoolLayout storage s = layout();

    require(msg.sender == s._reserves[asset].mTokenAddress, Errors.CALLER_NOT_ATOKEN);
    SupplyLogic.executeFinalizeTransfer(
      s._reserves,
      s._reservesList,
      s._eModeCategories,
      s._usersConfig,
      DataTypes.FinalizeTransferParams({
        asset: asset,
        from: from,
        to: to,
        amount: amount,
        balanceFromBefore: balanceFromBefore,
        balanceToBefore: balanceToBefore,
        reservesCount: s._reservesCount,
        oracle: ADDRESS_PROVIDER.getPriceOracle(),
        fromEModeCategory: s._usersEModeCategory[from]
      })
    );
  }

  
  function initReserve(
    address asset,
    address mTokenAddress,
    address stableDebtAddress,
    address variableDebtAddress,
    address interestRateStrategyAddress
  ) internal {
    LayoutTypes.PoolLayout storage s = layout();
    
    if (
      PoolLogic.executeInitReserve(
        s._reserves,
        s._reservesList,
        DataTypes.InitReserveParams({
          asset: asset,
          mTokenAddress: mTokenAddress,
          stableDebtAddress: stableDebtAddress,
          variableDebtAddress: variableDebtAddress,
          interestRateStrategyAddress: interestRateStrategyAddress,
          reservesCount: s._reservesCount,
          maxNumberReserves: MAX_NUMBER_RESERVES()
        })
      )
    ) {
      s._reservesCount++;
    }
  }

  
  function dropReserve(address asset) internal {
    LayoutTypes.PoolLayout storage s = layout();

    PoolLogic.executeDropReserve(s._reserves, s._reservesList, asset);
  }

  
  function setReserveInterestRateStrategyAddress(address asset, address rateStrategyAddress)
    internal
  {
    LayoutTypes.PoolLayout storage s = layout();

    require(asset != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
    require(s._reserves[asset].id != 0 || s._reservesList[0] == asset, Errors.ASSET_NOT_LISTED);
    s._reserves[asset].interestRateStrategyAddress = rateStrategyAddress;
  }

  
  function setConfiguration(address asset, DataTypes.ReserveConfigurationMap calldata configuration)
    internal
  {
    require(asset != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
    require(s._reserves[asset].id != 0 || s._reservesList[0] == asset, Errors.ASSET_NOT_LISTED);
    s._reserves[asset].configuration = configuration;
  }

  
  function updateBridgeProtocolFee(uint256 protocolFee)
    internal
  {
    LayoutTypes.PoolLayout storage s = layout();

    s._bridgeProtocolFee = protocolFee;
  }

  
  function updateFlashloanPremiums(
    uint128 flashLoanPremiumTotal,
    uint128 flashLoanPremiumToProtocol
  ) internal {
    LayoutTypes.PoolLayout storage s = layout();

    s._flashLoanPremiumTotal = flashLoanPremiumTotal;
    s._flashLoanPremiumToProtocol = flashLoanPremiumToProtocol;
  }

  
  function configureEModeCategory(uint8 id, DataTypes.EModeCategory memory category)
    internal
  {
    // category 0 is reserved for volatile heterogeneous assets and it's always disabled
    require(id != 0, Errors.EMODE_CATEGORY_RESERVED);
    s._eModeCategories[id] = category;
  }

  
  function getEModeCategoryData(uint8 id)
    internal
    returns (DataTypes.EModeCategory memory)
  {
    LayoutTypes.PoolLayout storage s = layout();

    return s._eModeCategories[id];
  }

  
  function setUserEMode(uint8 categoryId) internal {
    LayoutTypes.PoolLayout storage s = layout();

    EModeLogic.executeSetUserEMode(
      s._reserves,
      s._reservesList,
      s._eModeCategories,
      s._usersEModeCategory,
      s._usersConfig[msg.sender],
      DataTypes.ExecuteSetUserEModeParams({
        reservesCount: s._reservesCount,
        oracle: ADDRESS_PROVIDER.getPriceOracle(),
        categoryId: categoryId
      })
    );
  }

  
  function getUserEMode(address user) internal returns (uint256) {
    LayoutTypes.PoolLayout storage s = layout();

    return s._usersEModeCategory[user];
  }

  
  function resetIsolationModeTotalDebt(address asset)
    internal
  {
    LayoutTypes.PoolLayout storage s = layout();

    PoolLogic.executeResetIsolationModeTotalDebt(s._reserves, asset);
  }

  
  function rescueTokens(
    address token,
    address to,
    uint256 amount
  ) internal {
    PoolLogic.executeRescueTokens(token, to, amount);
  }
}
