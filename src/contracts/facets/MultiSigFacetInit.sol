// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibMultiSigStorage.sol";

/**
 * @title MultiSigFacetInit
 * @notice Initialization contract for MultiSigFacet
 * @dev This contract is called via delegatecall during diamondCut to initialize MultiSigFacet storage
 */
contract MultiSigFacetInit {
    event MultiSigInitialized(address[] signatories, uint256 threshold);

    /**
     * @notice Initialize MultiSigFacet with initial signatories and threshold
     * @param initialSignatories Array of initial signatory addresses
     * @param initialThreshold Minimum number of confirmations required
     */
    function init(address[] calldata initialSignatories, uint256 initialThreshold) external {
        require(initialSignatories.length > 0, "MultiSigInit: no signatories");
        require(initialThreshold > 0, "MultiSigInit: threshold must be > 0");
        require(initialThreshold <= initialSignatories.length, "MultiSigInit: threshold too high");

        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();
        
        for (uint256 i = 0; i < initialSignatories.length; i++) {
            address signatory = initialSignatories[i];
            require(signatory != address(0), "MultiSigInit: zero address");
            require(!ms.isSigner[signatory], "MultiSigInit: duplicate signer");
            
            ms.signatories.push(signatory);
            ms.isSigner[signatory] = true;
        }

        ms.threshold = initialThreshold;

        emit MultiSigInitialized(initialSignatories, initialThreshold);
    }
}
