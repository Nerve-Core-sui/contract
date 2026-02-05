#!/bin/bash
# Setup environment for Sui development

set -e

echo "========================================"
echo "  NerveCore Environment Setup"
echo "========================================"
echo ""

# Check OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     PLATFORM=Linux;;
    Darwin*)    PLATFORM=Mac;;
    MINGW*|MSYS*|CYGWIN*)    PLATFORM=Windows;;
    *)          PLATFORM="UNKNOWN:${OS}"
esac

echo "Detected platform: $PLATFORM"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Sui CLI is installed
if command_exists sui; then
    SUI_VERSION=$(sui --version)
    echo "Sui CLI is already installed: $SUI_VERSION"
    echo ""
else
    echo "Sui CLI not found. Installing..."
    echo ""

    if [ "$PLATFORM" = "Mac" ]; then
        if command_exists brew; then
            echo "Installing via Homebrew..."
            brew install sui
        else
            echo "Error: Homebrew not found. Please install from: https://brew.sh/"
            exit 1
        fi
    elif [ "$PLATFORM" = "Linux" ]; then
        echo "Downloading Sui CLI binary..."
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            curl -LO https://github.com/MystenLabs/sui/releases/download/testnet/sui-testnet-ubuntu-x86_64.tgz
            tar -xzf sui-testnet-ubuntu-x86_64.tgz
            chmod +x sui
            sudo mv sui /usr/local/bin/
            rm sui-testnet-ubuntu-x86_64.tgz
        else
            echo "Error: Unsupported architecture: $ARCH"
            echo "Please install manually from: https://docs.sui.io/build/install"
            exit 1
        fi
    elif [ "$PLATFORM" = "Windows" ]; then
        echo "For Windows, please install Sui CLI manually:"
        echo "1. Download from: https://github.com/MystenLabs/sui/releases"
        echo "2. Extract and add to PATH"
        echo "Or use WSL2 and run this script again."
        exit 1
    else
        echo "Error: Unsupported platform: $PLATFORM"
        echo "Please install manually from: https://docs.sui.io/build/install"
        exit 1
    fi

    echo "Sui CLI installed successfully!"
    echo ""
fi

# Check if wallet is configured
if sui client active-address &> /dev/null; then
    ACTIVE_ADDRESS=$(sui client active-address)
    echo "Wallet is already configured."
    echo "Active address: $ACTIVE_ADDRESS"
    echo ""
else
    echo "No wallet found. Creating new wallet..."
    echo ""

    # Create new address
    sui client new-address ed25519

    ACTIVE_ADDRESS=$(sui client active-address)
    echo ""
    echo "New wallet created!"
    echo "Address: $ACTIVE_ADDRESS"
    echo ""
fi

# Switch to testnet
echo "Configuring testnet environment..."
sui client switch --env testnet 2>/dev/null || sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
sui client switch --env testnet
echo "Switched to testnet"
echo ""

# Check balance
echo "Checking testnet balance..."
BALANCE=$(sui client gas --json 2>/dev/null | jq -r '.[0].balance // 0' || echo "0")

if [ "$BALANCE" -eq 0 ]; then
    echo "Your wallet has no testnet SUI."
    echo ""
    echo "To get testnet SUI:"
    echo "1. Visit: https://faucet.testnet.sui.io/"
    echo "2. Enter your address: $ACTIVE_ADDRESS"
    echo "3. Complete the captcha and request tokens"
    echo "4. Wait a few seconds for the transaction to complete"
    echo ""
    echo "Or use the curl command:"
    echo "curl --location --request POST 'https://faucet.testnet.sui.io/gas' \\"
    echo "  --header 'Content-Type: application/json' \\"
    echo "  --data-raw '{\"FixedAmountRequest\":{\"recipient\":\"$ACTIVE_ADDRESS\"}}'"
    echo ""
else
    BALANCE_SUI=$(echo "scale=4; $BALANCE / 1000000000" | bc)
    echo "Current balance: $BALANCE_SUI SUI"
    echo ""
fi

echo "========================================"
echo "  Setup Complete!"
echo "========================================"
echo ""
echo "Your environment is ready for deployment."
echo ""
echo "Next steps:"
echo "1. Ensure you have testnet SUI in your wallet"
echo "2. Navigate to contracts/nervecore directory"
echo "3. Run: ../scripts/deploy.sh"
echo ""
echo "Useful commands:"
echo "  sui client active-address    - Show your active address"
echo "  sui client gas                - Check your gas objects"
echo "  sui client envs               - List configured environments"
echo "  sui client switch --env testnet - Switch to testnet"
echo ""
