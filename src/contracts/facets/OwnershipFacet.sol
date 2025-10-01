// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibDiamond.sol";

contract OwnershipFacet {
    function owner() external view returns (address) {
        return LibDiamond.diamondStorage().contractOwner;
    }

    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }
}
