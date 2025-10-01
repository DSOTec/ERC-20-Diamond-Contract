// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibSwapStorage.sol";
import "../libraries/LibERC20Storage.sol";
import "../libraries/LibDiamond.sol";

/**
 * @title SwapFacet
 * @notice Allows users to swap ETH for ERC20 tokens at a fixed exchange rate
 * @dev Uses reentrancy guard pattern and safe math (Solidity 0.8+ has built-in overflow protection)
 */
contract SwapFacet {
    event TokensSwapped(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event ExchangeRateUpdated(uint256 newRate);
    event SwapPaused(bool paused);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Reentrancy guard state
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    /**
     * @notice Swap ETH for tokens at the current exchange rate
     * @dev Payable function - send ETH to receive tokens
     */
    function swapEthForTokens() external payable nonReentrant {
        require(msg.value > 0, "SwapFacet: no ETH sent");
        
        LibSwapStorage.SwapStorage storage ss = LibSwapStorage.swapStorage();
        require(!ss.paused, "SwapFacet: swapping is paused");
        require(ss.exchangeRate > 0, "SwapFacet: exchange rate not set");

        // Calculate tokens to mint (exchangeRate is tokens per 1 ETH with 18 decimals)
        uint256 tokensToMint = (msg.value * ss.exchangeRate) / 1e18;
        require(tokensToMint > 0, "SwapFacet: amount too small");

        // Mint tokens to buyer
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20();
        es.totalSupply += tokensToMint;
        es.balances[msg.sender] += tokensToMint;

        // Update stats
        ss.totalEthReceived += msg.value;

        emit Transfer(address(0), msg.sender, tokensToMint);
        emit TokensSwapped(msg.sender, msg.value, tokensToMint);
    }

    /**
     * @notice Set the exchange rate (tokens per 1 ETH)
     * @param rate The exchange rate with 18 decimals (e.g., 1000e18 = 1000 tokens per ETH)
     */
    function setExchangeRate(uint256 rate) external onlyOwner {
        require(rate > 0, "SwapFacet: rate must be > 0");
        LibSwapStorage.swapStorage().exchangeRate = rate;
        emit ExchangeRateUpdated(rate);
    }

    /**
     * @notice Pause or unpause swapping
     * @param _paused True to pause, false to unpause
     */
    function setSwapPaused(bool _paused) external onlyOwner {
        LibSwapStorage.swapStorage().paused = _paused;
        emit SwapPaused(_paused);
    }

    /**
     * @notice Withdraw accumulated ETH to owner
     */
    function withdrawEth() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "SwapFacet: no ETH to withdraw");
        
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "SwapFacet: ETH transfer failed");
    }

    /**
     * @notice Get current exchange rate
     * @return The exchange rate (tokens per 1 ETH with 18 decimals)
     */
    function getExchangeRate() external view returns (uint256) {
        return LibSwapStorage.swapStorage().exchangeRate;
    }

    /**
     * @notice Check if swapping is paused
     * @return True if paused, false otherwise
     */
    function isSwapPaused() external view returns (bool) {
        return LibSwapStorage.swapStorage().paused;
    }

    /**
     * @notice Get total ETH received through swaps
     * @return Total ETH received
     */
    function getTotalEthReceived() external view returns (uint256) {
        return LibSwapStorage.swapStorage().totalEthReceived;
    }

    /**
     * @notice Calculate how many tokens would be received for a given ETH amount
     * @param ethAmount The amount of ETH
     * @return The amount of tokens that would be received
     */
    function calculateTokensForEth(uint256 ethAmount) external view returns (uint256) {
        LibSwapStorage.SwapStorage storage ss = LibSwapStorage.swapStorage();
        if (ss.exchangeRate == 0) return 0;
        return (ethAmount * ss.exchangeRate) / 1e18;
    }
}
