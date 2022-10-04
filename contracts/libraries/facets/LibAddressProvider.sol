// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { Strings } from "../../dependencies/openzeppelin/contracts/Strings.sol";
import { LayoutTypes } from "../types/LayoutTypes.sol";
import { Query } from "../utils/Query.sol";
import { Errors } from "../utils/Errors.sol";

library LibAddressProvider {
  uint256 internal immutable _chainId;

  bytes32 internal constant STORAGE_SLOT = keccak256("addressProvider.storage");
  // Main identifiers
  bytes32 private constant POOL = "POOL";
  bytes32 private constant POOL_CONFIGURATOR = "POOL_CONFIGURATOR";
  bytes32 private constant PRICE_ORACLE = "PRICE_ORACLE";
  bytes32 private constant ACL_MANAGER = "ACL_MANAGER";
  bytes32 private constant ACL_ADMIN = "ACL_ADMIN";
  bytes32 private constant PRICE_ORACLE_SENTINEL = "PRICE_ORACLE_SENTINEL";
  bytes32 private constant DATA_PROVIDER = "DATA_PROVIDER";

  /**
   * @dev Emitted when the market identifier is updated.
   * @param oldMarketId The old id of the market
   * @param newMarketId The new id of the market
   */
  event MarketIdSet(string indexed oldMarketId, string indexed newMarketId);

  /**
   * @dev Emitted when the pool is updated.
   * @param oldAddress The old address of the Pool
   * @param newAddress The new address of the Pool
   */
  event PoolUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the pool configurator is updated.
   * @param oldAddress The old address of the PoolConfigurator
   * @param newAddress The new address of the PoolConfigurator
   */
  event PoolConfiguratorUpdated(
    address indexed oldAddress,
    address indexed newAddress
  );

  /**
   * @dev Emitted when the price oracle is updated.
   * @param oldAddress The old address of the PriceOracle
   * @param newAddress The new address of the PriceOracle
   */
  event PriceOracleUpdated(
    address indexed oldAddress,
    address indexed newAddress
  );

  /**
   * @dev Emitted when the ACL manager is updated.
   * @param oldAddress The old address of the ACLManager
   * @param newAddress The new address of the ACLManager
   */
  event ACLManagerUpdated(
    address indexed oldAddress,
    address indexed newAddress
  );

  /**
   * @dev Emitted when the ACL admin is updated.
   * @param oldAddress The old address of the ACLAdmin
   * @param newAddress The new address of the ACLAdmin
   */
  event ACLAdminUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the price oracle sentinel is updated.
   * @param oldAddress The old address of the PriceOracleSentinel
   * @param newAddress The new address of the PriceOracleSentinel
   */
  event PriceOracleSentinelUpdated(
    address indexed oldAddress,
    address indexed newAddress
  );

  /**
   * @dev Emitted when the pool data provider is updated.
   * @param oldAddress The old address of the PoolDataProvider
   * @param newAddress The new address of the PoolDataProvider
   */
  event PoolDataProviderUpdated(
    address indexed oldAddress,
    address indexed newAddress
  );

  /**
   * @dev Emitted when a new non-proxied contract address is registered.
   * @param id The identifier of the contract
   * @param oldAddress The address of the old contract
   * @param newAddress The address of the new contract
   */
  event AddressSet(
    bytes32 indexed id,
    address indexed oldAddress,
    address indexed newAddress
  );

  modifier initializer(LayoutTypes.AddressProviderLayout storage s) {
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

  function layout()
    internal
    pure
    returns (LayoutTypes.AddressProviderLayout storage s)
  {
    bytes32 slot = STORAGE_SLOT;
    assembly {
      s.slot := slot
    }
  }

  /**
   * @notice Only called in the constructor of {MTokenFacet}
   * @param chainId Chain id of deployed contract
   */
  function _constructor(uint256 chainId) internal {
    _chainId = chainId;
  }

  function initialize(
    LayoutTypes.AddressProviderLayout storage s,
    string memory marketId
  ) internal initializer(s) {
    _setMarketId(s, marketId);
  }

  function getAddress(bytes32 id) internal view returns (address) {
    return layout()._addresses[id];
  }

  function setAddress(bytes32 id, address newAddress) internal {
    LayoutTypes.AddressProviderLayout storage s = layout();

    address oldAddress = s._addresses[id];
    s._addresses[id] = newAddress;
    emit AddressSet(id, oldAddress, newAddress);
  }

  function getPool() internal view returns (address) {
    return getAddress(POOL);
  }

  function setPool(address newPool) internal {
    LayoutTypes.AddressProviderLayout storage s = layout();

    address oldPool = s._addresses[POOL];
    s._addresses[POOL] = newPool;
    emit PoolUpdated(oldPool, newPool);
  }

  function getPoolConfigurator() internal view {
    return getAddress(POOL_CONFIGURATOR);
  }

  function setPoolConfigurator(address newPoolConfigurator) internal {
    LayoutTypes.AddressProviderLayout storage s = layout();

    address oldPoolConfigurator = s._addresses[POOL_CONFIGURATOR];
    s._addresses[POOL_CONFIGURATOR] = newPoolConfigurator;
    emit PoolConfiguratorUpdated(oldPoolConfigurator, newPoolConfigurator);
  }

  function getPriceOracle() internal view returns (address) {
    return getAddress(PRICE_ORACLE);
  }

  function setPriceOracle(address newPriceOracle) internal {
    LayoutTypes.AddressProviderLayout storage s = layout();

    address oldPriceOracle = s._addresses[PRICE_ORACLE];
    s._addresses[PRICE_ORACLE] = newPriceOracle;
    emit PriceOracleUpdated(oldPriceOracle, newPriceOracle);
  }

  function getACLManager() internal view returns (address) {
    return getAddress(ACL_MANAGER);
  }

  function setACLManager(address newAclManager) internal {
    LayoutTypes.AddressProviderLayout storage s = layout();

    address oldAclManager = s._addresses[ACL_MANAGER];
    s._addresses[ACL_MANAGER] = newAclManager;
    emit ACLManagerUpdated(oldAclManager, newAclManager);
  }

  function getACLAdmin() internal view returns (address) {
    return getAddress(ACL_ADMIN);
  }

  function setACLAdmin(address newAclAdmin) internal {
    LayoutTypes.AddressProviderLayout storage s = layout();

    address oldAclAdmin = s._addresses[ACL_ADMIN];
    s._addresses[ACL_ADMIN] = newAclAdmin;
    emit ACLAdminUpdated(oldAclAdmin, newAclAdmin);
  }

  function getPriceOracleSentinel() internal view returns (address) {
    return getAddress(PRICE_ORACLE_SENTINEL);
  }

  function setPriceOracleSentinel(address newPriceOracleSentinel) internal {
    LayoutTypes.AddressProviderLayout storage s = layout();

    address oldPriceOracleSentinel = s._addresses[PRICE_ORACLE_SENTINEL];
    s._addresses[PRICE_ORACLE_SENTINEL] = newPriceOracleSentinel;
    emit PriceOracleSentinelUpdated(
      oldPriceOracleSentinel,
      newPriceOracleSentinel
    );
  }

  function getPoolDataProvider() internal view returns (address) {
    return getAddress(DATA_PROVIDER);
  }

  function setPoolDataProvider(address newDataProvider) internal {
    LayoutTypes.AddressProviderLayout storage s = layout();

    address oldDataProvider = s._addresses[DATA_PROVIDER];
    s._addresses[DATA_PROVIDER] = newDataProvider;
    emit PoolDataProviderUpdated(oldDataProvider, newDataProvider);
  }

  /**
   * @notice Updates the identifier of the Maria market.
   * @param newMarketId The new id of the market
   **/
  function _setMarketId(
    LayoutTypes.AddressProviderLayout storage s,
    string memory newMarketId
  ) internal {
    string memory oldMarketId = s._marketId;
    s._marketId = newMarketId;
    emit MarketIdSet(oldMarketId, newMarketId);
  }
}
