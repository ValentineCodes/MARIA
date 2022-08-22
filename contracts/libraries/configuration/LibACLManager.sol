// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Context} from "../../dependencies/openzeppelin/contracts/Context.sol";
import {Strings} from "../../dependencies/openzeppelin/contracts/Strings.sol";

error ACLManager__ACL_ADMIN_CANNOT_BE_ZERO();

library LibACLManager {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }
    struct ACLManagerLayout {
        address aclAdmin;
        mapping(bytes32 => RoleData) _roles;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("aclmanager.storage");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

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

    modifier onlyRole(ACLManagerLayout storage s, bytes32 role) {
        _checkRole(s, role, Context._msgSender());
        _;
    }

    function layout() internal pure returns (ACLManagerLayout storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    /**
     * @dev Can only be called in {MariaDiamond} constructor
     * @param aclAdmin The address of the ACLManager admin
     */
    function initACLManager(ACLManagerLayout storage s, address aclAdmin)
        internal
    {
        if (aclAdmin == address(0)) {
            revert ACLManager__ACL_ADMIN_CANNOT_BE_ZERO();
        }

        s.aclAdmin = aclAdmin;
        _setupRole(s, DEFAULT_ADMIN_ROLE, aclAdmin);
    }

    function getACLAdmin(ACLManagerLayout storage s)
        internal
        view
        returns (address)
    {
        return s.aclAdmin;
    }

    function setACLAdmin(ACLManagerLayout storage s, address newAclAdmin)
        internal
    {
        address oldAclAdmin = s.aclAdmin;
        s.aclAdmin = newAclAdmin;
        emit ACLAdminUpdated(oldAclAdmin, newAclAdmin);
    }

    function hasRole(
        ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal view returns (bool) {
        return s._roles[role].members[account];
    }

    function grantRole(
        ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal onlyRole(s, getRoleAdmin(s, role)) {
        _grantRole(s, role, account);
    }

    function revokeRole(
        ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal onlyRole(s, getRoleAdmin(s, role)) {
        _revokeRole(s, role, account);
    }

    function renounceRole(
        ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal {
        require(
            account == Context._msgSender(),
            "ACLManager: can only renounce roles for self"
        );

        _revokeRole(s, role, account);
    }

    function getRoleAdmin(ACLManagerLayout storage s, bytes32 role)
        internal
        view
        returns (bytes32)
    {
        return s._roles[role].adminRole;
    }

    function setRoleAdmin(
        ACLManagerLayout storage s,
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
        ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal virtual {
        _grantRole(s, s, role, account);
    }

    function _grantRole(
        ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) internal {
        if (!hasRole(s, role, account)) {
            s._roles[role].members[account] = true;
            emit RoleGranted(role, account, Context._msgSender());
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
        ACLManagerLayout storage s,
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
        ACLManagerLayout storage s,
        bytes32 role,
        address account
    ) private {
        if (hasRole(s, role, account)) {
            s._roles[role].members[account] = false;
            emit RoleRevoked(role, account, Context._msgSender());
        }
    }
}
