# Diamond Upgrade Guide

This guide explains how to upgrade your deployed ERC-20 Diamond contract with three new facets: SwapFacet, MultiSigFacet, and ERC20MetadataFacet.

## Overview

The upgrade adds the following functionality to your Diamond:

1. **SwapFacet** - Allows users to buy tokens with ETH at a fixed exchange rate
2. **MultiSigFacet** - Multi-signature wallet functionality for secure governance
3. **ERC20MetadataFacet** - Onchain token metadata with embedded SVG logo

The upgrade also **removes** the public `mint()` function from ERC20MintFacet for security.

## New Files Created

### Facets
- `src/contracts/facets/SwapFacet.sol` - ETH to token swap functionality
- `src/contracts/facets/MultiSigFacet.sol` - Multi-signature wallet
- `src/contracts/facets/ERC20MetadataFacet.sol` - Onchain metadata with SVG logo

### Storage Libraries
- `src/contracts/libraries/LibSwapStorage.sol` - Storage for SwapFacet
- `src/contracts/libraries/LibMultiSigStorage.sol` - Storage for MultiSigFacet

### Initialization Contracts
- `src/contracts/facets/SwapFacetInit.sol` - Initialize SwapFacet storage
- `src/contracts/facets/MultiSigFacetInit.sol` - Initialize MultiSigFacet storage

### Scripts
- `script/UpgradeDiamond.s.sol` - Basic upgrade script
- `script/UpgradeDiamondWithInit.s.sol` - Upgrade script with initialization

### Tests
- `test/DiamondUpgrade.t.sol` - Comprehensive test suite

## Upgrade Steps

### 1. Run Tests (Recommended)

First, verify everything works in a test environment:

```bash
forge test --match-contract DiamondUpgradeTest -vv
```

### 2. Configure the Upgrade Script

Edit `script/UpgradeDiamondWithInit.s.sol`:

```solidity
// Update these constants
address constant DIAMOND_ADDRESS = 0xYourDiamondAddress;
uint256 constant INITIAL_EXCHANGE_RATE = 1000e18; // 1000 tokens per 1 ETH
```

### 3. Set Environment Variables

Create a `.env` file:

```bash
PRIVATE_KEY=your_private_key_here
LISK_TESTNET_RPC=your_rpc_url_here
```

### 4. Execute the Upgrade

**Dry run (simulation):**
```bash
forge script script/UpgradeDiamondWithInit.s.sol --rpc-url $LISK_TESTNET_RPC
```

**Execute on testnet:**
```bash
forge script script/UpgradeDiamondWithInit.s.sol \
  --rpc-url $LISK_TESTNET_RPC \
  --broadcast \
  --verify
```

**Execute on mainnet:**
```bash
forge script script/UpgradeDiamondWithInit.s.sol \
  --rpc-url $MAINNET_RPC \
  --broadcast \
  --verify \
  --slow
```

## Post-Upgrade Configuration

### Initialize MultiSig (Optional)

If you want to use the multi-sig functionality:

```solidity
// Add signatories
diamond.addSignatory(signer1);
diamond.addSignatory(signer2);
diamond.addSignatory(signer3);

// Set threshold (e.g., 2 out of 3)
diamond.setThreshold(2);
```

### Configure Swap Settings

```solidity
// Update exchange rate if needed
diamond.setExchangeRate(2000e18); // 2000 tokens per ETH

// Pause/unpause swapping
diamond.setSwapPaused(false);
```

## New Functions Available

### SwapFacet Functions

```solidity
// User functions
swapEthForTokens() payable - Swap ETH for tokens
calculateTokensForEth(uint256 ethAmount) view - Calculate token amount
getExchangeRate() view - Get current exchange rate
isSwapPaused() view - Check if swapping is paused
getTotalEthReceived() view - Get total ETH received

// Owner functions
setExchangeRate(uint256 rate) - Set exchange rate
setSwapPaused(bool paused) - Pause/unpause swapping
withdrawEth() - Withdraw accumulated ETH
```

### MultiSigFacet Functions

```solidity
// Owner functions
addSignatory(address signatory) - Add a signatory
removeSignatory(address signatory) - Remove a signatory
setThreshold(uint256 threshold) - Set confirmation threshold

// Signatory functions
submitTransaction(address to, uint256 value, bytes data) - Submit transaction
confirmTransaction(uint256 txId) - Confirm a transaction
revokeConfirmation(uint256 txId) - Revoke confirmation
executeTransaction(uint256 txId) - Execute transaction (if threshold met)

// View functions
getSignatories() view - Get all signatories
getThreshold() view - Get current threshold
isSigner(address account) view - Check if address is signer
getTransaction(uint256 txId) view - Get transaction details
getTransactionCount() view - Get total transaction count
hasConfirmed(uint256 txId, address signer) view - Check confirmation status
```

### ERC20MetadataFacet Functions

```solidity
tokenURI() view - Get token metadata JSON with embedded SVG logo
getTokenName() view - Get token name
getTokenSymbol() view - Get token symbol
```

## Security Features

### SwapFacet
- ✅ Reentrancy protection on `swapEthForTokens()` and `withdrawEth()`
- ✅ Safe math (Solidity 0.8+ overflow protection)
- ✅ Owner-only admin functions
- ✅ Pausable swapping mechanism
- ✅ Zero-value checks

### MultiSigFacet
- ✅ Threshold-based execution
- ✅ Confirmation tracking per transaction
- ✅ Owner-only signatory management
- ✅ Signatory-only transaction operations
- ✅ Execute-once protection

### Storage Isolation
- ✅ Each facet uses separate Diamond Storage slots
- ✅ No storage collisions between facets
- ✅ Follows EIP-2535 Diamond Storage pattern

## Example Usage

### Swapping ETH for Tokens

```solidity
// User sends 1 ETH to get tokens
diamond.swapEthForTokens{value: 1 ether}();

// Check balance
uint256 balance = diamond.balanceOf(msg.sender);
```

### Multi-Sig Transaction

```solidity
// 1. Submit transaction (by any signer)
uint256 txId = diamond.submitTransaction(recipient, 1 ether, "");

// 2. Confirm by required signers
diamond.confirmTransaction(txId); // Signer 1
diamond.confirmTransaction(txId); // Signer 2

// 3. Execute (by any signer, once threshold met)
diamond.executeTransaction(txId);
```

### Getting Token Metadata

```solidity
// Get full metadata JSON with embedded SVG
string memory metadata = diamond.tokenURI();

// Metadata includes:
// - Token name and description
// - Base64-encoded SVG logo
// - Token attributes (type, standard, symbol, decimals)
```

## Verification

After upgrade, verify the changes:

```bash
# Check that mint function is removed
cast call $DIAMOND_ADDRESS "mint(address,uint256)" $USER 1000 --rpc-url $RPC_URL
# Should fail with "function not found"

# Check SwapFacet is added
cast call $DIAMOND_ADDRESS "getExchangeRate()" --rpc-url $RPC_URL

# Check MultiSigFacet is added
cast call $DIAMOND_ADDRESS "getThreshold()" --rpc-url $RPC_URL

# Check MetadataFacet is added
cast call $DIAMOND_ADDRESS "tokenURI()" --rpc-url $RPC_URL
```

## Rollback (Emergency)

If you need to rollback, you can use `diamondCut` to:
1. Remove the new facet selectors
2. Re-add the mint function if needed

```solidity
// Example: Remove SwapFacet
IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
cuts[0] = IDiamondCut.FacetCut({
    facetAddress: address(0),
    action: IDiamondCut.FacetCutAction.Remove,
    functionSelectors: swapSelectors
});
diamond.diamondCut(cuts, address(0), "");
```

## Gas Estimates

Approximate gas costs (may vary):

- Upgrade transaction: ~3-5M gas
- swapEthForTokens(): ~100-150k gas
- submitTransaction(): ~150-200k gas
- confirmTransaction(): ~50-80k gas
- executeTransaction(): ~80-120k gas + target call cost
- tokenURI(): View function (no gas)

## Support

For issues or questions:
1. Check the test file `test/DiamondUpgrade.t.sol` for examples
2. Review the Diamond Standard (EIP-2535) documentation
3. Verify all storage libraries use unique storage positions

## License

MIT
