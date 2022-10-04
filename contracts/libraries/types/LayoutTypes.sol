// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DataTypes} from "./DataTypes.sol";
import { AggregatorInterface } from "../../dependencies/chainlink/AggregatorInterface.sol";

library LayoutTypes {
    struct PoolLayout {
        address configurator;
        // Map of reserves and their data (underlyingAssetOfReserve => reserveData)
        mapping(address => DataTypes.ReserveData) _reserves;
        // Map of users address and their configuration data (userAddress => userConfiguration)
        mapping(address => DataTypes.UserConfigurationMap) _usersConfig;
        // List of reserves as a map (reserveId => reserve).
        // It is structured as a mapping for gas savings reasons, using the reserve id as index
        mapping(uint256 => address) _reservesList;
        // List of eMode categories as a map (eModeCategoryId => eModeCategory).
        // It is structured as a mapping for gas savings reasons, using the eModeCategoryId as index
        mapping(uint8 => DataTypes.EModeCategory) _eModeCategories;
        // Map of users address and their eMode category (userAddress => eModeCategoryId)
        mapping(address => uint8) _usersEModeCategory;
        // Fee of the protocol bridge, expressed in bps
        uint256 _bridgeProtocolFee;
        // Total FlashLoan Premium, expressed in bps
        uint128 _flashLoanPremiumTotal;
        // FlashLoan premium paid to protocol treasury, expressed in bps
        uint128 _flashLoanPremiumToProtocol;
        // Available liquidity that can be borrowed at once at stable rate, expressed in bps
        uint64 _maxStableRateBorrowSizePercent;
        // Maximum number of active reserves there have been in the protocol. It is the upper bound of the reserves list
        uint16 _reservesCount;
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint256 lastInitializedRevision;

        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool initializing;
    }

    struct ACLManagerLayout {
        address admin;
        mapping(bytes32 => DataTypes.RoleData) _roles;
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint256 lastInitializedRevision;

        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool initializing;
    }

    struct AddressProviderLayout {
        // Identifier of the Aave Market
        string _marketId;

        // Map of registered addresses (identifier => registeredAddress)
        mapping(bytes32 => address) _addresses;

        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint256 lastInitializedRevision;

        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool initializing;
    }

    struct InterestRateStrategyLayout {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint256 lastInitializedRevision;

        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool initializing;
    }

    struct PriceOracleLayout {
        // Map of asset price sources (asset => priceSource)
        mapping(address => AggregatorInterface) _assetsSources;

        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint256 lastInitializedRevision;

        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool initializing;
    }

    struct PriceOracleSentinelLayout {
        bool _isDown;
        uint256 _timestampGotUp;
        uint256 _gracePeriod;
                /**
         * @dev Indicates that the contract has been initialized.
         */
        uint256 lastInitializedRevision;

        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool initializing;
    }

    struct MTokenLayout {
        address _pool;
        address _treasury;
        address _underlyingAsset;
        // Map of users address and their state data (userAddress => userStateData)
        mapping(address => DataTypes.UserState) _userState;

        // Map of allowances (delegator => delegatee => allowanceAmount)
        mapping(address => mapping(address => uint256)) _allowances;

        // Map of address nonces (address => nonce)
        mapping(address => uint256) _nonces;

        bytes32 _domainSeparator;

        uint256 _totalSupply;
        string _name;
        string _symbol;
        uint8 _decimals;
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint256 lastInitializedRevision;

        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool initializing;

    }

    struct StableDebtTokenLayout {
        address _pool;
        address _underlyingAsset;

        // Map of users address and the timestamp of their last update (userAddress => lastUpdateTimestamp)
        mapping(address => uint40) _timestamps;

        // Map of borrow allowances (delegator => delegatee => borrowAllowanceAmount)
        mapping(address => mapping(address => uint256)) _borrowAllowances;

        // Map of address nonces (address => nonce)
        mapping(address => uint256) _nonces;

        // Map of users address and their state data (userAddress => userStateData)
        mapping(address => DataTypes.UserState) internal _userState;

        // Map of allowances (delegator => delegatee => allowanceAmount)
        mapping(address => mapping(address => uint256)) private _allowances;

        uint256 internal _totalSupply;
        string private _name;
        string private _symbol;
        uint8 private _decimals;

        bytes32 _domainSeparator;

        uint128 _avgStableRate;

        // Timestamp of the last update of the total supply
        uint40 _totalSupplyTimestamp;
        
          /**
         * @dev Indicates that the contract has been initialized.
         */
        uint256 lastInitializedRevision;

        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool initializing;
    }

    struct VariableDebtTokenLayout {
        address _pool;
        address _underlyingAsset;

        // Map of borrow allowances (delegator => delegatee => borrowAllowanceAmount)
        mapping(address => mapping(address => uint256)) _borrowAllowances;

        // Map of address nonces (address => nonce)
        mapping(address => uint256) _nonces;

        // Map of users address and their state data (userAddress => userStateData)
        mapping(address => DataTypes.UserState) internal _userState;

        // Map of allowances (delegator => delegatee => allowanceAmount)
        mapping(address => mapping(address => uint256)) private _allowances;

        bytes32 _domainSeparator;
        uint256 internal _totalSupply;
        string private _name;
        string private _symbol;
        uint8 private _decimals;
    }

    struct DelegationMTokenLayout {
        address _pool;
        address _treasury;
        address _underlyingAsset;
        // Map of users address and their state data (userAddress => userStateData)
        mapping(address => DataTypes.UserState) _userState;

        // Map of allowances (delegator => delegatee => allowanceAmount)
        mapping(address => mapping(address => uint256)) _allowances;

        // Map of address nonces (address => nonce)
        mapping(address => uint256) _nonces;

        bytes32 _domainSeparator;

        uint256 _totalSupply;
        string _name;
        string _symbol;
        uint8 _decimals;
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint256 lastInitializedRevision;

        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool initializing;

    }
}
