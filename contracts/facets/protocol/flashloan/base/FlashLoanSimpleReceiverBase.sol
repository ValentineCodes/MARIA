// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import { IFlashLoanSimpleReceiver } from "../interfaces/IFlashLoanSimpleReceiver.sol";
import { IAddressProvider } from "../../interfaces/IAddressProvider.sol";
import { IPool } from "../../interfaces/IPool.sol";

/**
 * @title FlashLoanSimpleReceiverBase
 * @author Aave
 * @notice Base contract to develop a flashloan-receiver contract.
 */
abstract contract FlashLoanSimpleReceiverBase is IFlashLoanSimpleReceiver {
  IAddressProvider public immutable override ADDRESSES_PROVIDER;
  IPool public immutable override POOL;

  constructor(IAddressProvider provider) {
    ADDRESSES_PROVIDER = provider;
    POOL = IPool(provider.getPool());
  }
}
