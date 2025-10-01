# Deployment Guide for ERC-20 Diamond

## Prerequisites

1. **Get Testnet ETH**: Visit https://sepolia-faucet.lisk.com/
2. **Export your private key** from MetaMask or your wallet

## Step-by-Step Deployment

### 1. Setup Environment

```bash
# Copy the example env file
cp .env.example .env

# Edit .env and add your private key
nano .env
```

Add your private key (without 0x prefix):
```
PRIVATE_KEY=your_actual_private_key_here
LISK_TESTNET_RPC=https://rpc.sepolia-api.lisk.com
```

### 2. Deploy the Contract

```bash
# Load environment variables
source .env

# Deploy to Lisk Sepolia testnet
forge script script/DeployDiamond.s.sol:DeployDiamond \
  --rpc-url $LISK_TESTNET_RPC \
  --broadcast \
  -vvvv
```

**Save the output!** You'll see addresses like:
```
Diamond: 0x1234...
CutFacet: 0x5678...
ERC20Facet: 0x9abc...
```

### 3. Verify on Block Explorer

Visit the block explorer:
```
https://sepolia-blockscout.lisk.com/address/YOUR_DIAMOND_ADDRESS
```

The contract should automatically appear. If you want to verify the source code:

```bash
# Verify Diamond contract
forge verify-contract YOUR_DIAMOND_ADDRESS \
  src/contracts/Diamond.sol:Diamond \
  --chain-id 4202 \
  --rpc-url $LISK_TESTNET_RPC \
  --constructor-args $(cast abi-encode "constructor(address,address)" YOUR_DEPLOYER_ADDRESS YOUR_CUT_FACET_ADDRESS)
```

### 4. Test Your Deployment

#### Check token info:
```bash
# Get name
cast call YOUR_DIAMOND_ADDRESS "name()(string)" --rpc-url $LISK_TESTNET_RPC

# Get symbol
cast call YOUR_DIAMOND_ADDRESS "symbol()(string)" --rpc-url $LISK_TESTNET_RPC

# Get total supply
cast call YOUR_DIAMOND_ADDRESS "totalSupply()(uint256)" --rpc-url $LISK_TESTNET_RPC
```

#### Mint tokens:
```bash
# Mint 1000 tokens to yourself
cast send YOUR_DIAMOND_ADDRESS \
  "mint(address,uint256)" \
  YOUR_ADDRESS \
  1000000000000000000000 \
  --rpc-url $LISK_TESTNET_RPC \
  --private-key $PRIVATE_KEY
```

#### Check balance:
```bash
cast call YOUR_DIAMOND_ADDRESS \
  "balanceOf(address)(uint256)" \
  YOUR_ADDRESS \
  --rpc-url $LISK_TESTNET_RPC
```

## Common Issues

### "Insufficient funds"
- Get testnet ETH from: https://sepolia-faucet.lisk.com/

### "Invalid private key"
- Make sure you removed the `0x` prefix from your private key in `.env`

### Deployment fails
- Check you have enough testnet ETH
- Verify RPC URL is correct
- Try adding `--legacy` flag if gas estimation fails

## Quick Commands Reference

```bash
# Deploy
forge script script/DeployDiamond.s.sol:DeployDiamond --rpc-url $LISK_TESTNET_RPC --broadcast

# Mint tokens
cast send <DIAMOND_ADDR> "mint(address,uint256)" <YOUR_ADDR> 1000000000000000000000 --rpc-url $LISK_TESTNET_RPC --private-key $PRIVATE_KEY

# Check balance
cast call <DIAMOND_ADDR> "balanceOf(address)(uint256)" <YOUR_ADDR> --rpc-url $LISK_TESTNET_RPC

# Transfer tokens
cast send <DIAMOND_ADDR> "transfer(address,uint256)" <RECIPIENT> 100000000000000000000 --rpc-url $LISK_TESTNET_RPC --private-key $PRIVATE_KEY
```

## Block Explorer

View your contract at:
- **Lisk Sepolia**: https://sepolia-blockscout.lisk.com/address/YOUR_DIAMOND_ADDRESS

You can interact with the contract directly through the block explorer's "Write Contract" tab.
