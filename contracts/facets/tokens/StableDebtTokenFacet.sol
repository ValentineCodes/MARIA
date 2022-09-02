// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import {OwnableInternal} from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import {LayoutTypes} from "../../libraries/types/LayoutTypes.sol";
import {Errors} from "../../libraries/utils/Errors.sol";
import {Query} from "../../libraries/utils/Query.sol";
import {LibStableDebtToken} from "../../libraries/facets/LibStableDebtToken.sol";

contract StableDebtTokenFacet is OwnableInternal {
    using LibStableDebtToken for LayoutTypes.StableDebtTokenLayout;

    /**
     * @dev Only pool can call functions marked by this modifier.
     **/
    modifier onlyPool() {
        require(
            Query._msgSender() == LibStableDebtToken.layout()._pool,
            Errors.CALLER_MUST_BE_POOL
        );
        _;
    }

    constructor() {
        LibStableDebtToken._constructor(block.chainId);
    }

    function initializeStableDebtToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address pool,
        address underlyingAsset,
        bytes calldata params
    ) external onlyOwner {
        LibStableDebtToken.layout().initializeStableDebtToken(
            name,
            symbol,
            decimals,
            pool,
            underlyingAsset,
            params
        );
    }

    function EIP712_REVISION() external view returns (bytes) {
        return LibStableDebtToken.EIP712_REVISION();
    }

    function DELEGATION_WITH_SIG_TYPEHASH() external view returns (bytes32) {
        return LibStableDebtToken.DELEGATION_WITH_SIG_TYPEHASH();
    }

    function DEBT_TOKEN_REVISION() external view returns (uint256) {
        return LibStableDebtToken.DEBT_TOKEN_REVISION();
    }

    /**
     * @notice Get the domain separator for the token
     * @dev Return cached value if chainId matches cache, otherwise recomputes separator
     * @return The domain separator of the token at current chain
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return LibStableDebtToken.layout().DOMAIN_SEPARATOR();
    }

    /// @inheritdoc IStableDebtToken
    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return LibStableDebtToken.layout().UNDERLYING_ASSET_ADDRESS();
    }

    /**
     * @notice Returns the nonce value for address specified as parameter
     * @param owner The address for which the nonce is being returned
     * @return The nonce value for the input address`
     */
    function nonces(address owner) external view returns (uint256) {
        return LibStableDebtToken.layout().nonces(owner);
    }

    /// @inheritdoc IERC20Detailed
    function name() external view returns (string memory) {
        return LibStableDebtToken.layout().name();
    }

    /// @inheritdoc IERC20Detailed
    function symbol() external view returns (string memory) {
        return LibStableDebtToken.layout().symbol();
    }

    /// @inheritdoc IERC20Detailed
    function decimals() external view returns (uint8) {
        return LibStableDebtToken.layout().decimals();
    }

    /// @inheritdoc IERC20
    function totalSupply() external view returns (uint256) {
        return LibStableDebtToken.layout().totalSupply();
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) external view returns (uint256) {
        return LibStableDebtToken.layout().balanceOf(account);
    }

    /// @inheritdoc IStableDebtToken
    function getAverageStableRate() external view returns (uint256) {
        return LibStableDebtToken.layout().getAverageStableRate();
    }

    /// @inheritdoc IStableDebtToken
    function getUserLastUpdated(address user) external view returns (uint40) {
        return LibStableDebtToken.layout().getUserLastUpdated(user);
    }

    /// @inheritdoc IStableDebtToken
    function getUserStableRate(address user) external view returns (uint256) {
        return LibStableDebtToken.layout().getUserStableRate(user);
    }

    /// @inheritdoc IStableDebtToken
    function getSupplyData()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint40
        )
    {
        return LibStableDebtToken.layout().getSupplyData();
    }

    /// @inheritdoc IStableDebtToken
    function getTotalSupplyAndAvgRate()
        external
        view
        returns (uint256, uint256)
    {
        return LibStableDebtToken.layout().getTotalSupplyAndAvgRate();
    }

    /// @inheritdoc IStableDebtToken
    function getTotalSupplyLastUpdated() external view returns (uint40) {
        return LibStableDebtToken.layout().getTotalSupplyLastUpdated();
    }

    /// @inheritdoc IStableDebtToken
    function principalBalanceOf(address user) external view returns (uint256) {
        return LibStableDebtToken.layout().principalBalanceOf(user);
    }

    function borrowAllowance(address fromUser, address toUser)
        external
        view
        returns (uint256)
    {
        return LibStableDebtToken.layout().borrowAllowance(fromUser, toUser);
    }

    /// @inheritdoc IStableDebtToken
    function mint(
        address user,
        address onBehalfOf,
        uint256 amount,
        uint256 rate
    )
        external
        onlyPool
        returns (
            bool,
            uint256,
            uint256
        )
    {
        return LibStableDebtToken.layout().mint(user, onBehalfOf, amount, rate);
    }

    /// @inheritdoc IStableDebtToken
    function burn(address from, uint256 amount)
        external
        onlyPool
        returns (uint256, uint256)
    {
        return LibStableDebtToken.layout().burn(from, amount);
    }

    function approveDelegation(address delegatee, uint256 amount) external {
        return LibStableDebtToken.layout().approveDelegation(delegatee, amount);
    }

    function delegationWithSig(
        address delegator,
        address delegatee,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        return
            LibStableDebtToken.layout().delegationWithSig(
                delegator,
                delegatee,
                value,
                deadline,
                v,
                r,
                s
            );
    }

    /**
     * @dev Being non transferrable, the debt token does not implement any of the
     * standard ERC20 functions for transfer and allowance.
     **/
    function transfer(address, uint256) external returns (bool) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }

    function allowance(address, address) external view returns (uint256) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }

    function approve(address, uint256) external returns (bool) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }

    function increaseAllowance(address, uint256) external returns (bool) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }

    function decreaseAllowance(address, uint256) external returns (bool) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }
}
