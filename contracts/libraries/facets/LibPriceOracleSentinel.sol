// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { LayoutTypes } from "../types/LayoutTypes.sol";
import { Query } from "../utils/Query.sol";
import { Errors } from "../utils/Errors.sol";

library LibPriceOracle {
   /**
   * @dev Emitted after the grace period is updated
   * @param newGracePeriod The new grace period value
   */
  event GracePeriodUpdated(uint256 newGracePeriod);

  bytes32 internal constant STORAGE_SLOT =
    keccak256("priceOracleSentinel.storage");

  modifier initializer(LayoutTypes.PriceOracleSentinelLayout storage s) {
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
    returns (LayoutTypes.PriceOracleSentinelLayout storage s)
  {
    bytes32 slot = STORAGE_SLOT;
    assembly {
      s.slot := slot
    }
  }

  function initialize(
    LayoutTypes.PriceOracleSentinelLayout storage s,
    uint256 gracePeriod
  ) internal initializer(s) {
    s._gracePeriod = gracePeriod;
  }

    /**
   * @notice Checks the sequencer oracle is healthy: is up and grace period passed.
   * @return True if the SequencerOracle is up and the grace period passed, false otherwise
   */
  function _isUpAndGracePeriodPassed() internal view returns (bool) {
    LayoutTypes.PriceOracleSentinelLayout storage s = layout();

    return  !s._isDown && block.timestamp - s._timestampGotUp > s._gracePeriod;
  }

  function setGracePeriod(uint256 newGracePeriod) internal {
    LayoutTypes.PriceOracleSentinelLayout storage s = layout();
    s._gracePeriod = newGracePeriod;
    emit GracePeriodUpdated(newGracePeriod);
  }

  function setAnswer(bool isDown, uint256 timestamp) internal {
    LayoutTypes.PriceOracleSentinelLayout storage s = layout();

    s._isDown = isDown;
    s._timestampGotUp = timestamp;
  }
  