# Quick Start - Diamond Upgrade

## TL;DR

This upgrade adds three powerful features to your ERC-20 Diamond:
1. **ETH → Token Swap** (removes public mint)
2. **Multi-Signature Wallet**
3. **Onchain Metadata with SVG Logo**

## Quick Deploy

```bash
# 1. Set your Diamond address in the script
# Edit: script/UpgradeDiamondWithInit.s.sol
# Line 22: address constant DIAMOND_ADDRESS = 0xYourAddress;

# 2. Run the upgrade
forge script script/UpgradeDiamondWithInit.s.sol \
  --rpc-url $LISK_TESTNET_RPC \
  --broadcast \
  --verify

# 3. Done! Your Diamond now has all three new facets.
```

## What Changed?

### ❌ Removed
- `mint(address to, uint256 amount)` - Public minting removed for security

### ✅ Added

**SwapFacet** - Buy tokens with ETH
```solidity
// Users can now buy tokens directly
diamond.swapEthForTokens{value: 1 ether}();

// Owner can set exchange rate
diamond.setExchangeRate(1000e18); // 1000 tokens per ETH
```

**MultiSigFacet** - Multi-signature governance
```solidity
// Setup signers
diamond.addSignatory(signer1);
diamond.addSignatory(signer2);
diamond.setThreshold(2); // 2 of 2 required

// Submit and execute transactions
uint256 txId = diamond.submitTransaction(recipient, 1 ether, "");
diamond.confirmTransaction(txId); // Signer 1
diamond.confirmTransaction(txId); // Signer 2
diamond.executeTransaction(txId); // Execute when threshold met
```

**ERC20MetadataFacet** - Onchain metadata
```solidity
// Get full metadata JSON with embedded SVG logo
string memory metadata = diamond.tokenURI();
// Returns: {"name":"...","image":"data:image/svg+xml;base64,..."}
```

## Test First (Recommended)

```bash
forge test --match-contract DiamondUpgradeTest -vv
```

All 5 tests should pass:
- ✅ testUpgradeDiamond
- ✅ testSwapFacet
- ✅ testMultiSigFacet
- ✅ testMetadataFacet
- ✅ testCompleteWorkflow

## Files Created

```
src/contracts/
├── facets/
│   ├── SwapFacet.sol              # ETH to token swaps
│   ├── MultiSigFacet.sol          # Multi-sig wallet
│   ├── ERC20MetadataFacet.sol     # Onchain metadata
│   ├── SwapFacetInit.sol          # Swap initialization
│   └── MultiSigFacetInit.sol      # MultiSig initialization
└── libraries/
    ├── LibSwapStorage.sol         # Swap storage
    └── LibMultiSigStorage.sol     # MultiSig storage

script/
├── UpgradeDiamond.s.sol           # Basic upgrade
└── UpgradeDiamondWithInit.s.sol   # Upgrade with init

test/
└── DiamondUpgrade.t.sol           # Comprehensive tests
```

## Security Features

- ✅ Reentrancy protection (SwapFacet)
- ✅ Owner-only admin functions
- ✅ Threshold-based execution (MultiSig)
- ✅ Separate Diamond Storage (no collisions)
- ✅ Safe math (Solidity 0.8+)
- ✅ Pausable swapping

## Next Steps

1. **Configure Swap Rate**
   ```solidity
   diamond.setExchangeRate(1000e18); // Set your rate
   ```

2. **Setup Multi-Sig** (Optional)
   ```solidity
   diamond.addSignatory(signer1);
   diamond.addSignatory(signer2);
   diamond.setThreshold(2);
   ```

3. **Test Swap**
   ```solidity
   diamond.swapEthForTokens{value: 0.1 ether}();
   ```

4. **View Metadata**
   ```solidity
   string memory uri = diamond.tokenURI();
   ```

## Need Help?

- 📖 Full guide: `UPGRADE_GUIDE.md`
- 🧪 Test examples: `test/DiamondUpgrade.t.sol`
- 🔍 Diamond Standard: [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535)

## Verification Commands

```bash
# Verify mint is removed (should fail)
cast call $DIAMOND "mint(address,uint256)" $USER 1000 --rpc-url $RPC

# Verify SwapFacet added
cast call $DIAMOND "getExchangeRate()" --rpc-url $RPC

# Verify MultiSigFacet added
cast call $DIAMOND "getThreshold()" --rpc-url $RPC

# Verify MetadataFacet added
cast call $DIAMOND "tokenURI()" --rpc-url $RPC
```

## Gas Costs

- Upgrade: ~3-5M gas
- Swap: ~100-150k gas
- Multi-sig submit: ~150-200k gas
- Multi-sig confirm: ~50-80k gas
- Multi-sig execute: ~80-120k gas

---

**Ready to upgrade?** Follow the steps above or see `UPGRADE_GUIDE.md` for detailed instructions.
