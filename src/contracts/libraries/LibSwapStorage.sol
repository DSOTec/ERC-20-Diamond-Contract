// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibSwapStorage {
    bytes32 constant STORAGE_POSITION = keccak256("diamond.standard.swap.storage");

    struct SwapStorage {
        uint256 exchangeRate; // How many tokens per 1 ETH (with 18 decimals)
        bool paused;
        uint256 totalEthReceived;
    }

    function swapStorage() internal pure returns (SwapStorage storage ss) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ss.slot := position
        }
    }
}
