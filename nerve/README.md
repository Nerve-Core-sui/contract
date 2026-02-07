# Nerve Package

Move contracts for the NerveCore DeFi gaming platform on Sui.

Folder contents
- `Move.toml` — package manifest
- `sources/` — Move modules: `faucet.move`, `lending.move`, `swap.move`
- `build/` — compiled bytecode and debug info
- `tests/` — Move unit tests

Quick local steps
1. Build the package:

   ```bash
   cd nerve
   sui move build
   ```

2. Run tests (optional):

   ```bash
   sui move test
   ```

Notes
- This package is intended for testnet/educational use only.
- See the project root README for full instructions and deployment scripts.

License: MIT
