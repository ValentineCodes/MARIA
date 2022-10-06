// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import { LibPool } from "../../../libraries/facets/LibPool.sol";
import { DataTypes } from "../../../libraries/types/DataTypes.sol";
import { LayoutTypes } from "../../../libraries/types/LayoutTypes.sol";
import { OwnableInternal } from "../../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import { IERC20WithPermit } from "../../../interfaces/IERC20WithPermit.sol";
import { IAddressProvider } from "../../../interfaces/IAddressProvider.sol";
import { IPool } from "../../../interfaces/IPool.sol";

contract Pool is IPool, OwnableInternal {
  using LibPool for LayoutTypes.PoolLayout;

  IAddressProvider public immutable ADDRESS_PROVIDER;

  constructor(address addressProvider) {
    ADDRESS_PROVIDER = IAddressProvider(addressProvider);
  }

  function initialize(address addressProvider) external onlyOwner {
    LibPool.initialize(addressProvider);
  }

  /// @inheritdoc IPool
  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external override {
    LibPool.supply(asset, amount, onBehalfOf, referralCode);
  }

  /// @inheritdoc IPool
  function supplyWithPermit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external override {
    IERC20WithPermit(asset).permit(
      msg.sender,
      address(this),
      amount,
      deadline,
      permitV,
      permitR,
      permitS
    );

    LibPool.supply(asset, amount, onBehalfOf, referralCode);
  }

  /// @inheritdoc IPool
  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external override returns (uint256) {
    return LibPool.withdraw(asset, amount, to);
  }

  /// @inheritdoc IPool
  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external override {
    LibPool.borrow(asset, amount, interestRateMode, referralCode, onBehalfOf);
  }

  /// @inheritdoc IPool
  function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) external override returns (uint256) {
    return LibPool.repay(asset, amount, interestRateMode, onBehalfOf, false);
  }

  /// @inheritdoc IPool
  function repayWithPermit(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external override returns (uint256) {
    IERC20WithPermit(asset).permit(
      msg.sender,
      address(this),
      amount,
      deadline,
      permitV,
      permitR,
      permitS
    );

    return LibPool.repay(asset, amount, interestRateMode, onBehalfOf, false);
  }

  /// @inheritdoc IPool
  function repayWithMTokens(
    address asset,
    uint256 amount,
    uint256 interestRateMode
  ) external override returns (uint256) {
    return LibPool.repay(asset, amount, interestRateMode, onBehalfOf, true);
  }

  /// @inheritdoc IPool
  function swapBorrowRateMode(address asset, uint256 interestRateMode)
    external
    override
  {
    LibPool.swapBorrowRateMode(asset, interestRateMode);
  }

  /// @inheritdoc IPool
  function rebalanceStableBorrowRate(address asset, address user)
    external
    override
  {
    LibPool.rebalanceStableBorrowRate(asset, user);
  }

  /// @inheritdoc IPool
  function setUserUseReserveAsCollateral(address asset, bool useAsCollateral)
    external
    override
  {
    LibPool.setUserUseReserveAsCollateral(asset, useAsCollateral);
  }

  /// @inheritdoc IPool
  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveMToken
  ) external override {
    LibPool.liquidationCall(
      collateralAsset,
      debtAsset,
      user,
      debtToCover,
      receiveMToken
    );
  }

  /// @inheritdoc IPool
  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata interestRateModes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external override {
    LibPool.flashLoan(
      receiverAddress,
      assets,
      amounts,
      interestRateModes,
      onBehalfOf,
      params,
      referralCode
    );
  }

  /// @inheritdoc IPool
  function flashLoanSimple(
    address receiverAddress,
    address asset,
    uint256 amount,
    bytes calldata params,
    uint16 referralCode
  ) external override {
    LibPool.flashLoanSimple(
      receiverAddress,
      asset,
      amount,
      params,
      referralCode
    );
  }

  /// @inheritdoc IPool
  function mintToTreasury(address[] calldata assets) external override {
    LibPool.mintToTreasury(assets);
  }

  /// @inheritdoc IPool
  function getReserveData(address asset)
    external
    view
    override
    returns (DataTypes.ReserveData memory)
  {
    return LibPool.getReserveData(asset);
  }

  /// @inheritdoc IPool
  function getUserAccountData(address user)
    external
    view
    override
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    )
  {
    return LibPool.getUserAccountData(user);
  }

  /// @inheritdoc IPool
  function getConfiguration(address asset)
    external
    view
    override
    returns (DataTypes.ReserveConfigurationMap memory)
  {
    return LibPool.getConfiguration(asset);
  }

  /// @inheritdoc IPool
  function getUserConfiguration(address user)
    external
    view
    override
    returns (DataTypes.UserConfigurationMap memory)
  {
    return LibPool.getUserConfiguration(user);
  }

  /// @inheritdoc IPool
  function getReserveNormalizedIncome(address asset)
    external
    view
    override
    returns (uint256)
  {
    return LibPool.getReserveNormalizedIncome(asset);
  }

  /// @inheritdoc IPool
  function getReserveNormalizedVariableDebt(address asset)
    external
    view
    override
    returns (uint256)
  {
    return LibPool.getNormalizedDebt(asset);
  }

  /// @inheritdoc IPool
  function getReservesList() external view override returns (address[] memory) {
    return LibPool.getReservesList();
  }

  /// @inheritdoc IPool
  function getReserveAddressById(uint16 id) external view returns (address) {
    return LibPool.getReserveAddressById(id);
  }

  /// @inheritdoc IPool
  function MAX_STABLE_RATE_BORROW_SIZE_PERCENT()
    external
    view
    override
    returns (uint256)
  {
    return LibPool.MAX_STABLE_RATE_BORROW_SIZE_PERCENT();
  }

  /// @inheritdoc IPool
  function BRIDGE_PROTOCOL_FEE() external view override returns (uint256) {
    return LibPool.BRIDGE_PROTOCOL_FEE();
  }

  /// @inheritdoc IPool
  function FLASHLOAN_PREMIUM_TOTAL() external view override returns (uint128) {
    return LibPool.FLASHLOAN_PREMIUM_TOTAL();
  }

  /// @inheritdoc IPool
  function FLASHLOAN_PREMIUM_TO_PROTOCOL()
    external
    view
    override
    returns (uint128)
  {
    return LibPool.FLASHLOAN_PREMIUM_TO_PROTOCOL();
  }

  /// @inheritdoc IPool
  function MAX_NUMBER_RESERVES() external view override returns (uint16) {
    return LibPool.MAX_NUMBER_RESERVES();
  }

  /// @inheritdoc IPool
  function finalizeTransfer(
    address asset,
    address from,
    address to,
    uint256 amount,
    uint256 balanceFromBefore,
    uint256 balanceToBefore
  ) external override {
    LibPool.finalizeTransfer(
      asset,
      from,
      to,
      amount,
      balanceFromBefore,
      balanceToBefore
    );
  }
}
