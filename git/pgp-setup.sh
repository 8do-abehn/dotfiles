#!/bin/bash

# PGP Key Setup Script
# Imports PGP keys from Bitwarden and configures Git signing
# Run with: bash ~/8do/dotfiles/git/pgp-setup.sh

set -e

ITEM_NAME="keybase.io"
TEMP_DIR=$(mktemp -d)

echo "Setting up PGP keys from Bitwarden..."
echo ""

# Check if bw CLI is installed
if ! command -v bw &> /dev/null; then
    echo "Error: Bitwarden CLI (bw) is not installed"
    echo "Install with: brew install bitwarden-cli"
    exit 1
fi

# Check if gpg is installed
if ! command -v gpg &> /dev/null; then
    echo "Installing GPG..."
    brew install gnupg
fi

# Check Bitwarden login status
echo "Checking Bitwarden login status..."
if ! bw login --check &> /dev/null; then
    read -p "Enter your Bitwarden email: " BITWARDEN_EMAIL
    echo "Logging into Bitwarden as $BITWARDEN_EMAIL..."
    bw login "$BITWARDEN_EMAIL"
else
    echo "Already logged into Bitwarden ✓"
fi

# Unlock vault
echo "Unlocking Bitwarden vault..."
echo "Enter your Bitwarden master password:"
BW_SESSION=$(bw unlock --raw)

if [[ -z "$BW_SESSION" ]]; then
    echo "Error: Failed to unlock Bitwarden vault"
    exit 1
fi

export BW_SESSION

echo "Vault unlocked ✓"
echo ""

# Search for keybase.io item
echo "Searching for '$ITEM_NAME' in Bitwarden..."
ITEM_ID=$(bw list items --search "$ITEM_NAME" | jq -r '.[0].id')

if [[ -z "$ITEM_ID" ]] || [[ "$ITEM_ID" == "null" ]]; then
    echo "Error: Could not find '$ITEM_NAME' in Bitwarden"
    bw lock
    exit 1
fi

echo "Found item ✓"
echo ""

# Get attachments
echo "Retrieving PGP key attachments..."
ATTACHMENTS=$(bw list items --search "$ITEM_NAME" | jq -r '.[0].attachments')

if [[ "$ATTACHMENTS" == "null" ]]; then
    echo "Error: No attachments found on '$ITEM_NAME' item"
    bw lock
    exit 1
fi

# Download private key
echo "Downloading private key..."
PRIVATE_KEY_ID=$(echo "$ATTACHMENTS" | jq -r '.[] | select(.fileName == "pgp_private") | .id')
if [[ -z "$PRIVATE_KEY_ID" ]] || [[ "$PRIVATE_KEY_ID" == "null" ]]; then
    echo "Error: pgp_private attachment not found"
    bw lock
    rm -rf "$TEMP_DIR"
    exit 1
fi

bw get attachment "$PRIVATE_KEY_ID" --itemid "$ITEM_ID" --output "$TEMP_DIR/pgp_private" --raw

# Download public key
echo "Downloading public key..."
PUBLIC_KEY_ID=$(echo "$ATTACHMENTS" | jq -r '.[] | select(.fileName == "pgp_public") | .id')
if [[ -z "$PUBLIC_KEY_ID" ]] || [[ "$PUBLIC_KEY_ID" == "null" ]]; then
    echo "Error: pgp_public attachment not found"
    bw lock
    rm -rf "$TEMP_DIR"
    exit 1
fi

bw get attachment "$PUBLIC_KEY_ID" --itemid "$ITEM_ID" --output "$TEMP_DIR/pgp_public" --raw

echo "Keys downloaded ✓"
echo ""

# Lock vault
bw lock
unset BW_SESSION

# Import keys into GPG
echo "Importing keys into GPG..."

# Import private key
if gpg --import "$TEMP_DIR/pgp_private" 2>&1; then
    echo "Private key imported ✓"
else
    echo "Error: Failed to import private key"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Import public key
if gpg --import "$TEMP_DIR/pgp_public" 2>&1; then
    echo "Public key imported ✓"
else
    echo "Error: Failed to import public key"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo ""

# Clean up temp files
rm -rf "$TEMP_DIR"

# Get the key ID
echo "Getting key information..."
KEY_ID=$(gpg --list-secret-keys --keyid-format=long | grep sec | head -1 | sed 's|.*/\([^ ]*\) .*|\1|')

if [[ -z "$KEY_ID" ]]; then
    echo "Error: Could not determine key ID"
    exit 1
fi

echo "Key ID: $KEY_ID"
echo ""

# Configure Git to use the key
echo "Configuring Git to sign commits..."
git config --global user.signingkey "$KEY_ID"
git config --global commit.gpgsign true
git config --global tag.gpgsign true

echo "Git configured for commit signing ✓"
echo ""

# Export public key for GitHub
echo "========================================"
echo "PGP setup complete!"
echo "========================================"
echo ""
echo "Key ID: $KEY_ID"
echo ""
echo "Your public key for GitHub:"
echo ""
gpg --armor --export "$KEY_ID"
echo ""
echo "Next steps:"
echo "  1. Copy the public key above (-----BEGIN PGP PUBLIC KEY BLOCK----- to -----END PGP PUBLIC KEY BLOCK-----)"
echo "  2. Go to https://github.com/settings/keys"
echo "  3. Click 'New GPG key'"
echo "  4. Paste the public key"
echo "  5. Click 'Add GPG key'"
echo ""
echo "To export your public key again:"
echo "  gpg --armor --export $KEY_ID"
echo ""
echo "Test signing:"
echo "  echo 'test' | gpg --clearsign"
