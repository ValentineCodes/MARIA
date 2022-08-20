// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./DataTypes.sol";
import "./UserConfiguration.sol";
import "./ReserveConfiguration.sol";
import "./ReserveLogic.sol";

/**
 * @notice Storage/Database of the Maria contract
 */
contract MariaDB {
    using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    // Map of address of underlying asset to reserve data
    mapping(address => DataTypes.ReserveData) internal s_reserves;

    // Map of users address to their configuration data
    mapping(address => DataTypes.UserConfigurationMap) internal s_usersConfig;

    // Map of reserve id to reserve
    mapping(uint256 => address) internal s_reservesList;

    // Map of EMode category id to eMode category
    mapping(uint8 => DataTypes.EModeCategory) internal s_eModeCategories;

    // Map of users address to their eMode category
    mapping(address => uint8) internal s_usersEModeCategory;

    // Fee of the protocol bridge, expressed in bps
    uint256 internal s_bridgeProtocolFee;

    // Total FlashLoan Premium, expressed in bps
    uint128 internal s_flashLoanPremiumTotal;

    // FlashLoan premium paid to protocol treasury, expressed in bps
    uint128 internal s_flashLoanPremiumToProtocol;

    // Available liquidity that can be borrowed at once at stable rate, expressed in bps
    uint64 internal s_maxStableRateBorrowSizePercent;

    // Maximum number of active reserves there have been in the protocol
    uint16 internal s_reservesCount;
}
