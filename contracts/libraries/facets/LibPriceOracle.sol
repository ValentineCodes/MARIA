// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { AggregatorInterface } from "../../dependencies/chainlink/AggregatorInterface.sol";
import { LayoutTypes } from "../types/LayoutTypes.sol";
import { Query } from "../utils/Query.sol";
import { Errors } from "../utils/Errors.sol";

library LibPriceOracle {
  /**
   * @dev Emitted after the price source of an asset is updated
   * @param asset The address of the asset
   * @param source The price source of the asset
   */
  event AssetSourceUpdated(address indexed asset, address indexed source);

  bytes32 internal constant STORAGE_SLOT = keccak256("priceOracle.storage");

  address public constant BASE_CURRENCY = 0x0; // 0x0 => USD
  uint256 public constant BASE_CURRENCY_UNIT = 1;

  modifier initializer(LayoutTypes.PriceOracleLayout storage s) {
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
    returns (LayoutTypes.PriceOracleLayout storage s)
  {
    bytes32 slot = STORAGE_SLOT;
    assembly {
      s.slot := slot
    }
  }

  function initialize(
    LayoutTypes.PriceOracleLayout storage s,
    address[] memory assets,
    address[] memory sources
  ) internal initializer(s) {
    _setAssetsSources(assets, sources);
  }

  /**
   * @notice Internal function to set the sources for each asset
   * @param assets The addresses of the assets
   * @param sources The address of the source of each asset
   */
  function _setAssetsSources(address[] memory assets, address[] memory sources)
    internal
  {
    LayoutTypes.PriceOracleLayout storage s = layout();

    require(assets.length == sources.length, Errors.INCONSISTENT_PARAMS_LENGTH);
    for (uint256 i = 0; i < assets.length; i++) {
      s._assetsSources[assets[i]] = AggregatorInterface(sources[i]);
      emit AssetSourceUpdated(assets[i], sources[i]);
    }
  }

  function getAssetPrice(address asset) internal view returns (uint256) {
    LayoutTypes.PriceOracleLayout storage s = layout();

    AggregatorInterface source = s._assetsSources[asset];

    if (asset == BASE_CURRENCY) {
      return BASE_CURRENCY_UNIT;
    } else if (address(source) == address(0)) {
      revert("Source unavailable");
    } else {
      int256 price = source.latestAnswer();
      if (price > 0) {
        return uint256(price);
      } else {
        return 0;
      }
    }
  }
}

function getAssetsPrices(address[] calldata assets)
  internal
  view
  returns (uint256[] memory)
{
  uint256[] memory prices = new uint256[](assets.length);
  for (uint256 i = 0; i < assets.length; i++) {
    prices[i] = getAssetPrice(assets[i]);
  }
  return prices;
}

function getAssetSource(address asset) internal view returns (address) {
  LayoutTypes.PriceOracleLayout storage s = layout();

  return address(s._assetsSources[asset]);
}
