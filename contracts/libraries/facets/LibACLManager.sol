// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Strings} from "../../dependencies/openzeppelin/contracts/Strings.sol";
import {LayoutTypes} from "../types/LayoutTypes.sol";
import {Query} from "../utils/Query.sol";
import {Errors} from "../utils/Errors.sol";

library LibACLManager {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {ACLManager-_setupRole}.
     */
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @dev Emitted when the ACL admin is updated.
     * @param oldAddress The old address of the ACLAdmin
     * @param newAddress The new address of the ACLAdmin
     */
    event ACLAdminUpdated(
        address indexed oldAddress,
        address indexed newAddress
    );

    bytes32 internal constant STORAGE_SLOT = keccak256("aclManager.storage");
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    modifier initializer(LayoutTypes.ACLManagerLayout storage s) {
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

    modifier onlyRole(LayoutTypes.ACLManagerLayout storage s, bytes32 role) {
        _checkRole(s, role, Query._msgSender());
        _;
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

    function initializeACLAdmin(
        LayoutTypes.ACLManagerLayout storage s,
        address admin
    ) internal initializer(s) {
        require(admin != address(0), Errors.ACL_ADMIN_CANNOT_BE_ZERO);

        s.admin = admin;
        _setupRole(s, DEFAULT_ADMIN_ROLE, admin);
    }

    function getACLAdmin(LayoutTypes.ACLManagerLayout storage s)
        internal
        view
        returns (address)
    {
        return s.admin;
    }

    function setACLAdmin(
        LayoutTypes.ACLManagerLayout storage s,
        address newAdmin
    ) internal {
        address oldAdmin = s.admin;
        s.admin = newAdmin;
        emit ACLAdminUpdated(oldAdmin, newAdmin);
    }

    function hasRole(
        LayoutTypes.ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal view returns (bool) {
        return s._roles[role].members[account];
    }

    function grantRole(
        LayoutTypes.ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal onlyRole(s, getRoleAdmin(s, role)) {
        _grantRole(s, role, account);
    }

    function revokeRole(
        LayoutTypes.ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal onlyRole(s, getRoleAdmin(s, role)) {
        _revokeRole(s, role, account);
    }

    function renounceRole(
        LayoutTypes.ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal {
        require(
            account == Query._msgSender(),
            "ACLManager: can only renounce roles for self"
        );

        _revokeRole(s, role, account);
    }

    function getRoleAdmin(LayoutTypes.ACLManagerLayout storage s, bytes32 role)
        internal
        view
        returns (bytes32)
    {
        return s._roles[role].adminRole;
    }

    function setRoleAdmin(
        LayoutTypes.ACLManagerLayout storage s,
        bytes32 role,
        bytes32 adminRole
    ) internal {
        bytes32 previousAdminRole = getRoleAdmin(s, role);
        s._roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     */
    function _setupRole(
        LayoutTypes.ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal virtual {
        _grantRole(s, s, role, account);
    }

    function _grantRole(
        LayoutTypes.ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal {
        if (!hasRole(s, role, account)) {
            s._roles[role].members[account] = true;
            emit RoleGranted(role, account, Query._msgSender());
        }
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^ACLManager: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(
        LayoutTypes.ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal view {
        if (!hasRole(s, role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "ACLManager: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    function _revokeRole(
        LayoutTypes.ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) private {
        if (hasRole(s, role, account)) {
            s._roles[role].members[account] = false;
            emit RoleRevoked(role, account, Query._msgSender());
        }
    }
}
