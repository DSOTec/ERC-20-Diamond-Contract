// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./libraries/LibDiamond.sol";
import "./interfaces/IDiamondCut.sol";
import "./interfaces/IDiamondLoupe.sol";
import "./interfaces/IERC173.sol";

contract Diamond is IERC173 {
    constructor(address _contractOwner, address _diamondCutFacet) {
        LibDiamond.setContractOwner(_contractOwner);

        // Add diamondCut selector from DiamondCutFacet
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondCut.diamondCut.selector;
        LibDiamond.addFacet(_diamondCutFacet, selectors);
    }

    // Fallback: delegate calls to facets
    fallback() external payable {
        address facet = LibDiamond.diamondStorage().selectorToFacet[msg.sig];
        require(facet != address(0), "Diamond: function not found");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
                case 0 { revert(0, returndatasize()) }
                default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}

    // Ownership via LibDiamond
    function owner() external view returns (address owner_) {
        owner_ = LibDiamond.diamondStorage().contractOwner;
    }

    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }
}
