# Diamond Architecture - After Upgrade

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Diamond Proxy                           │
│                   (Deployed Contract)                        │
│                                                              │
│  Fallback: Routes function calls to appropriate facets      │
│  Receive: Accepts ETH for swap functionality                │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ delegatecall
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
┌───────────────┐    ┌───────────────┐
│ Core Facets   │    │  New Facets   │
└───────────────┘    └───────────────┘
```

## Facet Architecture

```
Diamond Contract
│
├── Core Facets (Existing)
│   ├── DiamondCutFacet      → diamondCut()
│   ├── DiamondLoupeFacet    → facets(), facetAddresses()
│   ├── ERC20Facet           → transfer(), balanceOf(), etc.
│   └── OwnershipFacet       → owner(), transferOwnership()
│
└── New Facets (Added in Upgrade)
    ├── SwapFacet            → swapEthForTokens(), setExchangeRate()
    ├── MultiSigFacet        → submitTransaction(), confirmTransaction()
    └── ERC20MetadataFacet   → tokenURI()
```

## Storage Layout

```
┌─────────────────────────────────────────────────────────┐
│                    Diamond Storage                       │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │ LibDiamond Storage                             │    │
│  │ Position: keccak256("diamond.standard...")     │    │
│  │ - selectorToFacet mapping                      │    │
│  │ - facetToSelectors mapping                     │    │
│  │ - facetAddresses array                         │    │
│  │ - contractOwner                                │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │ LibERC20Storage                                │    │
│  │ Position: keccak256("diamond.standard.erc20")  │    │
│  │ - name, symbol, decimals                       │    │
│  │ - totalSupply                                  │    │
│  │ - balances mapping                             │    │
│  │ - allowances mapping                           │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │ LibSwapStorage (NEW)                           │    │
│  │ Position: keccak256("diamond.standard.swap")   │    │
│  │ - exchangeRate                                 │    │
│  │ - paused                                       │    │
│  │ - totalEthReceived                             │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │ LibMultiSigStorage (NEW)                       │    │
│  │ Position: keccak256("diamond.standard.multisig")│   │
│  │ - signatories array                            │    │
│  │ - isSigner mapping                             │    │
│  │ - threshold                                    │    │
│  │ - transactions array                           │    │
│  │ - confirmations mapping                        │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Function Selector Routing

```
User calls Diamond.swapEthForTokens()
         │
         ▼
Diamond fallback() receives call
         │
         ▼
Look up msg.sig in selectorToFacet mapping
         │
         ▼
Found: SwapFacet address
         │
         ▼
delegatecall to SwapFacet.swapEthForTokens()
         │
         ▼
SwapFacet executes using Diamond's storage
         │
         ▼
Return result to user
```

## Upgrade Process Flow

```
1. Deploy New Facets
   ├── SwapFacet.sol
   ├── MultiSigFacet.sol
   └── ERC20MetadataFacet.sol

2. Deploy Init Contracts (optional)
   ├── SwapFacetInit.sol
   └── MultiSigFacetInit.sol

3. Prepare FacetCut Array
   ├── Remove: mint() selector
   ├── Add: SwapFacet selectors
   ├── Add: MultiSigFacet selectors
   └── Add: MetadataFacet selectors

4. Execute diamondCut()
   ├── Remove old selectors
   ├── Add new selectors
   ├── Update selectorToFacet mapping
   └── Call init function (if provided)

5. Verify Upgrade
   ├── Test removed functions (should fail)
   └── Test new functions (should work)
```

## Data Flow - Swap Example

```
User (1 ETH)
     │
     ▼
Diamond.swapEthForTokens{value: 1 ETH}()
     │
     ▼
SwapFacet (via delegatecall)
     │
     ├─→ Check: msg.value > 0 ✓
     ├─→ Check: not paused ✓
     ├─→ Check: exchangeRate set ✓
     │
     ├─→ Calculate: tokens = (1 ETH * 1000e18) / 1e18 = 1000 tokens
     │
     ├─→ Update LibERC20Storage:
     │   ├── totalSupply += 1000
     │   └── balances[user] += 1000
     │
     ├─→ Update LibSwapStorage:
     │   └── totalEthReceived += 1 ETH
     │
     └─→ Emit: Transfer(0x0, user, 1000)
             TokensSwapped(user, 1 ETH, 1000)
```

## Data Flow - MultiSig Example

```
Signer1: Submit Transaction
     │
     ▼
MultiSigFacet.submitTransaction(recipient, 1 ETH, data)
     │
     ├─→ Check: msg.sender is signer ✓
     ├─→ Create transaction in storage
     ├─→ txId = transactions.length
     └─→ Emit: TransactionSubmitted(txId, ...)

Signer1 & Signer2: Confirm
     │
     ▼
MultiSigFacet.confirmTransaction(txId)
     │
     ├─→ Check: not already confirmed ✓
     ├─→ confirmations[txId][signer] = true
     ├─→ transactions[txId].confirmations++
     └─→ Emit: TransactionConfirmed(txId, signer)

Signer1: Execute (after threshold met)
     │
     ▼
MultiSigFacet.executeTransaction(txId)
     │
     ├─→ Check: confirmations >= threshold ✓
     ├─→ Mark as executed
     ├─→ Execute: recipient.call{value: 1 ETH}(data)
     └─→ Emit: TransactionExecuted(txId)
```

## Security Model

```
┌─────────────────────────────────────────┐
│         Access Control Layers           │
├─────────────────────────────────────────┤
│                                         │
│  Owner Only:                            │
│  ├── diamondCut()                       │
│  ├── setExchangeRate()                  │
│  ├── setSwapPaused()                    │
│  ├── withdrawEth()                      │
│  ├── addSignatory()                     │
│  ├── removeSignatory()                  │
│  └── setThreshold()                     │
│                                         │
│  Signer Only:                           │
│  ├── submitTransaction()                │
│  ├── confirmTransaction()               │
│  ├── revokeConfirmation()               │
│  └── executeTransaction()               │
│                                         │
│  Public:                                │
│  ├── swapEthForTokens()                 │
│  ├── transfer()                         │
│  ├── tokenURI()                         │
│  └── view functions                     │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Protection Mechanisms           │
├─────────────────────────────────────────┤
│                                         │
│  ✓ Reentrancy Guards                    │
│    - swapEthForTokens()                 │
│    - withdrawEth()                      │
│                                         │
│  ✓ Threshold Checks                     │
│    - executeTransaction()               │
│                                         │
│  ✓ State Validation                     │
│    - Transaction not executed           │
│    - Not already confirmed              │
│    - Sufficient confirmations           │
│                                         │
│  ✓ Input Validation                     │
│    - Zero address checks                │
│    - Zero value checks                  │
│    - Threshold <= signatories           │
│                                         │
└─────────────────────────────────────────┘
```

## Upgrade vs Redeploy Comparison

```
Traditional Redeploy:
├── Deploy new contract
├── Migrate all data (expensive!)
├── Update all integrations
├── Lose transaction history
└── Change contract address

Diamond Upgrade (This Approach):
├── Deploy only new facets
├── No data migration needed
├── No integration updates
├── Keep transaction history
└── Same contract address ✓
```

## Gas Optimization

```
Storage Access Pattern:
├── Direct storage slot access (assembly)
├── No SLOAD/SSTORE overhead from inheritance
└── Efficient storage packing

Function Routing:
├── O(1) selector lookup
├── Single delegatecall per function
└── No proxy hop overhead

Batch Operations:
├── diamondCut supports multiple facets
├── Single transaction for full upgrade
└── Reduced deployment costs
```

## Integration Points

```
External Systems
     │
     ├─→ Web3 Frontend
     │   ├── Call: swapEthForTokens()
     │   ├── Call: tokenURI()
     │   └── Display: SVG logo
     │
     ├─→ Block Explorers
     │   ├── Verify: Facet contracts
     │   └── Display: Diamond functions
     │
     ├─→ Wallets
     │   ├── Show: Token balance
     │   ├── Show: Token metadata
     │   └── Enable: Token transfers
     │
     └─→ DEX/DeFi
         ├── List: Token for trading
         └── Use: Standard ERC20 interface
```

## Maintenance & Upgrades

```
Future Upgrades:
├── Add new facets (Add action)
├── Replace existing facets (Replace action)
├── Remove facets (Remove action)
└── All without changing Diamond address

Monitoring:
├── Track: getTotalEthReceived()
├── Track: getTransactionCount()
├── Monitor: Events (TokensSwapped, TransactionExecuted)
└── Alert: Failed transactions

Governance:
├── Owner controls administrative functions
├── Multi-sig controls critical operations
└── Threshold ensures distributed control
```

---

**Architecture Benefits:**
- ✅ Modular design (easy to extend)
- ✅ Storage isolation (no collisions)
- ✅ Gas efficient (direct storage access)
- ✅ Upgradeable (without redeployment)
- ✅ Secure (multiple protection layers)
