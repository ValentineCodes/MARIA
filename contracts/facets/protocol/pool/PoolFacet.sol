// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import {LibPool} from "../../../libraries/facets/LibPool.sol";
import {LayoutTypes} from "../../../libraries/types/LayoutTypes.sol";
import {OwnableInternal} from "../../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import {IERC20WithPermit} from '../../../interfaces/IERC20WithPermit.sol';
import {IPool} from "../../../interfaces/IPool.sol";

contract Pool is IPool, OwnableInternal {
    using LibPool for LayoutTypes.PoolLayout;

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
        LibPool.supply(
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
    ) external override returns (uint256) {}

    /// @inheritdoc IPool
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external override {}

    /// @inheritdoc IPool
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external override returns (uint256) {}

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
    ) external override returns (uint256) {}

    /// @inheritdoc IPool
    function repayWithATokens(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external override returns (uint256) {}

    /// @inheritdoc IPool
    function swapBorrowRateMode(address asset, uint256 interestRateMode)
        external
        override
    {}

    /// @inheritdoc IPool
    function rebalanceStableBorrowRate(address asset, address user)
        external
        override
    {}

    /// @inheritdoc IPool
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral)
        external
        override
    {}

    /// @inheritdoc IPool
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
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
