// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import {LibPool} from "../../../libraries/facets/LibPool.sol";
import {DataTypes} from "../../../libraries/types/DataTypes.sol";
import {LayoutTypes} from "../../../libraries/types/LayoutTypes.sol";
import {OwnableInternal} from "../../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import {IERC20WithPermit} from '../../../interfaces/IERC20WithPermit.sol';
import {IAddressProvider} from '../../../interfaces/IAddressProvider.sol';
import {IPool} from "../../../interfaces/IPool.sol";

contract Pool is IPool, OwnableInternal {
    using LibPool for LayoutTypes.PoolLayout;

    IAddressProvider public immutable ADDRESS_PROVIDER;

    constructor(address addressProvider) {
        ADDRESS_PROVIDER = IAddressProvider(addressProvider);
    }

    function initializePool(LayoutTypes.PoolLayout storage s)
        external
        onlyOwner
    {
        LibPool.initializePool();
    }

    /// @inheritdoc IPool
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external override {
        LayoutTypes.PoolLayout storage s = LibPool.layout();

        LibPool.supply(
            s._reserves,
            s._reservesList,
            s._usersConfig[onBehalfOf],
            address asset,
            uint256 amount,
            address onBehalfOf,
            uint16 referralCode
        );
    }

    /// @inheritdoc IPool
    function supplyWithPermit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override {
        LayoutTypes.PoolLayout storage s = LibPool.layout();

        IERC20WithPermit(asset).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            permitV,
            permitR,
            permitS
        );

        LibPool.supply(
            s._reserves,
            s._reservesList,
            s._usersConfig[onBehalfOf],
            address asset,
            uint256 amount,
            address onBehalfOf,
            uint16 referralCode
        );
    }

    /// @inheritdoc IPool
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external override returns (uint256) {
        LayoutTypes.PoolLayout storage s = LibPool.layout();

       return LibPool.withdraw(  
        s._reserves,
        s._reservesList,
        s._eModeCategories,
        s._usersConfig[msg.sender],
        s._reservesCount,
        s._usersEModeCategory[msg.sender],
        asset, 
        amount, 
        to,
        ADDRESS_PROVIDER.getPriceOracle());
    }

    /// @inheritdoc IPool
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external override {
        LayoutTypes.PoolLayout storage s = LibPool.layout();

        LibPool.borrow(
            s._reserves,
            s._reservesList,
            s._eModeCategories,
            s._usersConfig[onBehalfOf],
            s._maxStableRateBorrowSizePercent,
            s._reservesCount,
            s._usersEModeCategory[onBehalfOf],
            asset,
            amount,
            DataTypes.InterestRateMode(interestRateMode),
            referralCode,
            onBehalfOf, 
            true,
            ADDRESS_PROVIDER.getPriceOracle(),
            ADDRESS_PROVIDER.getPriceOracleSentinel();
        )
    }

    /// @inheritdoc IPool
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external override returns (uint256) {
        LayoutTypes.PoolLayout storage s = LibPool.layout();

       return LibPool.repay(        
            s._reserves,
            s._reservesList,
            s._usersConfig[onBehalfOf],
            asset, 
            amount, 
            DataTypes.InterestRateMode(interestRateMode), 
            onBehalfOf, 
            false
        );
    }

    /// @inheritdoc IPool
    function repayWithPermit(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override returns (uint256) {
        LayoutTypes.PoolLayout storage s = LibPool.layout();

        IERC20WithPermit(asset).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            permitV,
            permitR,
            permitS
        );
        
        return LibPool.repay(        
            s._reserves,
            s._reservesList,
            s._usersConfig[onBehalfOf],
            asset, 
            amount, 
            DataTypes.InterestRateMode(interestRateMode), 
            onBehalfOf, 
            false
        );
    }

    /// @inheritdoc IPool
    function repayWithMTokens(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external override returns (uint256) {
        LayoutTypes.PoolLayout storage s = LibPool.layout();

        returnLibPool.repay(        
            s._reserves,
            s._reservesList,
            s._usersConfig[onBehalfOf],
            asset, 
            amount, 
            DataTypes.InterestRateMode(interestRateMode), 
            onBehalfOf, 
            true
        );
    }

    /// @inheritdoc IPool
    function swapBorrowRateMode(address asset, uint256 interestRateMode)
        external
        override
    {
        LayoutTypes.PoolLayout storage s = LibPool.layout();

        LibPool.swapBorrowRateMode( 
            s._reserves[asset],
            s._usersConfig[msg.sender],
            asset, 
            DataTypes.InterestRateMode(interestRateMode)
        );
    }

    /// @inheritdoc IPool
    function rebalanceStableBorrowRate(address asset, address user)
        external
        override
    {
        LayoutTypes.PoolLayout storage s = LibPool.layout();

        LibPool.rebalanceStableBorrowRate(s._reserves[asset], asset, user);
    }

    /// @inheritdoc IPool
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral)
        external
        override
    {
        LayoutTypes.PoolLayout storage s = LibPool.layout();

        LibPool.setUserUseReserveAsCollateral(      
            s._reserves,
            s._reservesList,
            s._eModeCategories,
            s._usersConfig[msg.sender],
            asset,
            useAsCollateral,
            s._reservesCount,
            ADDRESSES_PROVIDER.getPriceOracle(),
            s._usersEModeCategory[msg.sender]
        );
    }

    /// @inheritdoc IPool
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveMToken
    ) external override {}

    /// @inheritdoc IPool
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external override {}

    /// @inheritdoc IPool
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external override {}

    /// @inheritdoc IPool
    function mintToTreasury(address[] calldata assets) external override {}

    /// @inheritdoc IPool
    function getReserveData(address asset)
        external
        view
        override
        returns (DataTypes.ReserveData memory)
    {}

    /// @inheritdoc IPool
    function getUserAccountData(address user)
        external
        view
        override
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {}

    /// @inheritdoc IPool
    function getConfiguration(address asset)
        external
        view
        override
        returns (DataTypes.ReserveConfigurationMap memory)
    {}

    /// @inheritdoc IPool
    function getUserConfiguration(address user)
        external
        view
        override
        returns (DataTypes.UserConfigurationMap memory)
    {}

    /// @inheritdoc IPool
    function getReserveNormalizedIncome(address asset)
        external
        view
        override
        returns (uint256)
    {
        return LibPool.layout().getReserveNormalizedIncome(asset);
    }

    /// @inheritdoc IPool
    function getReserveNormalizedVariableDebt(address asset)
        external
        view
        override
        returns (uint256)
    {
        return LibPool.layout().getNormalizedDebt(asset);
    }

    /// @inheritdoc IPool
    function getReservesList()
        external
        view
        override
        returns (address[] memory)
    {}

    /// @inheritdoc IPool
    function getReserveAddressById(uint16 id) external view returns (address) {}

    /// @inheritdoc IPool
    function MAX_STABLE_RATE_BORROW_SIZE_PERCENT()
        external
        view
        override
        returns (uint256)
    {}

    /// @inheritdoc IPool
    function BRIDGE_PROTOCOL_FEE() external view override returns (uint256) {}

    /// @inheritdoc IPool
    function FLASHLOAN_PREMIUM_TOTAL()
        external
        view
        override
        returns (uint128)
    {}

    /// @inheritdoc IPool
    function FLASHLOAN_PREMIUM_TO_PROTOCOL()
        external
        view
        override
        returns (uint128)
    {}

    /// @inheritdoc IPool
    function MAX_NUMBER_RESERVES() external view override returns (uint16) {}

    /// @inheritdoc IPool
    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromBefore,
        uint256 balanceToBefore
    ) external override {}
}
