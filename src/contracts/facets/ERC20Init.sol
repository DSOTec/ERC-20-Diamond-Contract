// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibERC20Storage.sol";

contract ERC20Init {
    // Called via diamondCut initialization to set metadata
    function init(string memory _name, string memory _symbol, uint8 _decimals) external {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20();
        es.name = _name;
        es.symbol = _symbol;
        es.decimals = _decimals; // not used by decimals() here but kept for completeness
    }
}
