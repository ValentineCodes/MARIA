// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title IAddressProvider
 * @author Maria
 * @notice Interface of Maria address provider
 **/
interface IAddressProvider {
  function initialize(string memory marketId) external;

  function getMarketId() external view returns (string memory);

  function setMarketId(string memory newMarketId) external;

  function getAddress(bytes32 id) external view returns (address);

  function setAddress(bytes32 id, address newAddress) external;

  function getPool() external view returns (address);

  function setPool(address newPool) external;

  function getPoolConfigurator() external view returns (address);

  function setPoolConfigurator(address newPoolConfigurator) external;

  function getPriceOracle() external view returns (address);

  function setPriceOracle(address newPriceOracle) external;

  function getACLManager() external view returns (address);

  function setACLManager(address newAclManager) external;

  function getACLAdmin() external view returns (address);

  function setACLAdmin(address newAclAdmin) external;

  function getPriceOracleSentinel() external view returns (address);

  function setPriceOracleSentinel(address newPriceOracleSentinel) external;

  function getPoolDataProvider() external view returns (address);

  function setPoolDataProvider(address newDataProvider) external;
}
