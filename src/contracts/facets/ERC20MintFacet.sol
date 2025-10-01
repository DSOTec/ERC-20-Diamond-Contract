// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibERC20Storage.sol";
import "../interfaces/IERC20.sol";

contract ERC20MintFacet {
    // ERC20 Events (needed for minting to emit Transfer events)
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Public mint: anyone can mint
    function mint(address to, uint256 amount) public {
        require(to != address(0), "ERC20: mint to zero");
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20();
        es.totalSupply += amount;
        es.balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}
