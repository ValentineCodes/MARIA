// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {LibACLManager} from "./LibACLManager.sol";
import {Context} from "../../dependencies/openzeppelin/contracts/Context.sol";

contract Modifiers {
    using LibACLManager for LibACLManager.ACLManagerLayout;
    
    modifier onlyRole(bytes32 role) {
        LibACLManager.ACLManagerLayout storage s = LibACLManager.layout();
        LibACLManager.layout()._checkRole(s, role, Context._msgSender())
        _;
    }
}