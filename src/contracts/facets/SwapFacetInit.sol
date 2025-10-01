// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibSwapStorage.sol";

/**
 * @title SwapFacetInit
 * @notice Initialization contract for SwapFacet
 * @dev This contract is called via delegatecall during diamondCut to initialize SwapFacet storage
 */
contract SwapFacetInit {
    event ExchangeRateInitialized(uint256 rate);

    /**
     * @notice Initialize SwapFacet with default exchange rate
     * @param exchangeRate Initial exchange rate (tokens per 1 ETH with 18 decimals)
     */
    function init(uint256 exchangeRate) external {
        require(exchangeRate > 0, "SwapFacetInit: rate must be > 0");
        
        LibSwapStorage.SwapStorage storage ss = LibSwapStorage.swapStorage();
        ss.exchangeRate = exchangeRate;
        ss.paused = false;
        ss.totalEthReceived = 0;

        emit ExchangeRateInitialized(exchangeRate);
    }
}
