// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IDiamondCut.sol";

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.libdiamond.storage");

    struct DiamondStorage {
        mapping(bytes4 => address) selectorToFacet;
        mapping(address => bytes4[]) facetToSelectors;
        address[] facetAddresses;
        address contractOwner;
        // EIP-2535 loupe requirement
        mapping(bytes4 => bool) supportedInterfaces;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    // Mirror the event from IDiamondCut so it's in scope for emission
    event DiamondCut(IDiamondCut.FacetCut[] _cut, address _init, bytes _calldata);

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previous = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previous, _newOwner);
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == diamondStorage().contractOwner, "LibDiamond: not owner");
    }

    function addFacet(address facet, bytes4[] memory selectors) internal {
        DiamondStorage storage ds = diamondStorage();
        if (ds.facetToSelectors[facet].length == 0) {
            ds.facetAddresses.push(facet);
        }
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 sel = selectors[i];
            require(ds.selectorToFacet[sel] == address(0), "LibDiamond: selector exists");
            ds.selectorToFacet[sel] = facet;
            ds.facetToSelectors[facet].push(sel);
        }
    }

    function replaceFacet(address facet, bytes4[] memory selectors) internal {
        DiamondStorage storage ds = diamondStorage();
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 sel = selectors[i];
            address oldFacet = ds.selectorToFacet[sel];
            require(oldFacet != address(0), "LibDiamond: selector missing");
            ds.selectorToFacet[sel] = facet;
            // remove from old facet list
            bytes4[] storage oldList = ds.facetToSelectors[oldFacet];
            for (uint256 j = 0; j < oldList.length; j++) {
                if (oldList[j] == sel) {
                    oldList[j] = oldList[oldList.length - 1];
                    oldList.pop();
                    break;
                }
            }
            // add to new facet list
            if (ds.facetToSelectors[facet].length == 0) {
                ds.facetAddresses.push(facet);
            }
            ds.facetToSelectors[facet].push(sel);
        }
    }

    function removeFacet(bytes4[] memory selectors) internal {
        DiamondStorage storage ds = diamondStorage();
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 sel = selectors[i];
            address facet = ds.selectorToFacet[sel];
            require(facet != address(0), "LibDiamond: selector missing");
            ds.selectorToFacet[sel] = address(0);
            // remove from facet list
            bytes4[] storage list = ds.facetToSelectors[facet];
            for (uint256 j = 0; j < list.length; j++) {
                if (list[j] == sel) {
                    list[j] = list[list.length - 1];
                    list.pop();
                    break;
                }
            }
        }
    }

    function diamondCut(IDiamondCut.FacetCut[] memory _cut, address _init, bytes memory _calldata) internal {
        for (uint256 i = 0; i < _cut.length; i++) {
            IDiamondCut.FacetCutAction action = _cut[i].action;
            if (action == IDiamondCut.FacetCutAction.Add) addFacet(_cut[i].facetAddress, _cut[i].functionSelectors);
            else if (action == IDiamondCut.FacetCutAction.Replace) replaceFacet(_cut[i].facetAddress, _cut[i].functionSelectors);
            else if (action == IDiamondCut.FacetCutAction.Remove) removeFacet(_cut[i].functionSelectors);
            else revert("LibDiamond: incorrect FacetCutAction");
        }
        emit DiamondCut(_cut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) private {
        if (_init == address(0)) return;
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                assembly {
                    let size := mload(error)
                    revert(add(error, 32), size)
                }
            } else {
                revert("LibDiamond: init failed");
            }
        }
    }

    // Loupe helpers
    function facetAddresses() internal view returns (address[] memory) {
        return diamondStorage().facetAddresses;
    }

    function facetFunctionSelectors(address facet) internal view returns (bytes4[] memory) {
        return diamondStorage().facetToSelectors[facet];
    }

    function facetAddress(bytes4 selector) internal view returns (address) {
        return diamondStorage().selectorToFacet[selector];
    }
}
