# NerveCore Smart Contracts

Move contracts for the NerveCore DeFi gaming platform on Sui blockchain.

## Overview

NerveCore provides three core DeFi primitives designed for gamified learning:

1. **Token Faucet** - Mock tokens (MSUI, MUSDC) for testing with cooldown mechanics
2. **Lending Protocol** - Collateralized lending with 80% LTV
3. **Swap DEX** - Constant product AMM with 0.3% fees

All contracts are built using the Move programming language for the Sui blockchain.

## Contract Architecture

### Module: `nervecore::faucet`

Creates and manages two mock tokens with faucet functionality:

- **MSUI (Mock SUI)** - 9 decimals, 1000 tokens per claim
- **MUSDC (Mock USDC)** - 9 decimals, 1000 tokens per claim

**Features:**
- 1-hour cooldown between claims per token type
- Separate cooldown tracking for MSUI and MUSDC
- Admin mint capability for pool initialization
- Events for all faucet claims

**Key Functions:**
- `faucet_msui()` - Claim 1000 MSUI (1 hour cooldown)
- `faucet_musdc()` - Claim 1000 MUSDC (1 hour cooldown)
- `can_claim_msui()` - Check if address can claim MSUI
- `get_cooldown_remaining_msui()` - Get remaining cooldown time

### Module: `nervecore::lending`

Over-collateralized lending protocol with NFT receipts:

**Features:**
- Deposit MSUI as collateral, receive LendingReceipt NFT
- Borrow MUSDC up to 80% of collateral value (LTV)
- 5% APY (display only, not enforced)
- Must repay all debt before withdrawing collateral

**Key Functions:**
- `deposit()` - Deposit MSUI, get receipt NFT
- `borrow()` - Borrow MUSDC against collateral (max 80% LTV)
- `repay()` - Repay borrowed MUSDC
- `withdraw()` - Withdraw collateral (requires zero debt)
- View functions for pool stats and receipt info

### Module: `nervecore::swap`

Constant product AMM (Uniswap v2 style):

**Features:**
- MSUI/MUSDC liquidity pool
- 0.3% swap fee (30 basis points)
- LP tokens as NFT receipts
- Price calculation and quotes

**Key Functions:**
- `init_pool()` - Initialize pool with liquidity (one-time)
- `swap_msui_to_musdc()` - Swap MSUI for MUSDC
- `swap_musdc_to_msui()` - Swap MUSDC for MSUI
- `add_liquidity()` - Provide liquidity, get LP receipt
- `remove_liquidity()` - Burn LP receipt, get tokens back
- `get_quote_*()` - Get swap price quotes
- `get_msui_price()` - Get current MSUI price in MUSDC

## Prerequisites

Before deploying, you need:

1. **Sui CLI** - For building and deploying contracts
2. **Sui Wallet** - With testnet SUI for gas fees
3. **Node.js** - For post-deployment scripts

### Install Sui CLI

**macOS (Homebrew):**
```bash
brew install sui
```

**Ubuntu/Linux:**
```bash
curl -LO https://github.com/MystenLabs/sui/releases/download/testnet/sui-testnet-ubuntu-x86_64.tgz
tar -xzf sui-testnet-ubuntu-x86_64.tgz
chmod +x sui
sudo mv sui /usr/local/bin/
```

**Windows:**
Download from [Sui Releases](https://github.com/MystenLabs/sui/releases) or use WSL2.

**Or use our setup script:**
```bash
cd contracts/scripts
./setup-env.sh
```

## Quick Start

### 1. Setup Environment

```bash
# Run the setup script (installs Sui CLI, creates wallet)
cd contracts/scripts
./setup-env.sh

# Get testnet SUI from faucet
# Visit: https://faucet.testnet.sui.io/
# Or use curl:
sui client active-address  # Copy this address
curl --location --request POST 'https://faucet.testnet.sui.io/gas' \
  --header 'Content-Type: application/json' \
  --data-raw '{"FixedAmountRequest":{"recipient":"YOUR_ADDRESS"}}'
```

### 2. Build Contracts

```bash
cd contracts/nervecore
sui move build
```

### 3. Run Tests (Optional)

```bash
sui move test
```

### 4. Deploy to Testnet

```bash
# From contracts/nervecore directory
../scripts/deploy.sh
```

This will:
- Build the contracts
- Publish to Sui testnet
- Output Package ID and shared object IDs
- Save deployment info to a timestamped JSON file

### 5. Initialize Pools

```bash
cd ../scripts
npm install
npm run init
```

This post-deployment script will:
- Claim initial tokens from faucet
- Initialize swap pool with liquidity
- Output all contract addresses

### 6. Update Frontend Environment

Copy the contract addresses from the deployment output and add them to `frontend/.env`:

```bash
cd ../../frontend
cp .env.example .env
# Edit .env and paste the contract addresses
```

## Deployment Output

After successful deployment, you'll see:

```
Package ID: 0xabcd1234...
Shared Objects Created:
  nervecore::faucet::MSUITreasury: 0x1111...
  nervecore::faucet::MUSDCTreasury: 0x2222...
  nervecore::faucet::ClaimRegistry: 0x3333...
  nervecore::lending::LendingPool: 0x4444...
```

After initialization:

```
NEXT_PUBLIC_PACKAGE_ID=0xabcd1234...
NEXT_PUBLIC_MSUI_TREASURY=0x1111...
NEXT_PUBLIC_MUSDC_TREASURY=0x2222...
NEXT_PUBLIC_CLAIM_REGISTRY=0x3333...
NEXT_PUBLIC_LENDING_POOL=0x4444...
NEXT_PUBLIC_SWAP_POOL=0x5555...
```

## Testing Contracts

### Run Unit Tests

```bash
cd contracts/nervecore
sui move test
```

### Manual Testing via CLI

**Claim tokens from faucet:**
```bash
sui client call \
  --package $PACKAGE_ID \
  --module faucet \
  --function faucet_msui \
  --args $MSUI_TREASURY $CLAIM_REGISTRY 0x6 \
  --gas-budget 10000000
```

**Deposit to lending pool:**
```bash
sui client call \
  --package $PACKAGE_ID \
  --module lending \
  --function deposit \
  --args $LENDING_POOL $MSUI_COIN_ID 0x6 \
  --gas-budget 10000000
```

**Swap MSUI for MUSDC:**
```bash
sui client call \
  --package $PACKAGE_ID \
  --module swap \
  --function swap_msui_to_musdc_entry \
  --args $SWAP_POOL $MSUI_COIN_ID 1000000000 \
  --gas-budget 10000000
```

## Project Structure

```
contracts/
├── nervecore/
│   ├── Move.toml              # Package manifest
│   ├── sources/
│   │   ├── faucet.move        # Token faucet module
│   │   ├── lending.move       # Lending protocol module
│   │   └── swap.move          # Swap DEX module
│   └── tests/                 # Unit tests (if any)
└── scripts/
    ├── deploy.sh              # Main deployment script
    ├── setup-env.sh           # Environment setup script
    ├── init-pools.js          # Post-deployment initialization
    └── package.json           # Node.js dependencies
```

## Common Issues

### Issue: "Error: No active Sui address found"

**Solution:** Create a new wallet address:
```bash
sui client new-address ed25519
```

### Issue: "Error: Insufficient gas"

**Solution:** Get testnet SUI from the faucet:
```bash
# Visit https://faucet.testnet.sui.io/ or use curl
curl --location --request POST 'https://faucet.testnet.sui.io/gas' \
  --header 'Content-Type: application/json' \
  --data-raw '{"FixedAmountRequest":{"recipient":"YOUR_ADDRESS"}}'
```

### Issue: "Error: Package already published at address 0x0"

**Solution:** Update the `nervecore` address in `Move.toml`:
```toml
[addresses]
nervecore = "0x0"  # Sui will assign this during publish
```

### Issue: Faucet cooldown error

**Solution:** Wait 1 hour between claims, or use `admin_mint_*` functions for testing (requires AdminCap).

## Useful Commands

```bash
# Check your active address
sui client active-address

# List your gas coins
sui client gas

# Check your objects
sui client objects

# Switch to testnet
sui client switch --env testnet

# View transaction details
sui client tx-block $TX_DIGEST

# Query object details
sui client object $OBJECT_ID
```

## Constants Reference

| Constant | Value | Description |
|----------|-------|-------------|
| TOKEN_DECIMALS | 9 | Decimals for MSUI and MUSDC |
| CLAIM_AMOUNT | 1,000,000,000,000 | 1000 tokens (with 9 decimals) |
| COOLDOWN_MS | 3,600,000 | 1 hour in milliseconds |
| LTV_PERCENT | 80 | Max borrow is 80% of collateral |
| SWAP_FEE_BPS | 30 | 0.3% swap fee |

## Security Considerations

These contracts are for **testnet and educational purposes only**:

- ⚠️ Mock tokens have unlimited supply via faucet
- ⚠️ No price oracles - fixed 1:1 pricing assumed
- ⚠️ No liquidation mechanism
- ⚠️ No interest accrual (APY is display-only)
- ⚠️ Admin functions bypass security checks

**Do NOT use in production without:**
- Full security audit
- Proper price oracles
- Liquidation mechanisms
- Interest rate models
- Access control hardening

## Resources

- [Sui Documentation](https://docs.sui.io/)
- [Move Language Book](https://move-language.github.io/move/)
- [Sui Move by Example](https://examples.sui.io/)
- [Sui Testnet Faucet](https://faucet.testnet.sui.io/)
- [Sui Explorer](https://suiexplorer.com/)

## Support

For issues or questions:
1. Check the [Sui Discord](https://discord.gg/sui)
2. Review [Sui GitHub Issues](https://github.com/MystenLabs/sui/issues)
3. Consult the [Move documentation](https://move-language.github.io/move/)

## License

MIT License - see LICENSE file for details
