// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import {OwnableInternal} from "../../../access/ownable/OwnableInternal.sol";
import {DiamondBaseStorage} from "../base/DiamondBaseStorage.sol";
import {IDiamondWritable} from "./IDiamondWritable.sol";

error UpdateDisabled();

/**
 * @title EIP-2535 "Diamond" proxy update contract
 */
abstract contract DiamondWritable is IDiamondWritable, OwnableInternal {
    using DiamondBaseStorage for DiamondBaseStorage.Layout;

    /**
     * @inheritdoc IDiamondWritable
     */

    function setUpdateTimestamps() external onlyOwner {
        if(block.timestamp >= DiamondBaseStorage.layout().updateEndTimestamp) {revert UpdateDisabled()}

        DiamondBaseStorage.layout().setUpdateTimestamps();
    }

    function diamondCut(
        FacetCut[] calldata facetCuts,
        address target,
        bytes calldata data
    ) external onlyOwner {
         DiamondBaseStorage.Layout memory l = DiamondBaseStorage.layout();

        if(block.timestamp < l.updateStartTimestamp || block.timestamp >= l.updateEndTimestamp) {revert UpdateDisabled()}

        DiamondBaseStorage.layout().diamondCut(facetCuts, target, data);
    }
}
