// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { OwnableInternal } from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import { LibAddressProvider } from "../../libraries/facets/LibAddressProvider.sol";
import { LayoutTypes } from "../../libraries/types/LayoutTypes.sol";

/**
 * @title AddressesProvider
 * @author Maria
 * @notice Main registry of addresses part of or connected to the protocol, including permissioned roles
 * @dev Owned by the Maria Governance
 **/
contract AddressProvider is OwnableInternal {
  using LibAddressProvider for LayoutTypes.AddressProviderLayout;

  function initialize(string memory marketId) external onlyOwner {
    LibAddressProvider.layout().initialize(marketId);
  }

  /// @inheritdoc IAddressesProvider
  function getMarketId() external view override returns (string memory) {
    return LibAddressProvider.layout()._marketId;
  }

  /// @inheritdoc IAddressesProvider
  function setMarketId(string memory newMarketId) external override onlyOwner {
    LibAddressProvider.layout()._setMarketId(newMarketId);
  }

  /// @inheritdoc IAddressesProvider
  function getAddress(bytes32 id) external view override returns (address) {
    return LibAddressProvider.getAddress(id);
  }

  /// @inheritdoc IAddressesProvider
  function setAddress(bytes32 id, address newAddress)
    external
    override
    onlyOwner
  {
    LibAddressProvider.setAddress(id, newAddress);
  }

  /// @inheritdoc IAddressesProvider
  function getPool() external view override returns (address) {
    return LibAddressProvider.getPool();
  }

  /// @inheritdoc IAddressesProvider
  function setPool(address newPool) external override onlyOwner {
    LibAddressProvider.setPool(newPool);
  }

  /// @inheritdoc IAddressesProvider
  function getPoolConfigurator() external view override returns (address) {
    return LibAddressProvider.getPoolConfigurator();
  }

  /// @inheritdoc IAddressesProvider
  function setPoolConfigurator(address newPoolConfigurator)
    external
    override
    onlyOwner
  {
    LibAddressProvider.setPoolConfigurator(address newPoolConfigurator);
  }

  /// @inheritdoc IAddressesProvider
  function getPriceOracle() external view override returns (address) {
    return LibAddressProvider.getPriceOracle();
  }

  /// @inheritdoc IAddressesProvider
  function setPriceOracle(address newPriceOracle) external override onlyOwner {
    LibAddressProvider.setPriceOracle(address newPriceOracle);
  }

  /// @inheritdoc IAddressesProvider
  function getACLManager() external view override returns (address) {
    return LibAddressProvider.getACLManager();
  }

  /// @inheritdoc IAddressesProvider
  function setACLManager(address newAclManager) external override onlyOwner {
    LibAddressProvider.setACLManager(address newAclManager);
  }

  /// @inheritdoc IAddressesProvider
  function getACLAdmin() external view override returns (address) {
    return LibAddressProvider.getACLAdmin();
  }

  /// @inheritdoc IAddressesProvider
  function setACLAdmin(address newAclAdmin) external override onlyOwner {
    LibAddressProvider.setACLAdmin(address newAclAdmin);
  }

  /// @inheritdoc IAddressesProvider
  function getPriceOracleSentinel() external view override returns (address) {
    return LibAddressProvider.getPriceOracleSentinel();
  }

  /// @inheritdoc IAddressesProvider
  function setPriceOracleSentinel(address newPriceOracleSentinel)
    external
    override
    onlyOwner
  {
    LibAddressProvider.setPriceOracleSentinel(address newPriceOracleSentinel);
  }

  /// @inheritdoc IAddressesProvider
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
