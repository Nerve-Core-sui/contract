#!/bin/bash
# Deploy NerveCore contracts to Sui testnet
# Usage: bash contracts/scripts/deploy.sh  (from project root)
#    or: bash deploy.sh                    (from contracts/scripts/)
#    or: bash ../scripts/deploy.sh         (from contracts/nervecore/)

set -e

echo "========================================"
echo "  NerveCore Deployment Script"
echo "========================================"
echo ""

# ---- Locate nervecore directory ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NERVECORE_DIR="$(cd "$SCRIPT_DIR/../nervecore" 2>/dev/null && pwd)" || true

# If script is run from nervecore dir directly
if [ -f "Move.toml" ]; then
    NERVECORE_DIR="$(pwd)"
elif [ -z "$NERVECORE_DIR" ] || [ ! -f "$NERVECORE_DIR/Move.toml" ]; then
    echo "Error: Cannot find nervecore/Move.toml"
    echo "Run this script from project root, contracts/scripts/, or contracts/nervecore/"
    exit 1
fi

cd "$NERVECORE_DIR"
echo "Working directory: $NERVECORE_DIR"
echo ""

# ---- Check dependencies ----
if ! command -v sui &> /dev/null; then
    echo "Error: Sui CLI is not installed."
    echo "Install: cargo install --locked --git https://github.com/MystenLabs/sui.git --branch testnet sui"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    echo "Install: sudo apt install jq"
    exit 1
fi

echo "Sui CLI version: $(sui --version 2>/dev/null || echo 'unknown')"
echo ""

# ---- Check active address ----
ACTIVE_ADDRESS=$(sui client active-address 2>/dev/null || echo "")
if [ -z "$ACTIVE_ADDRESS" ]; then
    echo "Error: No active Sui address found."
    echo ""
    echo "Set up a wallet first:"
    echo "  sui client new-address ed25519"
    echo "  sui client switch --address <your-address>"
    exit 1
fi

echo "Active address: $ACTIVE_ADDRESS"

# ---- Check network ----
ACTIVE_ENV=$(sui client active-env 2>/dev/null || echo "unknown")
echo "Active network:  $ACTIVE_ENV"
echo ""

if [ "$ACTIVE_ENV" != "testnet" ]; then
    echo "Warning: You are NOT on testnet (current: $ACTIVE_ENV)"
    echo "Switch with: sui client switch --env testnet"
    echo ""
    read -p "Continue anyway? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# ---- Check balance ----
echo "Checking balance..."
GAS_JSON=$(sui client gas --json 2>/dev/null || echo "[]")
BALANCE=$(echo "$GAS_JSON" | jq -r 'if length > 0 then .[0].mistBalance // 0 else 0 end' 2>/dev/null || echo "0")

# Handle different JSON formats (mistBalance vs gasBalance)
if [ "$BALANCE" = "0" ] || [ "$BALANCE" = "null" ]; then
    BALANCE=$(echo "$GAS_JSON" | jq -r 'if length > 0 then .[0].gasBalance // 0 else 0 end' 2>/dev/null || echo "0")
fi

BALANCE_SUI=$(echo "scale=4; $BALANCE / 1000000000" | bc 2>/dev/null || echo "?")
echo "Balance: $BALANCE MIST (~$BALANCE_SUI SUI)"

if [ "$BALANCE" -lt 200000000 ] 2>/dev/null; then
    echo ""
    echo "Warning: Low balance! You need at least ~0.2 SUI for deployment."
    echo "Get testnet SUI: sui client faucet"
    echo "  or visit: https://faucet.testnet.sui.io/"
    echo ""
    read -p "Try requesting from faucet now? (y/N): " FAUCET
    if [ "$FAUCET" = "y" ] || [ "$FAUCET" = "Y" ]; then
        echo "Requesting testnet SUI..."
        sui client faucet 2>/dev/null || echo "Faucet request failed. Try manually."
        echo "Waiting 5 seconds for funds..."
        sleep 5
    fi
fi
echo ""

# ---- Build contracts ----
echo "========================================"
echo "  Building Move contracts..."
echo "========================================"
echo ""

if ! sui move build; then
    echo ""
    echo "Error: Build failed. Fix the errors above and try again."
    exit 1
fi
echo ""
echo "Build successful!"
echo ""

# ---- Publish to network ----
echo "========================================"
echo "  Publishing to Sui $ACTIVE_ENV..."
echo "========================================"
echo ""
echo "This will cost approximately 0.1-0.2 SUI in gas fees."
echo ""

PUBLISH_OUTPUT=$(sui client publish --gas-budget 500000000)

if [ $? -ne 0 ]; then
    echo "Error: Publish failed"
    echo "$PUBLISH_OUTPUT"
    exit 1
fi

# Check for errors in JSON output
STATUS=$(echo "$PUBLISH_OUTPUT" | jq -r '.effects.status.status // "unknown"' 2>/dev/null)
if [ "$STATUS" != "success" ]; then
    echo "Error: Transaction failed with status: $STATUS"
    echo "$PUBLISH_OUTPUT" | jq -r '.effects.status' 2>/dev/null
    exit 1
fi

echo "Publish successful!"
echo ""

# ---- Parse results ----
PACKAGE_ID=$(echo "$PUBLISH_OUTPUT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')
DIGEST=$(echo "$PUBLISH_OUTPUT" | jq -r '.digest // "unknown"')

echo "========================================"
echo "  Deployment Results"
echo "========================================"
echo ""
echo "Package ID:  $PACKAGE_ID"
echo "TX Digest:   $DIGEST"
echo ""

# Extract shared objects
echo "Shared Objects Created:"
echo "----------------------------------------"
echo "$PUBLISH_OUTPUT" | jq -r '
  .objectChanges[]
  | select(.type == "created" and .owner.Shared != null)
  | "  \(.objectType | split("::") | .[-1]): \(.objectId)"
' 2>/dev/null
echo ""

# Extract specific object IDs for frontend .env
MSUI_TREASURY=$(echo "$PUBLISH_OUTPUT" | jq -r '.objectChanges[] | select(.type == "created" and .objectType != null and (.objectType | contains("MSUITreasury"))) | .objectId' 2>/dev/null || echo "")
MUSDC_TREASURY=$(echo "$PUBLISH_OUTPUT" | jq -r '.objectChanges[] | select(.type == "created" and .objectType != null and (.objectType | contains("MUSDCTreasury"))) | .objectId' 2>/dev/null || echo "")
CLAIM_REGISTRY=$(echo "$PUBLISH_OUTPUT" | jq -r '.objectChanges[] | select(.type == "created" and .objectType != null and (.objectType | contains("ClaimRegistry"))) | .objectId' 2>/dev/null || echo "")
LENDING_POOL=$(echo "$PUBLISH_OUTPUT" | jq -r '.objectChanges[] | select(.type == "created" and .objectType != null and (.objectType | contains("LendingPool"))) | .objectId' 2>/dev/null || echo "")
ADMIN_CAP=$(echo "$PUBLISH_OUTPUT" | jq -r '.objectChanges[] | select(.type == "created" and .objectType != null and (.objectType | contains("AdminCap"))) | .objectId' 2>/dev/null || echo "")

# ---- Save deployment files ----
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Full deployment JSON
DEPLOYMENT_FILE="deployment-${TIMESTAMP}.json"
echo "$PUBLISH_OUTPUT" > "$DEPLOYMENT_FILE"
echo "Full deployment JSON: $DEPLOYMENT_FILE"

# Package ID file
echo "$PACKAGE_ID" > .package-id
echo "Package ID file:     .package-id"

# Generate frontend .env values
ENV_FILE="deployment-${TIMESTAMP}.env"
cat > "$ENV_FILE" << EOF
# NerveCore Contract Addresses
# Generated: $(date)
# Network: $ACTIVE_ENV
# TX Digest: $DIGEST

NEXT_PUBLIC_PACKAGE_ID=$PACKAGE_ID
NEXT_PUBLIC_MSUI_TREASURY=$MSUI_TREASURY
NEXT_PUBLIC_MUSDC_TREASURY=$MUSDC_TREASURY
NEXT_PUBLIC_CLAIM_REGISTRY=$CLAIM_REGISTRY
NEXT_PUBLIC_LENDING_POOL=$LENDING_POOL
NEXT_PUBLIC_ADMIN_CAP=$ADMIN_CAP
EOF

echo "Frontend .env file:  $ENV_FILE"
echo ""

echo "========================================"
echo "  Frontend .env Values"
echo "========================================"
echo ""
cat "$ENV_FILE"
echo ""

echo "========================================"
echo "  Next Steps"
echo "========================================"
echo ""
echo "1. Copy the values above to frontend/.env.local"
echo "2. The msui, musdc, faucet, lending, and swap modules are deployed!"
echo "3. Shared objects (treasuries, registry, pool) are ready to use."
echo ""
echo "Explorer: https://suiscan.xyz/$ACTIVE_ENV/tx/$DIGEST"
echo ""
