// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {SolidStateDiamond} from "../dependencies/solidstate/contracts/proxy/diamond/SolidStateDiamond.sol";
import {LibACLManager} from "../libraries/configuration/LibACLManager.sol";

contract MariaDiamond is SolidStateDiamond {
    using LibACLManager for LibACLManager.LibACLManagerLayout;

    struct Args {
        address aclAdmin;
    }

    constructor(Args calldata args) SolidStateDiamond() {
        // initialize facets

        LibACLManager.layout().initACLManager(args.aclAdmin);
    }
}
