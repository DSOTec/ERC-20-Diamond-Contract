// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/contracts/interfaces/IDiamondCut.sol";
import "../src/contracts/facets/SwapFacet.sol";
import "../src/contracts/facets/MultiSigFacet.sol";
import "../src/contracts/facets/ERC20MetadataFacet.sol";
import "../src/contracts/facets/SwapFacetInit.sol";
import "../src/contracts/facets/MultiSigFacetInit.sol";
import "../src/contracts/facets/ERC20MintFacet.sol";

/**
 * @title UpgradeDiamondWithInit
 * @notice Script to upgrade the deployed Diamond contract with new facets and initialization
 * @dev This script will:
 *      1. Remove the mint() function from ERC20MintFacet
 *      2. Add SwapFacet with swapEthForTokens functionality (with initialization)
 *      3. Add MultiSigFacet with multi-signature wallet functionality (with initialization)
 *      4. Add ERC20MetadataFacet with tokenURI and onchain SVG logo
 */
contract UpgradeDiamondWithInit is Script {
    // Configuration - Update these before running
    address constant DIAMOND_ADDRESS = 0xEB72f180964ce093084dBCd63a7c9f36Ce9B8140; // Deployed Diamond
    uint256 constant INITIAL_EXCHANGE_RATE = 1000e18; // 1000 tokens per 1 ETH
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy new facets
        SwapFacet swapFacet = new SwapFacet();
        MultiSigFacet multiSigFacet = new MultiSigFacet();
        ERC20MetadataFacet metadataFacet = new ERC20MetadataFacet();
        
        // Deploy init contracts
        SwapFacetInit swapInit = new SwapFacetInit();
        MultiSigFacetInit multiSigInit = new MultiSigFacetInit();

        console.log("=== Deployed Contracts ===");
        console.log("SwapFacet:", address(swapFacet));
        console.log("MultiSigFacet:", address(multiSigFacet));
        console.log("ERC20MetadataFacet:", address(metadataFacet));
        console.log("SwapFacetInit:", address(swapInit));
        console.log("MultiSigFacetInit:", address(multiSigInit));
        console.log("");

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
        bytes4[] memory swapSelectors = new bytes4[](8);
        swapSelectors[0] = SwapFacet.swapEthForTokens.selector;
        swapSelectors[1] = SwapFacet.setExchangeRate.selector;
        swapSelectors[2] = SwapFacet.setSwapPaused.selector;
        swapSelectors[3] = SwapFacet.withdrawEth.selector;
        swapSelectors[4] = SwapFacet.getExchangeRate.selector;
        swapSelectors[5] = SwapFacet.isSwapPaused.selector;
        swapSelectors[6] = SwapFacet.getTotalEthReceived.selector;
        swapSelectors[7] = SwapFacet.calculateTokensForEth.selector;
        
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(swapFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: swapSelectors
        });

        // 3. Add MultiSigFacet functions
        bytes4[] memory multiSigSelectors = new bytes4[](13);
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
        multiSigSelectors[12] = MultiSigFacet.hasConfirmed.selector;
        
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

        // Prepare initialization data
        // First initialize SwapFacet, then MultiSigFacet
        bytes memory swapInitData = abi.encodeWithSelector(
            SwapFacetInit.init.selector,
            INITIAL_EXCHANGE_RATE
        );

        // Execute first diamondCut with SwapFacet initialization
        console.log("=== Executing Diamond Upgrade ===");
        IDiamondCut(DIAMOND_ADDRESS).diamondCut(cuts, address(swapInit), swapInitData);

        console.log("Diamond upgraded successfully!");
        console.log("- Removed mint() function");
        console.log("- Added SwapFacet (initialized with rate:", INITIAL_EXCHANGE_RATE, ")");
        console.log("- Added MultiSigFacet");
        console.log("- Added ERC20MetadataFacet");
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Initialize MultiSig by calling addSignatory() and setThreshold()");
        console.log("2. Set exchange rate if needed using setExchangeRate()");
        console.log("3. Test swapEthForTokens() functionality");
        console.log("4. View metadata using tokenURI()");

        vm.stopBroadcast();
    }
}
