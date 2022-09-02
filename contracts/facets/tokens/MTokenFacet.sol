// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import {LibMToken} from "../../libraries/facets/LibMToken.sol";
import {OwnableInternal} from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import {LayoutTypes} from "../../libraries/types/LayoutTypes.sol";
import {Errors} from "../../libraries/utils/Errors.sol";
import {Query} from "../../libraries/utils/Query.sol";
import {IACLManager} from "../../interfaces/IACLManager.sol";

contract MToken is OwnableInternal {
    using LibMToken for LayoutTypes.MTokenLayout;

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
            Query._msgSender() == LibMToken.layout()._pool,
            Errors.CALLER_MUST_BE_POOL
        );
        _;
    }

    constructor() {
        LibMToken._constructor(block.chainId);
    }

    function initializeMToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address pool,
        address treasury,
        address underlyingAsset
    ) external onlyOwner {
        LibMToken.layout().initializeMToken(
            name,
            symbol,
            decimals,
            pool,
            treasury,
            underlyingAsset
        );
    }

    function EIP712_REVISION() external view returns (bytes) {
        return LibMToken.EIP712_REVISION();
    }

    function PERMIT_TYPEHASH() external view returns (bytes32) {
        return LibMToken.PERMIT_TYPEHASH();
    }

    function RESERVE_TREASURY_ADDRESS() external view returns (address) {
        return LibMToken.layout().RESERVE_TREASURY_ADDRESS();
    }

    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return LibMToken.layout().UNDERLYING_ASSET_ADDRESS();
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return LibMToken.layout().DOMAIN_SEPARATOR();
    }

    function nonces(address owner) external view returns (uint256) {
        return LibMToken.layout().nonces(owner);
    }

    function name() external view returns (string memory) {
        return LibMToken.layout().name();
    }

    function symbol() external view returns (string memory) {
        return LibMToken.layout().symbol();
    }

    function decimals() external view returns (uint8) {
        return LibMToken.layout().decimals();
    }

    function balanceOf(address user) external view returns (uint256) {
        return LibMToken.layout().balanceOf(user);
    }

    function totalSupply() external view returns (uint256) {
        return LibMToken.layout().totalSupply();
    }

    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return LibMToken.layout().allowance(owner, spender);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        return LibMToken.layout().increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        return LibMToken.layout().decreaseAllowance(spender, subtractedValue);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        return LibMToken.layout().approve(spender, amount);
    }

    function transfer(address recipient, uint256 amount)
        external
        returns (bool)
    {
        return LibMToken.layout().transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        return LibMToken.layout().transferFrom(sender, recipient, amount);
    }

    function transferOnLiquidation(
        address from,
        address to,
        uint256 value
    ) external onlyPool {
        LibMToken.layout().transferOnLiquidation(from, to, value);
    }

    function transferUnderlyingTo(address target, uint256 amount)
        external
        onlyPool
    {
        LibMToken.layout().transferUnderlyingTo(target, amount);
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external onlyPool returns (bool) {
        return LibMToken.layout().mint(caller, onBehalfOf, amount, index);
    }

    function burn(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external onlyPool {
        return LibMToken.layout().burn(caller, onBehalfOf, amount, index);
    }

    function mintToTreasury(uint256 amount, uint256 index) external onlyPool {
        if (amount == 0) {
            return;
        }
        LibMToken.layout().mintToTreasury(amount, index);
    }

    function scaledBalanceOf(address user) external view returns (uint256) {
        return LibMToken.layout().scaledBalanceOf(user);
    }

    function getScaledUserBalanceAndSupply(address user)
        external
        view
        returns (uint256, uint256)
    {
        return LibMToken.layout().getScaledUserBalanceAndSupply(user);
    }

    function scaledTotalSupply() external view returns (uint256) {
        return LibMToken.layout().scaledTotalSupply();
    }

    function getPreviousIndex(address user) external view returns (uint256) {
        return LibMToken.layout().getPreviousIndex(user);
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
        LibMToken.layout().permit(owner, spender, value, deadline, v, r, s);
    }

    function rescueTokens(
        address token,
        address to,
        uint256 amount
    ) external onlyPoolAdmin {
        LibMToken.layout().rescueTokens(token, to, amount);
    }
}
