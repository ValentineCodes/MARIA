// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import {LibDelegationMToken} from "../../libraries/facets/LibDelegationMToken.sol";
import {OwnableInternal} from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import {LayoutTypes} from "../../libraries/types/LayoutTypes.sol";
import {Errors} from "../../libraries/utils/Errors.sol";
import {Query} from "../../libraries/utils/Query.sol";
import {IACLManager} from "../../interfaces/IACLManager.sol";

contract DelegationMToken is OwnableInternal {
    using LibDelegationMToken for LayoutTypes.DelegationMTokenLayout;

    address internal immutable _aclManager;

    /**
     * @dev Only pool admin can call functions marked by this modifier.
     **/
    modifier onlyPoolAdmin() {
        require(
            IACLManager(_aclManager).isPoolAdmin(msg.sender),
            Errors.CALLER_NOT_POOL_ADMIN
        );
        _;
    }

    /**
     * @dev Only pool can call functions marked by this modifier.
     **/
    modifier onlyPool() {
        require(
            Query._msgSender() == LibDelegationMToken.layout()._pool,
            Errors.CALLER_MUST_BE_POOL
        );
        _;
    }

    constructor() {
        LibDelegationMToken._constructor(block.chainId);
    }

    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address pool,
        address treasury,
        address underlyingAsset
    ) external onlyOwner {
        LibDelegationMToken.layout().initialize(
            name,
            symbol,
            decimals,
            pool,
            treasury,
            underlyingAsset
        );
    }

    function EIP712_REVISION() external view returns (bytes) {
        return LibDelegationMToken.EIP712_REVISION();
    }

    function PERMIT_TYPEHASH() external view returns (bytes32) {
        return LibDelegationMToken.PERMIT_TYPEHASH();
    }

    function RESERVE_TREASURY_ADDRESS() external view returns (address) {
        return LibDelegationMToken.layout().RESERVE_TREASURY_ADDRESS();
    }

    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return LibDelegationMToken.layout().UNDERLYING_ASSET_ADDRESS();
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return LibDelegationMToken.layout().DOMAIN_SEPARATOR();
    }

    function nonces(address owner) external view returns (uint256) {
        return LibDelegationMToken.layout().nonces(owner);
    }

    function name() external view returns (string memory) {
        return LibDelegationMToken.layout().name();
    }

    function symbol() external view returns (string memory) {
        return LibDelegationMToken.layout().symbol();
    }

    function decimals() external view returns (uint8) {
        return LibDelegationMToken.layout().decimals();
    }

    function balanceOf(address user) external view returns (uint256) {
        return LibDelegationMToken.layout().balanceOf(user);
    }

    function totalSupply() external view returns (uint256) {
        return LibDelegationMToken.layout().totalSupply();
    }

    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return LibDelegationMToken.layout().allowance(owner, spender);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        return LibDelegationMToken.layout().increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        return LibDelegationMToken.layout().decreaseAllowance(spender, subtractedValue);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        return LibDelegationMToken.layout().approve(spender, amount);
    }

    function transfer(address recipient, uint256 amount)
        external
        returns (bool)
    {
        return LibDelegationMToken.layout().transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        return LibDelegationMToken.layout().transferFrom(sender, recipient, amount);
    }

    function transferOnLiquidation(
        address from,
        address to,
        uint256 value
    ) external onlyPool {
        LibDelegationMToken.layout().transferOnLiquidation(from, to, value);
    }

    function transferUnderlyingTo(address target, uint256 amount)
        external
        onlyPool
    {
        LibDelegationMToken.layout().transferUnderlyingTo(target, amount);
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external onlyPool returns (bool) {
        return LibDelegationMToken.layout().mint(caller, onBehalfOf, amount, index);
    }

    function burn(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external onlyPool {
        return LibDelegationMToken.layout().burn(caller, onBehalfOf, amount, index);
    }

    function mintToTreasury(uint256 amount, uint256 index) external onlyPool {
        if (amount == 0) {
            return;
        }
        LibDelegationMToken.layout().mintToTreasury(amount, index);
    }

    function scaledBalanceOf(address user) external view returns (uint256) {
        return LibDelegationMToken.layout().scaledBalanceOf(user);
    }

    function getScaledUserBalanceAndSupply(address user)
        external
        view
        returns (uint256, uint256)
    {
        return LibDelegationMToken.layout().getScaledUserBalanceAndSupply(user);
    }

    function scaledTotalSupply() external view returns (uint256) {
        return LibDelegationMToken.layout().scaledTotalSupply();
    }

    function getPreviousIndex(address user) external view returns (uint256) {
        return LibDelegationMToken.layout().getPreviousIndex(user);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        LibDelegationMToken.layout().permit(owner, spender, value, deadline, v, r, s);
    }

    function rescueTokens(
        address token,
        address to,
        uint256 amount
    ) external onlyPoolAdmin {
        LibDelegationMToken.layout().rescueTokens(token, to, amount);
    }
}
