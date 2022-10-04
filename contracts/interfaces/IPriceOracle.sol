// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title IAddressProvider
 * @author Maria
 * @notice Interface of Maria price oracle
 **/
interface IPriceOracle {
  function initialize(
    address[] memory assets,
    address[] memory sources,
  ) external;


  function setAssetSources(
    address[] calldata assets,
    address[] calldata sources
  ) external;

  /// @inheritdoc IPriceOracleGetter
  function getAssetPrice(address asset)
    external
    view
    returns (uint256);


  function getAssetsPrices(address[] calldata assets)
    external
    view
    returns (uint256[] memory);


  function getAssetSource(address asset)
    external
    view
    returns (address);
}
