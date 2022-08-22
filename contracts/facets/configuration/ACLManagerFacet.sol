// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import {IACLManager} from "../../interfaces/IACLManager.sol";
import {LibACLManager} from "../../libraries/configuration/LibACLManager";
import {OwnableInternal} from "../../dependencies/solidstate/contracts/access/ownable/OwnableInternal.sol";

/**
 * @title ACLManager
 * @author Maria
 * @notice Access Control List Manager. Main registry of system roles and permissions.
 */
contract ACLManager is IACLManager, OwnableInternal {
    using LibACLManager for LibACLManager.ACLManagerLayout;

    bytes32 public constant override POOL_ADMIN_ROLE = keccak256("POOL_ADMIN");
    bytes32 public constant override EMERGENCY_ADMIN_ROLE =
        keccak256("EMERGENCY_ADMIN");
    bytes32 public constant override RISK_ADMIN_ROLE = keccak256("RISK_ADMIN");
    bytes32 public constant override FLASH_BORROWER_ROLE =
        keccak256("FLASH_BORROWER");
    bytes32 public constant override BRIDGE_ROLE = keccak256("BRIDGE");
    bytes32 public constant override ASSET_LISTING_ADMIN_ROLE =
        keccak256("ASSET_LISTING_ADMIN");

    function getACLAdmin() external view override returns (address) {
        return LibACLManager.layout().getACLAdmin();
    }

    function setACLAdmin(address newAclAdmin) external override {
        LibACLManager.layout().setACLAdmin(newAclAdmin);
    }

    function hasRole(bytes32 role, address account)
        external
        view
        override
        returns (bool)
    {
        return LibACLManager.layout().hasRole(role, account);
    }

    function grantRole(bytes32 role, address account) external override {
        LibACLManager.layout().grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external override {
        LibACLManager.layout().revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) external override {
        LibACLManager.layout().renounceRole(role, account);
    }

    function getRoleAdmin(bytes32 role)
        external
        view
        override
        returns (bytes32)
    {
        return LibACLManager.layout().getRoleAdmin(role);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external override {
        LibACLManager.layout().setRoleAdmin(role, adminRole);
    }

    function addPoolAdmin(address admin) external override {
        LibACLManager.layout().grantRole(POOL_ADMIN_ROLE, admin);
    }

    function removePoolAdmin(address admin) external override {
        LibACLManager.layout().revokeRole(POOL_ADMIN_ROLE, admin);
    }

    function isPoolAdmin(address admin) external view override returns (bool) {
        return LibACLManager.layout().hasRole(POOL_ADMIN_ROLE, admin);
    }

    function addEmergencyAdmin(address admin) external override {
        LibACLManager.layout().grantRole(EMERGENCY_ADMIN_ROLE, admin);
    }

    function removeEmergencyAdmin(address admin) external override {
        LibACLManager.layout().revokeRole(EMERGENCY_ADMIN_ROLE, admin);
    }

    function isEmergencyAdmin(address admin)
        external
        view
        override
        returns (bool)
    {
        return LibACLManager.layout().hasRole(EMERGENCY_ADMIN_ROLE, admin);
    }

    function addRiskAdmin(address admin) external override {
        LibACLManager.layout().grantRole(RISK_ADMIN_ROLE, admin);
    }

    function removeRiskAdmin(address admin) external override {
        LibACLManager.layout().revokeRole(RISK_ADMIN_ROLE, admin);
    }

    function isRiskAdmin(address admin) external view override returns (bool) {
        return LibACLManager.layout().hasRole(RISK_ADMIN_ROLE, admin);
    }

    function addFlashBorrower(address borrower) external override {
        LibACLManager.layout().grantRole(FLASH_BORROWER_ROLE, borrower);
    }

    function removeFlashBorrower(address borrower) external override {
        LibACLManager.layout().revokeRole(FLASH_BORROWER_ROLE, borrower);
    }

    function isFlashBorrower(address borrower)
        external
        view
        override
        returns (bool)
    {
        return LibACLManager.layout().hasRole(FLASH_BORROWER_ROLE, borrower);
    }

    function addBridge(address bridge) external override {
        LibACLManager.layout().grantRole(BRIDGE_ROLE, bridge);
    }

    function removeBridge(address bridge) external override {
        LibACLManager.layout().revokeRole(BRIDGE_ROLE, bridge);
    }

    function isBridge(address bridge) external view override returns (bool) {
        return LibACLManager.layout().hasRole(BRIDGE_ROLE, bridge);
    }

    function addAssetListingAdmin(address admin) external override {
        LibACLManager.layout().grantRole(ASSET_LISTING_ADMIN_ROLE, admin);
    }

    function removeAssetListingAdmin(address admin) external override {
        LibACLManager.layout().revokeRole(ASSET_LISTING_ADMIN_ROLE, admin);
    }

    function isAssetListingAdmin(address admin)
        external
        view
        override
        returns (bool)
    {
        return LibACLManager.layout().hasRole(ASSET_LISTING_ADMIN_ROLE, admin);
    }
}
