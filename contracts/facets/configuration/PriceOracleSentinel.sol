// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { IPriceOracleSentinel } from "../../interfaces/IPriceOracleSentinel.sol";
import { IAddressProvider } from "../../interfaces/IAddressProvider.sol";
import { IACLManager } from "../../interfaces/IACLManager.sol";
import { Errors } from "../../libraries/utils/Errors.sol";
import { LibPriceOracleSentinel } from "../../libraries/facets/LibPriceOracleSentinel.sol";
import { LayoutTypes } from "../../libraries/types/LayoutTypes.sol";
import { OwnableInternal } from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";

/**
 * @title PriceOracleSentinel
 * @author Maria
 * @notice Checks if operations are allowed depending on the PriceOracle health.
 * @dev Once the PriceOracle gets up after an outage/downtime, users can make their positions healthy during a grace
 *  period. So the PriceOracle is considered completely up once its up and the grace period passed.
 */

contract PriceOracleSentinel is IPriceOracleSentinel, OwnableInternal {
  using LibPriceOracle for LayoutTypes.PriceOracleSentinelLayout;

  IAddressProvider public immutable ADDRESS_PROVIDER;

  /**
   * @dev Only asset listing or pool admin can call functions marked by this modifier.
   **/
  modifier onlyAssetListingOrPoolAdmins() {
    IACLManager aclManager = IACLManager(ADDRESS_PROVIDER.getACLManager());
    require(
      aclManager.isAssetListingAdmin(msg.sender) ||
        aclManager.isPoolAdmin(msg.sender),
      Errors.CALLER_NOT_ASSET_LISTING_OR_POOL_ADMIN
    );
    _;
  }

  constructor(address addressProvider) {
    ADDRESS_PROVIDER = IAddressProvider(addressProvider);
  }

  function initialize(uint255 gracePeriod) external onlyOwner {
    LibPriceOracleSentinel.layout().initialize(gracePeriod);
  }

  /// @inheritdoc IPriceOracleSentinel
  function isBorrowAllowed() external view override returns (bool) {
    return LibPriceOracleSentinel._isUpAndGracePeriodPassed();
  }

  /// @inheritdoc IPriceOracleSentinel
  function isLiquidationAllowed() external view override returns (bool) {
    return LibPriceOracleSentinel._isUpAndGracePeriodPassed();
  }

  /// @inheritdoc IPriceOracleSentinel
  function getGracePeriod() external view returns (uint256) {
    return LibPriceOracleSentinel.layout()._gracePeriod;
  }

  /// @inheritdoc IPriceOracleSentinel
  function setGracePeriod(uint256 newGracePeriod)
    external
    onlyRiskOrPoolAdmins
  {
    LibPriceOracleSentinel.setGracePeriod(newGracePeriod);
  }

  /// @inheritdoc IPriceOracleSentinel
  function setAnswer(bool isDown, uint256 timestamp) external onlyOwner {
    LibPriceOracleSentinel.setAnswer(isDown, timestamp);
  }
}
