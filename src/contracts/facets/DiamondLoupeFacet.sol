// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IDiamondLoupe.sol";
import "../libraries/LibDiamond.sol";

contract DiamondLoupeFacet is IDiamondLoupe {
    function facets() external view override returns (Facet[] memory result) {
        address[] memory addrs = LibDiamond.facetAddresses();
        result = new Facet[](addrs.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            result[i].facetAddress = addrs[i];
            result[i].functionSelectors = LibDiamond.facetFunctionSelectors(addrs[i]);
        }
    }

    function facetFunctionSelectors(address _facet) external view override returns (bytes4[] memory) {
        return LibDiamond.facetFunctionSelectors(_facet);
    }

    function facetAddresses() external view override returns (address[] memory) {
        return LibDiamond.facetAddresses();
    }

    function facetAddress(bytes4 _selector) external view override returns (address) {
        return LibDiamond.facetAddress(_selector);
    }
}
