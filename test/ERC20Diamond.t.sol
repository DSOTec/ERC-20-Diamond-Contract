// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/contracts/Diamond.sol";
import "../src/contracts/facets/DiamondCutFacet.sol";
import "../src/contracts/facets/DiamondLoupeFacet.sol";
import "../src/contracts/facets/OwnershipFacet.sol";
import "../src/contracts/facets/ERC20Facet.sol";
import "../src/contracts/facets/ERC20MintFacet.sol";
import "../src/contracts/facets/ERC20Init.sol";
import "../src/contracts/interfaces/IDiamondCut.sol";
import "../src/contracts/interfaces/IERC20.sol";

contract ERC20DiamondTest is Test {
    // Events for testing
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    Diamond diamond;
    DiamondCutFacet cutFacet;
    DiamondLoupeFacet loupe;
    OwnershipFacet own;
    ERC20Facet erc20Facet;
    ERC20MintFacet mintFacet;
    ERC20Init initFacet;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        address owner = address(this);
        cutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(cutFacet));
        loupe = new DiamondLoupeFacet();
        own = new OwnershipFacet();
        erc20Facet = new ERC20Facet();
        mintFacet = new ERC20MintFacet();
        initFacet = new ERC20Init();

        // Build cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](5);

        // Loupe
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        cut[0] = IDiamondCut.FacetCut(address(loupe), IDiamondCut.FacetCutAction.Add, loupeSelectors);

        // Ownership
        bytes4[] memory ownSelectors = new bytes4[](2);
        ownSelectors[0] = OwnershipFacet.owner.selector;
        ownSelectors[1] = OwnershipFacet.transferOwnership.selector;
        cut[1] = IDiamondCut.FacetCut(address(own), IDiamondCut.FacetCutAction.Add, ownSelectors);

        // ERC20 group 1
        bytes4[] memory erc20Sel1 = new bytes4[](7);
        erc20Sel1[0] = ERC20Facet.name.selector;
        erc20Sel1[1] = ERC20Facet.symbol.selector;
        erc20Sel1[2] = ERC20Facet.decimals.selector;
        erc20Sel1[3] = ERC20Facet.totalSupply.selector;
        erc20Sel1[4] = ERC20Facet.balanceOf.selector;
        erc20Sel1[5] = ERC20Facet.transfer.selector;
        erc20Sel1[6] = ERC20Facet.approve.selector;
        cut[2] = IDiamondCut.FacetCut(address(erc20Facet), IDiamondCut.FacetCutAction.Add, erc20Sel1);

        // ERC20 group 2
        bytes4[] memory erc20Sel2 = new bytes4[](2);
        erc20Sel2[0] = ERC20Facet.allowance.selector;
        erc20Sel2[1] = ERC20Facet.transferFrom.selector;
        cut[3] = IDiamondCut.FacetCut(address(erc20Facet), IDiamondCut.FacetCutAction.Add, erc20Sel2);

        // Mint
        bytes4[] memory mintSel = new bytes4[](1);
        mintSel[0] = ERC20MintFacet.mint.selector;
        cut[4] = IDiamondCut.FacetCut(address(mintFacet), IDiamondCut.FacetCutAction.Add, mintSel);

        // Init metadata
        bytes memory calldataInit = abi.encodeWithSelector(ERC20Init.init.selector, "DiamondToken", "DIAM", 18);
        IDiamondCut(address(diamond)).diamondCut(cut, address(initFacet), calldataInit);
    }

    function testMetadata() public {
        IERC20 token = IERC20(address(diamond));
        assertEq(token.name(), "DiamondToken");
        assertEq(token.symbol(), "DIAM");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
    }

    function testPublicMint() public {
        IERC20 token = IERC20(address(diamond));

        // Anyone can mint: use alice to mint to herself
        vm.prank(alice);
        (bool ok, ) = address(diamond).call(abi.encodeWithSelector(ERC20MintFacet.mint.selector, alice, 100 ether));
        assertTrue(ok);

        assertEq(token.totalSupply(), 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);
    }

    function testTransferAndApprove() public {
        IERC20 token = IERC20(address(diamond));

        // Mint to Alice
        vm.prank(alice);
        (bool ok, ) = address(diamond).call(abi.encodeWithSelector(ERC20MintFacet.mint.selector, alice, 50 ether));
        assertTrue(ok);

        // Alice transfers to Bob
        vm.prank(alice);
        assertTrue(token.transfer(bob, 20 ether));
        assertEq(token.balanceOf(bob), 20 ether);
        assertEq(token.balanceOf(alice), 30 ether);

        // Alice approves Bob
        vm.prank(alice);
        assertTrue(token.approve(bob, 10 ether));
        assertEq(token.allowance(alice, bob), 10 ether);

        // Bob transferFrom Alice to himself
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, 10 ether));
        assertEq(token.balanceOf(bob), 30 ether);
        assertEq(token.balanceOf(alice), 20 ether);
        assertEq(token.allowance(alice, bob), 0);
    }

    function testMintEmitsTransferEvent() public {
        vm.expectEmit(true, true, false, true);
        // Expect the Transfer event from the ERC20MintFacet
        emit Transfer(address(0), alice, 1 ether);
        vm.prank(alice);
        (bool ok, ) = address(diamond).call(abi.encodeWithSelector(ERC20MintFacet.mint.selector, alice, 1 ether));
        assertTrue(ok);
    }

    // ========== Ownership Tests ==========
    function testOwnershipInitialOwner() public {
        OwnershipFacet ownershipFacet = OwnershipFacet(address(diamond));
        assertEq(ownershipFacet.owner(), address(this));
    }

    function testOwnershipTransfer() public {
        OwnershipFacet ownershipFacet = OwnershipFacet(address(diamond));
        
        // Transfer ownership to alice
        ownershipFacet.transferOwnership(alice);
        assertEq(ownershipFacet.owner(), alice);
        
        // Alice can now transfer to bob
        vm.prank(alice);
        ownershipFacet.transferOwnership(bob);
        assertEq(ownershipFacet.owner(), bob);
    }

    function testOwnershipTransferUnauthorized() public {
        OwnershipFacet ownershipFacet = OwnershipFacet(address(diamond));
        
        // Alice tries to transfer ownership without being owner
        vm.prank(alice);
        vm.expectRevert("LibDiamond: not owner");
        ownershipFacet.transferOwnership(bob);
    }

    // ========== Diamond Loupe Tests ==========
    function testLoupeFacetAddresses() public {
        DiamondLoupeFacet loupeFacet = DiamondLoupeFacet(address(diamond));
        address[] memory facetAddrs = loupeFacet.facetAddresses();
        
        // Should have cutFacet, loupe, own, erc20Facet, and mintFacet
        assertEq(facetAddrs.length, 5);
        
        // Verify the facet addresses are in the list
        bool hasCutFacet = false;
        bool hasLoupe = false;
        bool hasOwn = false;
        bool hasErc20 = false;
        bool hasMint = false;
        
        for (uint i = 0; i < facetAddrs.length; i++) {
            if (facetAddrs[i] == address(cutFacet)) hasCutFacet = true;
            if (facetAddrs[i] == address(loupe)) hasLoupe = true;
            if (facetAddrs[i] == address(own)) hasOwn = true;
            if (facetAddrs[i] == address(erc20Facet)) hasErc20 = true;
            if (facetAddrs[i] == address(mintFacet)) hasMint = true;
        }
        
        assertTrue(hasCutFacet);
        assertTrue(hasLoupe);
        assertTrue(hasOwn);
        assertTrue(hasErc20);
        assertTrue(hasMint);
    }

    function testLoupeFacetAddress() public {
        DiamondLoupeFacet loupeFacet = DiamondLoupeFacet(address(diamond));
        
        // Check that specific selectors map to correct facets
        assertEq(loupeFacet.facetAddress(ERC20Facet.name.selector), address(erc20Facet));
        assertEq(loupeFacet.facetAddress(ERC20MintFacet.mint.selector), address(mintFacet));
        assertEq(loupeFacet.facetAddress(OwnershipFacet.owner.selector), address(own));
    }

    function testLoupeFacetFunctionSelectors() public {
        DiamondLoupeFacet loupeFacet = DiamondLoupeFacet(address(diamond));
        
        // Get selectors for ERC20Facet
        bytes4[] memory selectors = loupeFacet.facetFunctionSelectors(address(erc20Facet));
        assertEq(selectors.length, 9); // 7 from first cut + 2 from second cut
        
        // Get selectors for MintFacet
        bytes4[] memory mintSelectors = loupeFacet.facetFunctionSelectors(address(mintFacet));
        assertEq(mintSelectors.length, 1);
        assertEq(mintSelectors[0], ERC20MintFacet.mint.selector);
    }

    function testLoupeFacets() public {
        DiamondLoupeFacet loupeFacet = DiamondLoupeFacet(address(diamond));
        IDiamondLoupe.Facet[] memory facetList = loupeFacet.facets();
        
        assertEq(facetList.length, 5);
        
        // Verify each facet has selectors
        for (uint i = 0; i < facetList.length; i++) {
            assertTrue(facetList[i].facetAddress != address(0));
            assertTrue(facetList[i].functionSelectors.length > 0);
        }
    }

    // ========== Diamond Proxy Fallback Tests ==========
    function testDiamondFallbackDelegatesCorrectly() public {
        // Call ERC20 functions through the diamond proxy
        IERC20 token = IERC20(address(diamond));
        
        // These calls test the fallback delegation
        assertEq(token.name(), "DiamondToken");
        assertEq(token.symbol(), "DIAM");
        assertEq(token.decimals(), 18);
    }

    function testDiamondFallbackRevertsOnUnknownSelector() public {
        // Try to call a function that doesn't exist
        vm.expectRevert("Diamond: function not found");
        address(diamond).call(abi.encodeWithSignature("nonExistentFunction()"));
    }

    // ========== Facet Replace Tests ==========
    function testReplaceFacet() public {
        // Deploy a new ERC20Facet
        ERC20Facet newErc20Facet = new ERC20Facet();
        
        // Replace the name and symbol selectors with the new facet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = ERC20Facet.name.selector;
        selectors[1] = ERC20Facet.symbol.selector;
        
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(newErc20Facet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
        
        // Verify the facet was replaced
        DiamondLoupeFacet loupeFacet = DiamondLoupeFacet(address(diamond));
        assertEq(loupeFacet.facetAddress(ERC20Facet.name.selector), address(newErc20Facet));
        
        // Function should still work
        IERC20 token = IERC20(address(diamond));
        assertEq(token.name(), "DiamondToken");
    }

    // ========== Facet Remove Tests ==========
    function testRemoveFacet() public {
        // Remove the mint function
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = ERC20MintFacet.mint.selector;
        
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectors
        });
        
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
        
        // Verify the selector was removed
        DiamondLoupeFacet loupeFacet = DiamondLoupeFacet(address(diamond));
        assertEq(loupeFacet.facetAddress(ERC20MintFacet.mint.selector), address(0));
        
        // Calling mint should now fail
        vm.expectRevert("Diamond: function not found");
        address(diamond).call(abi.encodeWithSelector(ERC20MintFacet.mint.selector, alice, 1 ether));
    }
}
