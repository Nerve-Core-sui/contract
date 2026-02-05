#!/bin/bash
# Deploy NerveCore contracts to Sui testnet

set -e

echo "========================================"
echo "  NerveCore Deployment Script"
echo "========================================"
echo ""

# Check if sui CLI is installed
if ! command -v sui &> /dev/null; then
    echo "Error: Sui CLI is not installed."
    echo "Please install it first using setup-env.sh"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -f "Move.toml" ]; then
    echo "Error: Move.toml not found. Please run this script from the contracts/nervecore directory."
    exit 1
fi

# Get current active address
ACTIVE_ADDRESS=$(sui client active-address 2>/dev/null || echo "")
if [ -z "$ACTIVE_ADDRESS" ]; then
    echo "Error: No active Sui address found."
    echo "Please set up your wallet first using: sui client new-address ed25519"
    exit 1
fi

echo "Active address: $ACTIVE_ADDRESS"
echo ""

# Check balance
echo "Checking testnet balance..."
BALANCE=$(sui client gas --json 2>/dev/null | jq -r '.[0].balance // 0')
if [ "$BALANCE" -lt 100000000 ]; then
    echo "Warning: Low balance detected (${BALANCE} MIST)"
    echo "You may need testnet SUI from: https://faucet.testnet.sui.io/"
    echo ""
fi

# Build contracts
echo "Building Move contracts..."
sui move build --skip-fetch-latest-git-deps
if [ $? -ne 0 ]; then
    echo "Error: Build failed"
    exit 1
fi
echo "Build successful!"
echo ""

# Publish to testnet
echo "Publishing to Sui testnet..."
echo "This will cost approximately 0.1 SUI in gas fees."
echo ""

PUBLISH_OUTPUT=$(sui client publish --gas-budget 100000000 --json)

if [ $? -ne 0 ]; then
    echo "Error: Publish failed"
    echo "$PUBLISH_OUTPUT"
    exit 1
fi

echo "Publish successful!"
echo ""

# Parse package ID and object IDs from output
PACKAGE_ID=$(echo "$PUBLISH_OUTPUT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')

echo "========================================"
echo "  Deployment Results"
echo "========================================"
echo ""
echo "Package ID: $PACKAGE_ID"
echo ""

# Extract shared objects
echo "Shared Objects Created:"
echo "$PUBLISH_OUTPUT" | jq -r '.objectChanges[] | select(.type == "created" and .owner.Shared != null) | "\(.objectType): \(.objectId)"'
echo ""

# Save deployment info
DEPLOYMENT_FILE="deployment-$(date +%Y%m%d-%H%M%S).json"
echo "$PUBLISH_OUTPUT" > "$DEPLOYMENT_FILE"
echo "Full deployment data saved to: $DEPLOYMENT_FILE"
echo ""

# Save package ID for init script
echo "$PACKAGE_ID" > .package-id
echo "Package ID saved to .package-id"
echo ""

echo "========================================"
echo "  Next Steps"
echo "========================================"
echo ""
echo "1. Copy the Package ID and shared object IDs above"
echo "2. Run the initialization script:"
echo "   cd scripts && npm install && npm run init"
echo "3. Update your frontend .env file with the contract addresses"
echo ""
echo "Note: The faucet, lending, and swap modules are now deployed!"
echo "      Shared objects (treasuries, registries, pools) are automatically"
echo "      created and ready to use."
echo ""
