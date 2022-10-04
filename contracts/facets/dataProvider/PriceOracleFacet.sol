// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { IPriceOracle } from "../../interfaces/IPriceOracle.sol";
import { IAddressProvider } from "../../interfaces/IAddressProvider.sol";
import { IACLManager } from "../../interfaces/IACLManager.sol";
import { Errors } from "../../libraries/utils/Errors.sol";
import { LibPriceOracle } from "../../libraries/facets/LibPriceOracle.sol";
import { LayoutTypes } from "../../libraries/types/LayoutTypes.sol";
import { OwnableInternal } from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";

/**
 * @title PriceOracle
 * @author Maria
 * @notice This gets asset prices from Chainlink Aggregators and manages asset sources
 * - Owned by the Maria governance
 */

contract PriceOracle is OwnableInternal {
  using LibPriceOracle for LayoutTypes.PriceOracleLayout;

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

  function initialize(
    address[] memory assets,
    address[] memory sources,
  ) external onlyOwner {
    LibPriceOracle.layout().initialize(assets, sources);
  }

  /// @inheritdoc IPriceOracle
  function setAssetSources(
    address[] calldata assets,
    address[] calldata sources
  ) external override onlyAssetListingOrPoolAdmins {
    LibPriceOracle._setAssetsSources(assets, sources);
  }

  /// @inheritdoc IPriceOracleGetter
  function getAssetPrice(address asset)
    external
    view
    override
    returns (uint256)
  {
    return LibPriceOracle.getAssetPrice(asset);
  }

  /// @inheritdoc IPriceOracle
  function getAssetsPrices(address[] calldata assets)
    external
    view
    override
    returns (uint256[] memory)
  {
    return LibPriceOracle.getAssetsPrices(assets);
  }

  /// @inheritdoc IPriceOracle
  function getAssetSource(address asset)
    external
    view
    override
    returns (address)
  {
    return LibPriceOracle.getAssetSource(asset);
  }
}
