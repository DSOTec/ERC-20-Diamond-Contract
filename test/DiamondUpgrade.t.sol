// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/contracts/Diamond.sol";
import "../src/contracts/facets/DiamondCutFacet.sol";
import "../src/contracts/facets/DiamondLoupeFacet.sol";
import "../src/contracts/facets/ERC20Facet.sol";
import "../src/contracts/facets/ERC20Init.sol";
import "../src/contracts/facets/SwapFacet.sol";
import "../src/contracts/facets/MultiSigFacet.sol";
import "../src/contracts/facets/ERC20MetadataFacet.sol";
import "../src/contracts/facets/SwapFacetInit.sol";
import "../src/contracts/facets/MultiSigFacetInit.sol";
import "../src/contracts/facets/ERC20MintFacet.sol";
import "../src/contracts/interfaces/IDiamondCut.sol";
import "../src/contracts/interfaces/IERC20.sol";

contract DiamondUpgradeTest is Test {
    Diamond diamond;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    ERC20Facet erc20Facet;
    ERC20MintFacet erc20MintFacet;
    SwapFacet swapFacet;
    MultiSigFacet multiSigFacet;
    ERC20MetadataFacet metadataFacet;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);

    uint256 constant EXCHANGE_RATE = 1000e18; // 1000 tokens per ETH

    function setUp() public {
        // Deploy Diamond with DiamondCutFacet
        diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(diamondCutFacet));

        // Deploy and add other facets
        diamondLoupeFacet = new DiamondLoupeFacet();
        erc20Facet = new ERC20Facet();
        erc20MintFacet = new ERC20MintFacet();

        // Add DiamondLoupeFacet
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;

        // Add ERC20Facet
        bytes4[] memory erc20Selectors = new bytes4[](6);
        erc20Selectors[0] = IERC20.name.selector;
        erc20Selectors[1] = IERC20.symbol.selector;
        erc20Selectors[2] = IERC20.decimals.selector;
        erc20Selectors[3] = IERC20.totalSupply.selector;
        erc20Selectors[4] = IERC20.balanceOf.selector;
        erc20Selectors[5] = IERC20.transfer.selector;

        // Add ERC20MintFacet
        bytes4[] memory mintSelectors = new bytes4[](1);
        mintSelectors[0] = ERC20MintFacet.mint.selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(erc20Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc20Selectors
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(erc20MintFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: mintSelectors
        });

        // Initialize ERC20
        ERC20Init erc20Init = new ERC20Init();
        bytes memory initData = abi.encodeWithSelector(
            ERC20Init.init.selector,
            "Diamond Token",
            "DMD"
        );

        IDiamondCut(address(diamond)).diamondCut(cuts, address(erc20Init), initData);

        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    function testUpgradeDiamond() public {
        // Deploy new facets
        swapFacet = new SwapFacet();
        multiSigFacet = new MultiSigFacet();
        metadataFacet = new ERC20MetadataFacet();

        // Prepare upgrade
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

        // 1. Remove mint function
        bytes4[] memory removeMintSelectors = new bytes4[](1);
        removeMintSelectors[0] = ERC20MintFacet.mint.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: removeMintSelectors
        });

        // 2. Add SwapFacet
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

        // 3. Add MultiSigFacet
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

        // 4. Add MetadataFacet
        bytes4[] memory metadataSelectors = new bytes4[](3);
        metadataSelectors[0] = ERC20MetadataFacet.tokenURI.selector;
        metadataSelectors[1] = ERC20MetadataFacet.getTokenName.selector;
        metadataSelectors[2] = ERC20MetadataFacet.getTokenSymbol.selector;
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(metadataFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: metadataSelectors
        });

        // Initialize SwapFacet
        SwapFacetInit swapInit = new SwapFacetInit();
        bytes memory initData = abi.encodeWithSelector(
            SwapFacetInit.init.selector,
            EXCHANGE_RATE
        );

        // Execute upgrade
        IDiamondCut(address(diamond)).diamondCut(cuts, address(swapInit), initData);

        // Verify mint function is removed
        vm.expectRevert();
        ERC20MintFacet(address(diamond)).mint(user1, 1000e18);
    }

    function testSwapFacet() public {
        testUpgradeDiamond(); // First upgrade

        // Test swapping ETH for tokens
        vm.startPrank(user1);
        uint256 ethAmount = 1 ether;
        uint256 expectedTokens = (ethAmount * EXCHANGE_RATE) / 1e18;

        SwapFacet(address(diamond)).swapEthForTokens{value: ethAmount}();

        assertEq(IERC20(address(diamond)).balanceOf(user1), expectedTokens);
        assertEq(SwapFacet(address(diamond)).getTotalEthReceived(), ethAmount);
        vm.stopPrank();

        // Test exchange rate calculation
        uint256 calculated = SwapFacet(address(diamond)).calculateTokensForEth(2 ether);
        assertEq(calculated, (2 ether * EXCHANGE_RATE) / 1e18);

        // Test pause functionality
        SwapFacet(address(diamond)).setSwapPaused(true);
        assertTrue(SwapFacet(address(diamond)).isSwapPaused());

        vm.startPrank(user2);
        vm.expectRevert("SwapFacet: swapping is paused");
        SwapFacet(address(diamond)).swapEthForTokens{value: 1 ether}();
        vm.stopPrank();

        // Unpause
        SwapFacet(address(diamond)).setSwapPaused(false);

        // Test withdraw
        uint256 ownerBalanceBefore = owner.balance;
        SwapFacet(address(diamond)).withdrawEth();
        assertGt(owner.balance, ownerBalanceBefore);
    }

    function testMultiSigFacet() public {
        testUpgradeDiamond(); // First upgrade

        // Add signatories
        MultiSigFacet(address(diamond)).addSignatory(user1);
        MultiSigFacet(address(diamond)).addSignatory(user2);
        MultiSigFacet(address(diamond)).addSignatory(user3);

        // Set threshold
        MultiSigFacet(address(diamond)).setThreshold(2);

        // Verify setup
        address[] memory signatories = MultiSigFacet(address(diamond)).getSignatories();
        assertEq(signatories.length, 3);
        assertEq(MultiSigFacet(address(diamond)).getThreshold(), 2);
        assertTrue(MultiSigFacet(address(diamond)).isSigner(user1));

        // Submit transaction
        vm.startPrank(user1);
        bytes memory data = "";
        uint256 txId = MultiSigFacet(address(diamond)).submitTransaction(user3, 1 ether, data);
        assertEq(txId, 0);
        vm.stopPrank();

        // Confirm transaction
        vm.prank(user1);
        MultiSigFacet(address(diamond)).confirmTransaction(txId);

        vm.prank(user2);
        MultiSigFacet(address(diamond)).confirmTransaction(txId);

        // Check confirmations
        (,,,, uint256 confirmations) = MultiSigFacet(address(diamond)).getTransaction(txId);
        assertEq(confirmations, 2);

        assertTrue(MultiSigFacet(address(diamond)).hasConfirmed(txId, user1));
        assertTrue(MultiSigFacet(address(diamond)).hasConfirmed(txId, user2));
        assertFalse(MultiSigFacet(address(diamond)).hasConfirmed(txId, user3));
    }

    function testMetadataFacet() public {
        testUpgradeDiamond(); // First upgrade

        // Get token URI
        string memory uri = ERC20MetadataFacet(address(diamond)).tokenURI();
        
        // Verify it contains expected data
        assertTrue(bytes(uri).length > 0);
        
        // Check helper functions
        string memory name = ERC20MetadataFacet(address(diamond)).getTokenName();
        string memory symbol = ERC20MetadataFacet(address(diamond)).getTokenSymbol();
        
        assertEq(name, "Diamond Token");
        assertEq(symbol, "DMD");

        // Log the metadata for manual inspection
        console.log("Token URI:");
        console.log(uri);
    }

    function testCompleteWorkflow() public {
        testUpgradeDiamond();

        // 1. User swaps ETH for tokens
        vm.startPrank(user1);
        SwapFacet(address(diamond)).swapEthForTokens{value: 5 ether}();
        uint256 user1Balance = IERC20(address(diamond)).balanceOf(user1);
        assertGt(user1Balance, 0);
        vm.stopPrank();

        // 2. Setup multi-sig
        MultiSigFacet(address(diamond)).addSignatory(user1);
        MultiSigFacet(address(diamond)).addSignatory(user2);
        MultiSigFacet(address(diamond)).setThreshold(2);

        // 3. Submit and execute a multi-sig transaction
        vm.deal(address(diamond), 10 ether);
        
        vm.prank(user1);
        uint256 txId = MultiSigFacet(address(diamond)).submitTransaction(
            user3,
            1 ether,
            ""
        );

        vm.prank(user1);
        MultiSigFacet(address(diamond)).confirmTransaction(txId);

        vm.prank(user2);
        MultiSigFacet(address(diamond)).confirmTransaction(txId);

        uint256 user3BalanceBefore = user3.balance;
        vm.prank(user1);
        MultiSigFacet(address(diamond)).executeTransaction(txId);
        
        assertEq(user3.balance, user3BalanceBefore + 1 ether);

        // 4. Check metadata
        string memory metadata = ERC20MetadataFacet(address(diamond)).tokenURI();
        assertTrue(bytes(metadata).length > 0);

        console.log("=== Complete Workflow Test Passed ===");
        console.log("User1 Token Balance:", user1Balance);
        console.log("Multi-sig Transaction Executed");
        console.log("Metadata Generated Successfully");
    }

    receive() external payable {}
}
