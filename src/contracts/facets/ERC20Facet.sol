// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibERC20Storage.sol";
import "../interfaces/IERC20.sol";

contract ERC20Facet is IERC20 {
    using LibERC20Storage for LibERC20Storage.ERC20Storage;

    function name() external view override returns (string memory) {
        return LibERC20Storage.erc20().name;
    }

    function symbol() external view override returns (string memory) {
        return LibERC20Storage.erc20().symbol;
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function totalSupply() external view override returns (uint256) {
        return LibERC20Storage.erc20().totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return LibERC20Storage.erc20().balances[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(to != address(0), "ERC20: transfer to zero");
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20();
        uint256 bal = es.balances[msg.sender];
        require(bal >= amount, "ERC20: balance too low");
        unchecked {
            es.balances[msg.sender] = bal - amount;
            es.balances[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        LibERC20Storage.erc20().allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner_, address spender) external view override returns (uint256) {
        return LibERC20Storage.erc20().allowances[owner_][spender];
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(to != address(0), "ERC20: transfer to zero");
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20();
        uint256 bal = es.balances[from];
        require(bal >= amount, "ERC20: balance too low");
        uint256 allowed = es.allowances[from][msg.sender];
        require(allowed >= amount, "ERC20: allowance");
        unchecked {
            es.allowances[from][msg.sender] = allowed - amount;
            es.balances[from] = bal - amount;
            es.balances[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }
}
