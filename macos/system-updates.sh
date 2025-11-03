#!/bin/bash

# System updates requiring softwareupdate
# Run with: bash ~/8do/dotfiles/macos/system-updates.sh

echo "Checking for required system components..."
echo ""

# Rosetta 2 (Apple Silicon only)
if [[ $(uname -m) == 'arm64' ]]; then
    if ! /usr/bin/pgrep oahd >/dev/null 2>&1; then
        echo "Installing Rosetta 2..."
        softwareupdate --install-rosetta --agree-to-license
        echo "Rosetta 2 installed ✓"
    else
        echo "Rosetta 2 already installed ✓"
    fi
else
    echo "Intel Mac detected - Rosetta not needed ✓"
fi

echo ""

# Xcode Command Line Tools (optional - uncomment if needed)
# if ! xcode-select -p &>/dev/null; then
#     echo "Installing Xcode Command Line Tools..."
#     xcode-select --install
#     echo "Please complete the installation in the dialog, then re-run this script"
#     exit 1
# else
#     echo "Xcode Command Line Tools already installed ✓"
# fi

echo ""
echo "System updates check complete!"
