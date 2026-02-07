# Nerve Package - Comprehensive DeFi Contracts on Sui

![Nerve Logo](https://img.shields.io/badge/Sui-DeFi-blue)
![License](https://img.shields.io/badge/License-Educational-green)
![Status](https://img.shields.io/badge/Status-Testnet-yellow)

Nerve is a comprehensive Move package that implements DeFi primitives for the Sui blockchain platform. This package is designed for educational and testing purposes, featuring three main modules: **Faucet** for mock token distribution, **Lending** for loans with over-collateralization, and **Swap** for automated market maker (AMM).

## 📋 Table of Contents

- [Features](#features)
- [System Requirements](#system-requirements)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [API Documentation](#api-documentation)
- [Configuration](#configuration)
- [Unit Testing](#unit-testing)
- [Deployment](#deployment)
- [Usage Examples](#usage-examples)
- [Security Notes](#security-notes)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## 🚀 Features

### 1. **Faucet Module** (`faucet.move`)
The faucet module provides a mechanism to distribute mock tokens to users with a cooldown system.

**Features:**
- Distribution of MSUI and MUSDC tokens with per-address cooldown
- Admin mint function for unlimited token generation
- Timestamp checking to prevent duplicate claims
- Gas-efficient design

**Supported Tokens:**
- MSUI (Mock SUI) - 9 decimal places
- MUSDC (Mock USDC) - 9 decimal places

### 2. **Lending Module** (`lending.move`)
Over-collateralized lending system with NFT receipts for position tracking.

**Features:**
- Deposit collateral and borrow against collateral
- Over-collateralization with 80% LTV
- NFT Receipt for tracking and withdraw
- Repay with interest calculation
- Withdraw collateral after repay

**Security Features:**
- LTV validation before borrowing
- NFT receipt as proof-of-ownership
- Balance tracking for each user

### 3. **Swap Module** (`swap.move`)
Automated Market Maker (AMM) with constant-product formula (Uniswap v2 style).

**Features:**
- Create trading pools with two tokens
- Add and remove liquidity with LP receipts
- Swap with 0.3% fee (30 basis points)
- Price calculation based on constant-product formula
- Multi-hop swap support

**Formula:**
- `x * y = k` (constant product)
- Optimal swap with slippage protection

---

## 💻 System Requirements

### Software Requirements
- **Sui CLI** (latest version)
  - For build, test, and deployment
  - Download: https://docs.sui.io/guides/developer/getting-started/sui-install
- **Move Language Support**
  - Included with Sui CLI
- **Node.js** (v16 or newer) - optional
  - Only if using automation scripts

### Hardware Requirements
- Minimum 4GB RAM
- 500MB disk space for build artifacts
- Internet connection for downloading dependencies

### Wallet Requirements
- Sui wallet account with test SUI
- Minimum 0.5 SUI for gas fees
- Testnet or devnet configured

---

## 📁 Project Structure

```
nerve/
├── Move.toml                          # Package manifest and configuration
├── README.md                          # This documentation
├── Cargo.toml                         # Rust dependencies (if any scripts)
├── sources/                           # Move source code
│   ├── faucet.move                   # Faucet module
│   ├── lending.move                  # Lending module
│   ├── swap.move                     # Swap/AMM module
│   ├── msui.move                     # Mock SUI token
│   ├── musdc.move                    # Mock USDC token
│   └── dependencies/                 # External dependencies
│       ├── MoveStdlib/              # Standard library
│       └── Sui/                      # Sui framework
├── build/                             # Compiled artifacts (generated)
│   └── nerve/
│       ├── bytecode_modules/         # Compiled .mv files
│       ├── debug_info/               # Debug information
│       └── sources/                  # Source mirrors
├── tests/                             # Unit tests
│   └── nerve_tests.move              # Test file
└── Published.toml                    # Published package info
```

### File Descriptions

| File | Description |
|------|-------------|
| `Move.toml` | Package manifest defining dependencies and addresses |
| `sources/faucet.move` | Faucet implementation with cooldown mechanism |
| `sources/lending.move` | Lending protocol with over-collateralization |
| `sources/swap.move` | AMM with constant-product formula |
| `sources/msui.move` | Token definition for Mock SUI |
| `sources/musdc.move` | Token definition for Mock USDC |
| `tests/nerve_tests.move` | Comprehensive unit tests for all modules |

---

## 🔧 Installation

### Step 1: Clone Repository
```bash
git clone <repository-url>
cd nerve
```

### Step 2: Install Sui CLI (if not already installed)
```bash
# Linux/Mac
curl -fsSL https://github.com/MystenLabs/sui/releases/download/testnet-v1.X.X/sui-testnet-v1.X.X-ubuntu-x86_64 -o sui
chmod +x sui
sudo mv sui /usr/local/bin/

# Verify installation
sui --version
```

### Step 3: Configure Sui CLI
```bash
# Create new default wallet
sui client new default

# Or switch to existing wallet
sui client switch --address <your-address>

# Verify network
sui client envs
```

### Step 4: Download Dependencies
```bash
cd nerve
sui move build
```

**Expected output:**
```
Building Modules...
Compiling dependency "MoveStdlib"
Compiling dependency "Sui" 
Compiling module "nerve"
Build successful!
```

---

## ⚡ Quickstart

### Option 1: Local Build (Fast)
```bash
# Build package
sui move build

# Expected output:
# Compiled successfully at: ./build/nerve/
```

### Option 2: Run Unit Tests
```bash
# Run all tests
sui move test

# Run with verbosity
sui move test -- --coverage

# Expected output:
# running 10 tests
# test faucet_tests ... ok
# test lending_tests ... ok
# test swap_tests ... ok
```

### Option 3: Deploy to Testnet
```bash
# Build first
sui move build

# Publish to testnet (interactive)
sui client publish --gas-budget 100000000

# Save Package ID from output:
# Package ID: 0x...
```

---

## 📚 API Documentation

### Faucet Module (`nervecore::faucet`)

#### `faucet_msui(ctx: &mut TxContext) -> Coin<MSUI>`
Claim Mock SUI token with 1-hour cooldown per address.

**Parameters:**
- `ctx` - Transaction context

**Returns:**
- `Coin<MSUI>` - 1.000 MSUI token (with 9 decimal)

**Cooldown:** 3.600.000 ms (1 hour)

**Example:**
```move
let coin = faucet::faucet_msui(&mut tx_context);
```

#### `faucet_musdc(ctx: &mut TxContext) -> Coin<MUSDC>`
Claim Mock USDC token with 1-hour cooldown per address.

**Parameters:**
- `ctx` - Transaction context

**Returns:**
- `Coin<MUSDC>` - 1.000 MUSDC token (with 9 decimal)

**Cooldown:** 3.600.000 ms (1 hour)

---

### Lending Module (`nervecore::lending`)

#### `deposit(coin: Coin<T>, pool: &mut Pool<T>, ctx: &mut TxContext)`
Deposit token as collateral to lending pool.

**Parameters:**
- `coin` - Token to be deposited
- `pool` - Mutable reference to lending pool
- `ctx` - Transaction context

**Preconditions:**
- Pool is already initialized
- Coin amount > 0

**Effects:**
- Increases user balance in pool
- Emit event for tracking

#### `borrow(amount: u64, collateral_amount: u64, pool: &mut Pool<T>, ctx: &mut TxContext) -> (Coin<T>, NFTReceipt)`
Borrow token with already-deposited collateral.

**Parameters:**
- `amount` - Amount of token to borrow
- `collateral_amount` - Amount of collateral to use
- `pool` - Mutable reference to lending pool
- `ctx` - Transaction context

**Returns:**
- `(Coin<T>, NFTReceipt)` - Borrowed coin and NFT receipt for tracking

**LTV Requirement:**
- LTV ≤ 80%
- Formula: `borrow_amount / collateral_value ≤ 0.8`

**Preconditions:**
- Collateral amount ≤ deposited balance
- New LTV ≤ 80%

#### `repay(mut receipt: NFTReceipt, coin: Coin<T>, pool: &mut Pool<T>, ctx: &mut TxContext)`
Repay loan with interest.

**Parameters:**
- `receipt` - NFT receipt from borrowing
- `coin` - Token for payment
- `pool` - Mutable reference to lending pool
- `ctx` - Transaction context

**Interest Calculation:**
- Simple interest: 5% per annum
- Duration: from borrow time until now

#### `withdraw(collateral_amount: u64, pool: &mut Pool<T>, ctx: &mut TxContext) -> Coin<T>`
Withdraw collateral after repaying loan.

**Parameters:**
- `collateral_amount` - Amount of collateral to withdraw
- `pool` - Mutable reference to lending pool
- `ctx` - Transaction context

**Returns:**
- `Coin<T>` - Withdrawn collateral

**Preconditions:**
- Must repay all loans
- Withdrawal amount ≤ available balance

---

### Swap Module (`nervecore::swap`)

#### `init_pool<X, Y>(pool_id: ID, x_amount: u64, y_amount: u64, ctx: &mut TxContext) -> (Coin<X>, Coin<Y>, LP<X, Y>)`
Initialize trading pool for X/Y pair.

**Parameters:**
- `pool_id` - Unique identifier for pool
- `x_amount` - Initial liquidity for token X
- `y_amount` - Initial liquidity for token Y
- `ctx` - Transaction context

**Returns:**
- Tuple containing LP receipt and remaining coins

**Preconditions:**
- Pool doesn't exist yet
- Amounts > 0
- Sufficient gas budget

#### `add_liquidity<X, Y>(pool: &mut Pool<X, Y>, coin_x: Coin<X>, coin_y: Coin<Y>, ctx: &mut TxContext) -> LP<X, Y>`
Add liquidity to existing pool.

**Parameters:**
- `pool` - Mutable reference to liquidity pool
- `coin_x` - Token X to add
- `coin_y` - Token Y to add
- `ctx` - Transaction context

**Returns:**
- `LP<X, Y>` - LP receipt for tracking share

**Formula:**
- Share calculation: `sqrt(amount_x * amount_y)`
- Proportion must match existing ratio

#### `remove_liquidity<X, Y>(pool: &mut Pool<X, Y>, lp: LP<X, Y>, ctx: &mut TxContext) -> (Coin<X>, Coin<Y>)`
Remove liquidity from pool and claim rewards.

**Parameters:**
- `pool` - Mutable reference to liquidity pool
- `lp` - LP receipt to burn
- `ctx` - Transaction context

**Returns:**
- Tuple containing claimed tokens X and Y

#### `swap_x_to_y<X, Y>(pool: &mut Pool<X, Y>, coin: Coin<X>, min_out: u64, ctx: &mut TxContext) -> Coin<Y>`
Swap token X to Y with slippage protection.

**Parameters:**
- `pool` - Mutable reference to liquidity pool
- `coin` - Token X to swap
- `min_out` - Minimum output for slippage protection
- `ctx` - Transaction context

**Returns:**
- `Coin<Y>` - Output token Y

**Fee:** 0.3% (30 basis points)

**Formula:**
```
output = (input * 997 * y_reserve) / (x_reserve * 1000 + input * 997)
```

#### `swap_y_to_x<X, Y>(pool: &mut Pool<X, Y>, coin: Coin<Y>, min_out: u64, ctx: &mut TxContext) -> Coin<X>`
Swap token Y to X with slippage protection.

**Parameters:**
- `pool` - Mutable reference to liquidity pool
- `coin` - Token Y to swap
- `min_out` - Minimum output for slippage protection
- `ctx` - Transaction context

**Returns:**
- `Coin<X>` - Output token X

---

## ⚙️ Configuration

### Constants

The following are main constants that can be configured:

```move
// Token Configuration
const TOKEN_DECIMALS: u8 = 9;               // Token precision (9 decimal)
const INITIAL_SUPPLY: u64 = 1_000_000;      // Initial token supply

// Faucet Configuration
const CLAIM_AMOUNT: u64 = 1_000_000_000;    // 1.000 MSUI/MUSDC (with decimals)
const COOLDOWN_MS: u64 = 3_600_000;         // 1 hour cooldown

// Lending Configuration
const LTV_PERCENT: u64 = 80;                // 80% LTV ratio
const INTEREST_RATE: u64 = 5;               // 5% annual interest

// Swap Configuration
const SWAP_FEE_BPS: u64 = 30;               // 30 basis points (0.3%)
const MIN_LIQUIDITY: u64 = 1_000;           // Minimum liquidity for pool
```

### Modifying Constants

To modify constants, edit the corresponding source file:

```bash
# Example: changing CLAIM_AMOUNT in faucet
vim sources/faucet.move

# Find constant and change value
const CLAIM_AMOUNT: u64 = 2_000_000_000;  // 2.000 MSUI

# Rebuild
sui move build
```

---

## 🧪 Unit Testing

### Running Tests

#### All Tests
```bash
sui move test
```

#### With Coverage Report
```bash
sui move test -- --coverage
```

#### Specific Module Test
```bash
sui move test -- --filter faucet
sui move test -- --filter lending
sui move test -- --filter swap
```

### Test Structure

Tests are located in `tests/nerve_tests.move` and include:

**Faucet Tests:**
- ✅ Multiple claims with cooldown validation
- ✅ Preventing duplicate claims within cooldown period
- ✅ Admin mint function

**Lending Tests:**
- ✅ Deposit and withdraw functionality
- ✅ LTV constraint validation
- ✅ Interest calculation
- ✅ NFT receipt management

**Swap Tests:**
- ✅ Pool initialization
- ✅ Add/remove liquidity
- ✅ Swap with fee calculation
- ✅ Constant product formula verification
- ✅ Slippage protection

### Expected Test Output

```
running 25 tests

test faucet_tests::test_faucet_msui_claim ... ok
test faucet_tests::test_faucet_cooldown ... ok
test lending_tests::test_deposit_and_borrow ... ok
test lending_tests::test_ltv_validation ... ok
test lending_tests::test_repay_with_interest ... ok
test swap_tests::test_pool_initialization ... ok
test swap_tests::test_swap_fee_calculation ... ok
test swap_tests::test_constant_product ... ok

Test result: ok. 25 passed; 0 failed; 0 aborted
```

---

## 🚀 Deployment

### Pre-Deployment Checklist

- [ ] Sui CLI installed and verified (`sui --version`)
- [ ] Wallet configured with gas funds (minimum 0.5 SUI)
- [ ] Testnet/Devnet selected as network
- [ ] Build successful (`sui move build`)
- [ ] All tests passed (`sui move test`)

### Deployment Steps

#### 1. Build Package
```bash
cd nerve
sui move build
```

**Expected Output:**
```
Building Modules...
Compiling Sui Framework
Compiling MoveStdlib
Compiling nerve
Package directory: ./build/nerve
```

#### 2. Publish Package
```bash
# Interactive deployment
sui client publish --gas-budget 100000000

# Non-interactive (ensure environment is setup)
sui client publish \
  --package-path . \
  --gas-budget 100000000 \
  --skip-dependency-verification
```

#### 3. Capture Output
```
╭─────────────────────────────────────────╮
│ Successfully published package!         │
│ Transaction digest: 0xABC...            │
│ Package ID: 0x12345...                  │
╰─────────────────────────────────────────╯
```

**Note:** Save the Package ID for package interactions!

### Post-Deployment

#### Verify Package
```bash
sui client object 0x<package-id>
```

#### Initialize Pools (Optional)
```bash
# If using scripts, run initialization
cd ../scripts
npm run init
```

#### Test Faucet Function
```bash
sui client call --package 0x<package-id> \
  --module faucet \
  --function faucet_msui \
  --gas-budget 1000000
```

---

## 💡 Usage Examples

### Scenario 1: Using Faucet

```move
// 1. Claim MSUI
let msui = faucet::faucet_msui(&mut tx_context);
transfer::public_transfer(msui, sender(ctx));

// 2. Wait 1 hour
// ... (cooldown period)

// 3. Claim again
let msui_again = faucet::faucet_msui(&mut tx_context);
transfer::public_transfer(msui_again, sender(ctx));
```

### Scenario 2: Lending & Borrowing

```move
// 1. Setup lending pool
let pool = lending::create_pool<MSUI>();

// 2. Deposit collateral
let msui = faucet::faucet_msui(&mut ctx);
lending::deposit(msui, &mut pool, &mut ctx);

// 3. Borrow against collateral
let (borrowed, receipt) = lending::borrow(
    500,           // borrow 500 MSUI
    1000,          // with 1000 MSUI collateral (80% LTV)
    &mut pool,
    &mut ctx
);

// 4. Repay borrow
let repay_coin = faucet::faucet_msui(&mut ctx);
lending::repay(receipt, repay_coin, &mut pool, &mut ctx);

// 5. Withdraw collateral
let collateral = lending::withdraw(1000, &mut pool, &mut ctx);
transfer::public_transfer(collateral, sender(&ctx));
```

### Scenario 3: AMM Swap

```move
// 1. Initialize pool with initial liquidity
let (msui, musdc, lp) = swap::init_pool<MSUI, MUSDC>(
    1000,  // 1000 MSUI
    1000   // 1000 MUSDC (1:1 ratio)
);

// 2. Add more liquidity
let (msui_coin, musdc_coin) = swap::add_liquidity(
    &mut pool,
    msui,
    musdc
);

// 3. Swap MSUI to MUSDC
let output = swap::swap_x_to_y<MSUI, MUSDC>(
    &mut pool,
    msui_coin,
    900  // min_out: expect at least 900 MUSDC (with slippage)
);

// 4. Remove liquidity
let (out_msui, out_musdc) = swap::remove_liquidity(
    &mut pool,
    lp
);
```

---

## 🔐 Security Notes

### ⚠️ IMPORTANT: Educational Use Only

These contracts are designed **ONLY for educational and testnet purposes**. Do not use in production without audit and enhancements.

### Known Limitations

| Issue | Description | Impact |
|-------|-------------|--------|
| No Access Control | No role management | Admin functions accessible by anyone |
| No Price Oracle | Token prices not validated | Borrow/lending can happen at arbitrary prices |
| No Liquidation | Positions cannot be liquidated | Bad debt can accumulate |
| Unlimited Minting | Admin mint not limited | Token supply can inflate uncontrollably |
| No Audit | Contracts not audited | Potential bugs and vulnerabilities |

### Recommendations for Production

If you want to reuse this code for production, add:

1. **Access Control**
   ```move
   // Add capability-based access control
   struct AdminCapability has key { ... }
   
   fun restricted_mint(..., cap: &AdminCapability) { ... }
   ```

2. **Price Oracle Integration**
   ```move
   // Integrate with Pyth/Switchboard
   let price = oracle::get_price(token_id);
   let collateral_value = amount * price;
   ```

3. **Liquidation Engine**
   ```move
   fun liquidate(position_id: u64, pool: &mut Pool, ...) {
       // Check if position underwater
       // Force sell collateral
       // Distribute to lender
   }
   ```

4. **Auditing & Testing**
   - External code audit
   - Comprehensive fuzzing
   - Economic model review
   - Gas optimization

### Best Practices

- Always validate input amounts
- Check for integer overflow/underflow
- Use `sui::balance` for tracking
- Implement comprehensive event logging
- Rate limit admin functions if possible

---

## 🛠️ Troubleshooting

### Build Issues

#### Error: "Cannot find dependency Sui"
```bash
# Solution: Update Move.toml with latest Sui revision
sui move update --dependencies
```

#### Error: "Module already published"
```bash
# Solution: Change package address in Move.toml
# [addresses]
# nerve = "0x1"  # Change this to different address
```

#### Out of Memory During Build
```bash
# Solution: Increase available memory
export RUST_MIN_STACK=8388608
sui move build
```

### Runtime Issues

#### Error: "Insufficient gas"
```bash
# Increase gas budget
sui client call ... --gas-budget 200000000
```

#### Error: "Not enough balance for gas"
```bash
# Claim tokens from faucet for gas
sui client call --package <pkg_id> \
  --module faucet \
  --function faucet_msui \
  --gas-budget 1000000
```

#### Test Failures

**Issue:** Some tests timeout
```bash
# Solution: Run individual test
sui move test -- --filter specific_test

# Increase timeout if needed
sui move test -- --timeout 60000
```

### Deployment Issues

#### Error: "Invalid package digest"
```bash
# Solution: Force rebuild
rm -rf build/
sui move build --force
sui client publish --package-path . --gas-budget 200000000
```

#### Transaction Fails During Publish
```bash
# Check gas budget
sui client gas

# If insufficient, fund wallet
sui client call --package <faucet_pkg> \
  --module faucet \
  --function faucet_msui
```

### Network Issues

#### Can't Connect to Testnet
```bash
# Check current network
sui client active-address

# Switch network
sui client switch --env testnet

# Verify connection
sui client objects --from-address <address>
```

#### Package Not Found After Publish
```bash
# Wait 5-10 seconds for indexing
sleep 10

# Query package
sui client object <package-id>
```

---

## 📖 Additional Documentation

### External Resources

- [Sui Developer Documentation](https://docs.sui.io)
- [Move Language Reference](https://move-language.github.io)
- [Sui CLI Commands](https://docs.sui.io/references/cli)
- [Sui RPC API](https://docs.sui.io/references/sui-api)

### Useful Commands

```bash
# Compile and check errors
sui move check

# Analyze module dependencies
sui move prove

# Generate documentation
sui move doc

# Run benchmark
sui move test -- --coverage --test <test_name>
```

---

## 🤝 Contributing

We accept contributions in the form of:

- Bug reports and fixes
- Documentation improvements
- Test cases
- Performance optimizations
- Feature suggestions

### Contribution Process

1. Fork repository
2. Create feature branch (`git checkout -b feature/improvement`)
3. Commit changes (`git commit -am 'Add feature'`)
4. Push to branch (`git push origin feature/improvement`)
5. Open Pull Request with detailed description

---

## 📄 License

This package is released for **educational and testing purposes** on Sui testnet.

**Note:** This code is NOT guaranteed for production use. Use at your own risk.

---

## 📞 Support & Contact

For questions or issues:

1. Open GitHub Issue with detailed description
2. Include stack trace and steps to reproduce
3. Specify Sui CLI version: `sui --version`
4. Attach relevant logs: `sui client call ... --verbose`

---

## 📝 Changelog

### Version 1.0.0 (2026-02-07)
- Initial release with Faucet, Lending, and Swap modules
- Comprehensive tests and documentation
- Testnet deployment support

---

**Happy building on Sui! 🚀**

*Last Updated: February 7, 2026*
