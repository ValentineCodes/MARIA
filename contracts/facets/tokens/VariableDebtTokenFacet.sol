// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import {OwnableInternal} from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import {LayoutTypes} from "../../libraries/types/LayoutTypes.sol";
import {Errors} from "../../libraries/utils/Errors.sol";
import {Query} from "../../libraries/utils/Query.sol";
import {LibVariableDebtToken} from "../../libraries/facets/LibVariableDebtToken.sol";

contract VariableDebtTokenFacet is OwnableInternal {
    /**
     * @dev Only pool can call functions marked by this modifier.
     **/
    modifier onlyPool() {
        require(
            Query._msgSender() == LibVariableDebtToken.layout()._pool,
            Errors.CALLER_MUST_BE_POOL
        );
        _;
    }

    constructor() {
        LibVariableDebtToken._constructor(block.chainId);
    }

    function initializeVariableDebtToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address pool,
        address underlyingAsset,
        bytes calldata params
    ) external onlyOwner {
        LibVariableDebtToken.layout().initializeVariableDebtToken(
            name,
            symbol,
            decimals,
            pool,
            underlyingAsset,
            params
        );
    }

    function EIP712_REVISION() external view returns (bytes) {
        return LibVariableDebtToken.EIP712_REVISION();
    }

    function DELEGATION_WITH_SIG_TYPEHASH() external view returns (bytes32) {
        return LibVariableDebtToken.DELEGATION_WITH_SIG_TYPEHASH();
    }

    function DEBT_TOKEN_REVISION() external view returns (uint256) {
        return LibVariableDebtToken.DEBT_TOKEN_REVISION();
    }

    /**
     * @notice Get the domain separator for the token
     * @dev Return cached value if chainId matches cache, otherwise recomputes separator
     * @return The domain separator of the token at current chain
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return LibVariableDebtToken.layout().DOMAIN_SEPARATOR();
    }

    /// @inheritdoc IVariableDebtToken
    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return LibVariableDebtToken.layout().UNDERLYING_ASSET_ADDRESS();
    }

    /**
     * @notice Returns the nonce value for address specified as parameter
     * @param owner The address for which the nonce is being returned
     * @return The nonce value for the input address`
     */
    function nonces(address owner) external view returns (uint256) {
        return LibVariableDebtToken.layout().nonces(owner);
    }

    /// @inheritdoc IERC20Detailed
    function name() external view returns (string memory) {
        return LibVariableDebtToken.layout().name();
    }

    /// @inheritdoc IERC20Detailed
    function symbol() external view returns (string memory) {
        return LibVariableDebtToken.layout().symbol();
    }

    /// @inheritdoc IERC20Detailed
    function decimals() external view returns (uint8) {
        return LibVariableDebtToken.layout().decimals();
    }

    /// @inheritdoc IERC20
    function totalSupply() external view returns (uint256) {
        return LibVariableDebtToken.layout().totalSupply();
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) external view returns (uint256) {
        return LibVariableDebtToken.layout().balanceOf(account);
    }

    function scaledBalanceOf(address user) external view returns (uint256) {
        return LibVariableDebtToken.layout()._userState[user].balance;
    }

    function getScaledUserBalanceAndSupply(address user)
        external
        view
        returns (uint256, uint256)
    {
        LayoutTypes.VariableDebtTokenLayout storage s = LibVariableDebtToken
            .layout();

        return (s._userState[user].balance, s._totalSupply);
    }

    function scaledTotalSupply() external view returns (uint256) {
        return LibVariableDebtToken.layout()._totalSupply;
    }

    function getPreviousIndex(address user) external view returns (uint256) {
        return LibVariableDebtToken.layout()._userState[user].additionalData;
    }

    function approveDelegation(address delegatee, uint256 amount) external {
        return
            LibVariableDebtToken.layout().approveDelegation(delegatee, amount);
    }

    function borrowAllowance(address fromUser, address toUser)
        external
        view
        returns (uint256)
    {
        return
            LibVariableDebtToken.layout()._borrowAllowances[fromUser][toUser];
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
            LibVariableDebtToken.layout().delegationWithSig(
                delegator,
                delegatee,
                value,
                deadline,
                v,
                r,
                s
            );
    }

    /// @inheritdoc IVariableDebtToken
    function mint(
        address user,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external onlyPool returns (bool, uint256) {
        return
            LibVariableDebtToken.layout().mint(user, onBehalfOf, amount, index);
    }

    /// @inheritdoc IVariableDebtToken
    function burn(
        address from,
        uint256 amount,
        uint256 index
    ) external onlyPool returns (uint256, uint256) {
        return LibVariableDebtToken.layout().burn(from, amount, index);
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
