// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { IMariaPriceOracle } from "../../interfaces/IMariaPriceOracle.sol";
import { IAddressProvider } from "../../interfaces/IAddressProvider.sol";
import { IACLManager } from "../../interfaces/IACLManager.sol";
import { Errors } from "../../libraries/utils/Errors.sol";
import { LibMariaPriceOracle } from "../../libraries/facets/LibMariaPriceOracle.sol";
import { LayoutTypes } from "../../libraries/types/LayoutTypes.sol";
import { OwnableInternal } from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";

/**
 * @title MariaPriceOracle
 * @author Maria
 * @notice This gets asset prices from Chainlink Aggregators and manages asset sources
 * - Owned by the Maria governance
 */

contract MariaPriceOracle is OwnableInternal {
  using LibMariaPriceOracle for LayoutTypes.MariaPriceOracleLayout;

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
    LibMariaPriceOracle.layout().initialize(assets, sources);
  }

  /// @inheritdoc IMariaPriceOracle
  function setAssetSources(
    address[] calldata assets,
    address[] calldata sources
  ) external override onlyAssetListingOrPoolAdmins {
    LibMariaPriceOracle._setAssetsSources(assets, sources);
  }

  /// @inheritdoc IPriceOracleGetter
  function getAssetPrice(address asset)
    external
    view
    override
    returns (uint256)
  {
    return LibMariaPriceOracle.getAssetPrice(asset);
  }

  /// @inheritdoc IMariaPriceOracle
  function getAssetsPrices(address[] calldata assets)
    external
    view
    override
    returns (uint256[] memory)
  {
    return LibMariaPriceOracle.getAssetsPrices(assets);
  }

  /// @inheritdoc IMariaPriceOracle
  function getAssetSource(address asset)
    external
    view
    override
    returns (address)
  {
    return LibMariaPriceOracle.getAssetSource(asset);
  }
}
