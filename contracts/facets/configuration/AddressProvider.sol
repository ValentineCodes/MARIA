// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { OwnableInternal } from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import { LibAddressProvider } from "../../libraries/facets/LibAddressProvider.sol";
import { LayoutTypes } from "../../libraries/types/LayoutTypes.sol";
import {IAddressProvider} from "../../interfaces/IAddressProvider.sol";

/**
 * @title AddressesProvider
 * @author Maria
 * @notice Main registry of addresses part of or connected to the protocol, including permissioned roles
 * @dev Owned by the Maria Governance
 **/
contract AddressProvider is IAddressProvider, OwnableInternal {
  using LibAddressProvider for LayoutTypes.AddressProviderLayout;

  function initialize(string memory marketId) external onlyOwner {
    LibAddressProvider.layout().initialize(marketId);
  }

  /// @inheritdoc IAddressProvider
  function getMarketId() external view override returns (string memory) {
    return LibAddressProvider.layout()._marketId;
  }

  /// @inheritdoc IAddressProvider
  function setMarketId(string memory newMarketId) external override onlyOwner {
    LibAddressProvider.layout()._setMarketId(newMarketId);
  }

  /// @inheritdoc IAddressProvider
  function getAddress(bytes32 id) external view override returns (address) {
    return LibAddressProvider.getAddress(id);
  }

  /// @inheritdoc IAddressProvider
  function setAddress(bytes32 id, address newAddress)
    external
    override
    onlyOwner
  {
    LibAddressProvider.setAddress(id, newAddress);
  }

  /// @inheritdoc IAddressProvider
  function getPool() external view override returns (address) {
    return LibAddressProvider.getPool();
  }

  /// @inheritdoc IAddressProvider
  function setPool(address newPool) external override onlyOwner {
    LibAddressProvider.setPool(newPool);
  }

  /// @inheritdoc IAddressProvider
  function getPoolConfigurator() external view override returns (address) {
    return LibAddressProvider.getPoolConfigurator();
  }

  /// @inheritdoc IAddressProvider
  function setPoolConfigurator(address newPoolConfigurator)
    external
    override
    onlyOwner
  {
    LibAddressProvider.setPoolConfigurator(address newPoolConfigurator);
  }

  /// @inheritdoc IAddressProvider
  function getPriceOracle() external view override returns (address) {
    return LibAddressProvider.getPriceOracle();
  }

  /// @inheritdoc IAddressProvider
  function setPriceOracle(address newPriceOracle) external override onlyOwner {
    LibAddressProvider.setPriceOracle(address newPriceOracle);
  }

  /// @inheritdoc IAddressProvider
  function getACLManager() external view override returns (address) {
    return LibAddressProvider.getACLManager();
  }

  /// @inheritdoc IAddressProvider
  function setACLManager(address newAclManager) external override onlyOwner {
    LibAddressProvider.setACLManager(address newAclManager);
  }

  /// @inheritdoc IAddressProvider
  function getACLAdmin() external view override returns (address) {
    return LibAddressProvider.getACLAdmin();
  }

  /// @inheritdoc IAddressProvider
  function setACLAdmin(address newAclAdmin) external override onlyOwner {
    LibAddressProvider.setACLAdmin(address newAclAdmin);
  }

  /// @inheritdoc IAddressProvider
  function getPriceOracleSentinel() external view override returns (address) {
    return LibAddressProvider.getPriceOracleSentinel();
  }

  /// @inheritdoc IAddressProvider
  function setPriceOracleSentinel(address newPriceOracleSentinel)
    external
    override
    onlyOwner
  {
    LibAddressProvider.setPriceOracleSentinel(address newPriceOracleSentinel);
  }

  /// @inheritdoc IAddressProvider
  function getPoolDataProvider() external view override returns (address) {
    return LibAddressProvider.getPoolDataProvider();
  }

  function setPoolDataProvider(address newDataProvider)
    external
    override
    onlyOwner
  {
    LibAddressProvider.setPoolDataProvider(address newDataProvider);
  }
}
