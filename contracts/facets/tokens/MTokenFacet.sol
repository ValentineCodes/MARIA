// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import {LibMToken} from "../../libraries/facets/LibMToken.sol";
import {OwnableInternal} from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";
import {LayoutTypes} from "../../libraries/types/LayoutTypes.sol";

contract MToken is OwnableInternal {
    using LibMToken for LayoutTypes.MTokenLayout;

    constructor() {
        LibMToken._constructor(block.chainId);
    }

    function initializeMToken(address treasury, address underlyingAsset)
        external
        onlyOwner
    {
        return LibMToken.layout().initializeMToken(treasury, underlyingAsset);
    }

    // Done
    function RESERVE_TREASURY_ADDRESS() external view returns (address) {
        return LibMToken.layout().RESERVE_TREASURY_ADDRESS();
    }

    // Done
    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return LibMToken.layout().UNDERLYING_ASSET_ADDRESS();
    }

    // Done
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return LibMToken.layout().DOMAIN_SEPARATOR();
    }

    // Done
    function nonces(address owner) external view returns (uint256) {
        return LibMToken.layout().nonces(owner);
    }

    // Done
    function name() external view returns (string memory) {
        return LibMToken.layout().name();
    }

    // Done
    function symbol() external view returns (string memory) {
        return LibMToken.layout().symbol();
    }

    // Done
    function decimals() external view returns (uint8) {
        return LibMToken.layout().decimals();
    }

    // Done
    function balanceOf(address user) external view returns (uint256) {
        return LibMToken.layout().balanceOf(user);
    }

    // Done
    function totalSupply() external view returns (uint256) {
        return LibMToken.layout().totalSupply();
    }

    function transfer(address recipient, uint256 amount)
        external
        returns (bool)
    {}

    // Done
    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return LibMToken.layout().allowance(owner, spender);
    }

    // Done
    function approve(address spender, uint256 amount) external returns (bool) {
        return LibMToken.layout().approve(spender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {}

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external {}

    function burn(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external {}

    function mintToTreasury(uint256 amount, uint256 index) external {}

    function getIncentivesController() external view {}

    function setIncentivesController() external {}

    // Done
    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        return LibMToken.layout().increaseAllowance(spender, addedValue);
    }

    // Done
    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        return LibMToken.layout().decreaseAllowance(spender, subtractedValue);
    }

    function transferOnLiquidation(
        address from,
        address to,
        uint256 value
    ) external {}

    // Done
    function scaledBalanceOf(address user) external view returns (uint256) {
        return LibMToken.layout().scaledBalanceOf(user);
    }

    // Done
    function getScaledUserBalanceAndSupply(address user)
        external
        view
        returns (uint256, uint256)
    {
        return LibMToken.layout().getScaledUserBalanceAndSupply(user);
    }

    // Done
    function scaledTotalSupply() external view returns (uint256) {
        return LibMToken.layout().scaledTotalSupply();
    }

    // Done
    function getPreviousIndex(address user) external view returns (uint256) {
        return LibMToken.layout().getPreviousIndex(user);
    }

    // Done
    function transferUnderlyingTo(address target, uint256 amount) external {
        LibMToken.layout().transferUnderlyingTo(target, amount);
    }

    function handleRepayment(address user, uint256 amount) external {}

    // Done
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

    // Done
    function rescueTokens(
        address token,
        address to,
        uint256 amount
    ) external {
        LibMToken.layout().rescueTokens(token, to, amount);
    }
}
