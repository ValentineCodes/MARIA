// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {LayoutTypes} from "../types/LayoutTypes.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {Query} from "../utils/Query.sol";
import {MathUtils} from "../math/MathUtils.sol";
import {WadRayMath} from "../math/WadRayMath.sol";

library LibPool {
    using WadRayMath for uint256;

    bytes32 internal constant STORAGE_SLOT = keccak256("pool.storage");

    modifier initializer(LayoutTypes.PoolLayout storage s) {
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
        returns (LayoutTypes.ACLManagerLayout storage s)
    {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    /**
     * @notice Initializes the Pool.
     **/
    function initializePool(LayoutTypes.PoolLayout storage s)
        internal
        initializer(s)
    {
        s._maxStableRateBorrowSizePercent = 0.25e4;
        s._flashLoanPremiumTotal = 0.0009e4;
        s._flashLoanPremiumToProtocol = 0;
    }

    function supply(
        LayoutTypes.PoolLayout storage s,
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) internal {}

    function getReserveNormalizedIncome(
        LayoutTypes.PoolLayout storage s,
        address asset
    ) internal view returns (uint256) {
        DataTypes.ReserveData memory reserve = s._reserves[asset];

        if (reserve.lastUpdateTimestamp == block.timestamp) {
            return reserve.liquidityIndex;
        } else {
            return
                MathUtils
                    .calculateLinearInterest(
                        reserve.currentLiquidityRate,
                        reserve.lastUpdateTimestamp
                    )
                    .rayMul(reserve.liquidityIndex);
        }
    }
}
