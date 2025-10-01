// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/contracts/interfaces/IDiamondCut.sol";
import "../src/contracts/facets/SwapFacet.sol";
import "../src/contracts/facets/MultiSigFacet.sol";
import "../src/contracts/facets/ERC20MetadataFacet.sol";
import "../src/contracts/facets/ERC20MintFacet.sol";

/**
 * @title UpgradeDiamond
 * @notice Script to upgrade the deployed Diamond contract with new facets
 * @dev This script will:
 *      1. Remove the mint() function from ERC20MintFacet
 *      2. Add SwapFacet with swapEthForTokens functionality
 *      3. Add MultiSigFacet with multi-signature wallet functionality
 *      4. Add ERC20MetadataFacet with tokenURI and onchain SVG logo
 */
contract UpgradeDiamond is Script {
    // Replace with your deployed Diamond address
    address constant DIAMOND_ADDRESS = address(0); // TODO: Set your Diamond address here
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy new facets
        SwapFacet swapFacet = new SwapFacet();
        MultiSigFacet multiSigFacet = new MultiSigFacet();
        ERC20MetadataFacet metadataFacet = new ERC20MetadataFacet();

        console.log("Deployed SwapFacet at:", address(swapFacet));
        console.log("Deployed MultiSigFacet at:", address(multiSigFacet));
        console.log("Deployed ERC20MetadataFacet at:", address(metadataFacet));

        // Prepare diamondCut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

        // 1. Remove mint function from ERC20MintFacet
        bytes4[] memory removeMintSelectors = new bytes4[](1);
        removeMintSelectors[0] = ERC20MintFacet.mint.selector;
        
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: removeMintSelectors
        });

        // 2. Add SwapFacet functions
        bytes4[] memory swapSelectors = new bytes4[](7);
        swapSelectors[0] = SwapFacet.swapEthForTokens.selector;
        swapSelectors[1] = SwapFacet.setExchangeRate.selector;
        swapSelectors[2] = SwapFacet.setSwapPaused.selector;
        swapSelectors[3] = SwapFacet.withdrawEth.selector;
        swapSelectors[4] = SwapFacet.getExchangeRate.selector;
        swapSelectors[5] = SwapFacet.isSwapPaused.selector;
        swapSelectors[6] = SwapFacet.getTotalEthReceived.selector;
        
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(swapFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: swapSelectors
        });

        // 3. Add MultiSigFacet functions
        bytes4[] memory multiSigSelectors = new bytes4[](12);
        multiSigSelectors[0] = MultiSigFacet.addSignatory.selector;
        multiSigSelectors[1] = MultiSigFacet.removeSignatory.selector;
        multiSigSelectors[2] = MultiSigFacet.setThreshold.selector;
        multiSigSelectors[3] = MultiSigFacet.submitTransaction.selector;
        multiSigSelectors[4] = MultiSigFacet.confirmTransaction.selector;
        multiSigSelectors[5] = MultiSigFacet.revokeConfirmation.selector;
        multiSigSelectors[6] = MultiSigFacet.executeTransaction.selector;
        multiSigSelectors[7] = MultiSigFacet.getSignatories.selector;
        multiSigSelectors[8] = MultiSigFacet.getThreshold.selector;
        multiSigSelectors[9] = MultiSigFacet.isSigner.selector;
        multiSigSelectors[10] = MultiSigFacet.getTransaction.selector;
        multiSigSelectors[11] = MultiSigFacet.getTransactionCount.selector;
        
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(multiSigFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: multiSigSelectors
        });

        // 4. Add ERC20MetadataFacet functions
        bytes4[] memory metadataSelectors = new bytes4[](3);
        metadataSelectors[0] = ERC20MetadataFacet.tokenURI.selector;
        metadataSelectors[1] = ERC20MetadataFacet.getTokenName.selector;
        metadataSelectors[2] = ERC20MetadataFacet.getTokenSymbol.selector;
        
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(metadataFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: metadataSelectors
        });

        // Execute diamondCut
        IDiamondCut(DIAMOND_ADDRESS).diamondCut(cuts, address(0), "");

        console.log("Diamond upgraded successfully!");
        console.log("- Removed mint() function");
        console.log("- Added SwapFacet");
        console.log("- Added MultiSigFacet");
        console.log("- Added ERC20MetadataFacet");

        vm.stopBroadcast();
    }

    /**
     * @notice Helper function to get all selectors for verification
     */
    function getSwapFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = SwapFacet.swapEthForTokens.selector;
        selectors[1] = SwapFacet.setExchangeRate.selector;
        selectors[2] = SwapFacet.setSwapPaused.selector;
        selectors[3] = SwapFacet.withdrawEth.selector;
        selectors[4] = SwapFacet.getExchangeRate.selector;
        selectors[5] = SwapFacet.isSwapPaused.selector;
        selectors[6] = SwapFacet.getTotalEthReceived.selector;
        selectors[7] = SwapFacet.calculateTokensForEth.selector;
        return selectors;
    }

    function getMultiSigFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](13);
        selectors[0] = MultiSigFacet.addSignatory.selector;
        selectors[1] = MultiSigFacet.removeSignatory.selector;
        selectors[2] = MultiSigFacet.setThreshold.selector;
        selectors[3] = MultiSigFacet.submitTransaction.selector;
        selectors[4] = MultiSigFacet.confirmTransaction.selector;
        selectors[5] = MultiSigFacet.revokeConfirmation.selector;
        selectors[6] = MultiSigFacet.executeTransaction.selector;
        selectors[7] = MultiSigFacet.getSignatories.selector;
        selectors[8] = MultiSigFacet.getThreshold.selector;
        selectors[9] = MultiSigFacet.isSigner.selector;
        selectors[10] = MultiSigFacet.getTransaction.selector;
        selectors[11] = MultiSigFacet.getTransactionCount.selector;
        selectors[12] = MultiSigFacet.hasConfirmed.selector;
        return selectors;
    }

    function getMetadataFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = ERC20MetadataFacet.tokenURI.selector;
        selectors[1] = ERC20MetadataFacet.getTokenName.selector;
        selectors[2] = ERC20MetadataFacet.getTokenSymbol.selector;
        return selectors;
    }
}
