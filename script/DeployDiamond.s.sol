// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/contracts/Diamond.sol";
import "../src/contracts/facets/DiamondCutFacet.sol";
import "../src/contracts/facets/DiamondLoupeFacet.sol";
import "../src/contracts/facets/OwnershipFacet.sol";
import "../src/contracts/facets/ERC20Facet.sol";
import "../src/contracts/facets/ERC20MintFacet.sol";
import "../src/contracts/facets/ERC20Init.sol";
import "../src/contracts/interfaces/IDiamondCut.sol";

contract DeployDiamond is Script {
    function run() external {
        // Load deployer from env/private key
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);

        // 1. Deploy core facets
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        Diamond diamond = new Diamond(deployer, address(cutFacet));

        DiamondLoupeFacet loupe = new DiamondLoupeFacet();
        OwnershipFacet own = new OwnershipFacet();

        // 2. Deploy ERC20 facets
        ERC20Facet erc20 = new ERC20Facet();
        ERC20MintFacet mint = new ERC20MintFacet();
        ERC20Init init = new ERC20Init();

        // 3. Build cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);

        // Loupe selectors
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Ownership selectors
        bytes4[] memory ownSelectors = new bytes4[](2);
        ownSelectors[0] = OwnershipFacet.owner.selector;
        ownSelectors[1] = OwnershipFacet.transferOwnership.selector;
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(own),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownSelectors
        });

        // ERC20 selectors
        bytes4[] memory erc20Selectors = new bytes4[](7);
        erc20Selectors[0] = ERC20Facet.name.selector;
        erc20Selectors[1] = ERC20Facet.symbol.selector;
        erc20Selectors[2] = ERC20Facet.decimals.selector;
        erc20Selectors[3] = ERC20Facet.totalSupply.selector;
        erc20Selectors[4] = ERC20Facet.balanceOf.selector;
        erc20Selectors[5] = ERC20Facet.transfer.selector;
        erc20Selectors[6] = ERC20Facet.approve.selector;
        // Note: allowance + transferFrom as well
        // Expand to include allowance and transferFrom
        bytes4[] memory erc20Selectors2 = new bytes4[](2);
        erc20Selectors2[0] = ERC20Facet.allowance.selector;
        erc20Selectors2[1] = ERC20Facet.transferFrom.selector;

        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(erc20),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc20Selectors
        });
        // We need to add the remaining two as well (can use another cut entry or merge)
        IDiamondCut.FacetCut[] memory cutFull = new IDiamondCut.FacetCut[](5);
        cutFull[0] = cut[0];
        cutFull[1] = cut[1];
        cutFull[2] = cut[2];
        cutFull[3] = IDiamondCut.FacetCut({
            facetAddress: address(erc20),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc20Selectors2
        });

        // Mint selectors
        bytes4[] memory mintSelectors = new bytes4[](1);
        mintSelectors[0] = ERC20MintFacet.mint.selector;
        cutFull[4] = IDiamondCut.FacetCut({
            facetAddress: address(mint),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: mintSelectors
        });

        // 4. Initialize ERC20 metadata via ERC20Init
        bytes memory calldataInit = abi.encodeWithSelector(ERC20Init.init.selector, "DiamondToken", "DIAM", 18);

        // 5. Execute cut
        IDiamondCut(address(diamond)).diamondCut(cutFull, address(init), calldataInit);

        vm.stopBroadcast();

        // Log addresses
        console2.log("Deployer:", deployer);
        console2.log("Diamond:", address(diamond));
        console2.log("CutFacet:", address(cutFacet));
        console2.log("LoupeFacet:", address(loupe));
        console2.log("OwnershipFacet:", address(own));
        console2.log("ERC20Facet:", address(erc20));
        console2.log("MintFacet:", address(mint));
        console2.log("InitFacet:", address(init));
    }
}
