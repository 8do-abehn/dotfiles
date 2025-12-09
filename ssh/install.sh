#!/bin/bash

# SSH Config Installation Script
# Run with: bash ~/8do/dotfiles/ssh/install.sh

set -euo pipefail

DOTFILES_SSH_CONFIG="$HOME/8do/dotfiles/ssh/config"
SSH_CONFIG="$HOME/.ssh/config"

echo "Setting up SSH configuration..."
echo ""

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Backup existing SSH config if it exists and is not a symlink
if [[ -f "$SSH_CONFIG" ]] && [[ ! -L "$SSH_CONFIG" ]]; then
    echo "Backing up existing SSH config..."
    cp "$SSH_CONFIG" "${SSH_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backup created: ${SSH_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    echo ""
fi

# Remove existing file/symlink
if [[ -e "$SSH_CONFIG" ]] || [[ -L "$SSH_CONFIG" ]]; then
    rm "$SSH_CONFIG"
fi

# Create symlink
echo "Linking SSH config..."
ln -sf "$DOTFILES_SSH_CONFIG" "$SSH_CONFIG"

# Set correct permissions
chmod 600 "$SSH_CONFIG"

echo "SSH config linked successfully ✓"
echo ""
echo "Configuration:"
echo "  Source: $DOTFILES_SSH_CONFIG"
echo "  Target: $SSH_CONFIG"
echo ""
echo "Edit your SSH config:"
echo "  ${EDITOR:-nano} $DOTFILES_SSH_CONFIG"
echo ""
echo "Test your configuration:"
echo "  ssh -T git@github.com"
echo "  ssh pve001 (or whatever your Proxmox host is)"
