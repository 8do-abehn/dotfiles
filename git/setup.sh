#!/bin/bash

# Git and GitHub SSH Setup Script
# Run with: bash ~/8do/dotfiles/git/setup.sh

set -euo pipefail

GITHUB_EMAIL="177274210+8do-abehn@users.noreply.github.com"
SSH_KEY_PATH="$HOME/.ssh/github_ed25519"

echo "Setting up Git and GitHub SSH..."
echo ""

# Set up global git config
echo "Configuring global git settings..."

# Check if git config is already set
CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [[ -n "$CURRENT_NAME" ]] && [[ "$CURRENT_EMAIL" == "$GITHUB_EMAIL" ]]; then
    echo "Git already configured ✓"
    echo "  user.name: $CURRENT_NAME"
    echo "  user.email: $CURRENT_EMAIL"
    GIT_USERNAME="$CURRENT_NAME"
else
    if [[ -n "$CURRENT_NAME" ]]; then
        echo "Current git config:"
        echo "  user.name: $CURRENT_NAME"
        echo "  user.email: $CURRENT_EMAIL"
        read -p "Update to use GitHub email? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            GIT_USERNAME="$CURRENT_NAME"
            echo "Keeping existing configuration"
        else
            read -rp "Enter your Git username (for commits) [$CURRENT_NAME]: " GIT_USERNAME
            GIT_USERNAME="${GIT_USERNAME:-$CURRENT_NAME}"
            git config --global user.name "$GIT_USERNAME"
            git config --global user.email "$GITHUB_EMAIL"
            echo "Git config updated ✓"
        fi
    else
        read -rp "Enter your Git username (for commits): " GIT_USERNAME
        if [[ -z "$GIT_USERNAME" ]]; then
            echo "Error: Git username is required"
            exit 1
        fi
        git config --global user.name "$GIT_USERNAME"
        git config --global user.email "$GITHUB_EMAIL"
        echo "Git config set ✓"
    fi
    echo "  user.name: $GIT_USERNAME"
    echo "  user.email: $GITHUB_EMAIL"
fi
echo ""

# Check if SSH key already exists
if [[ -f "$SSH_KEY_PATH" ]]; then
    echo "SSH key already exists ✓"
    echo "  Location: $SSH_KEY_PATH"

    # Check if key is already in ssh-agent
    if ssh-add -l 2>/dev/null | grep -q "$SSH_KEY_PATH"; then
        echo "  Key already loaded in ssh-agent ✓"
    else
        echo "  Adding key to ssh-agent..."
        eval "$(ssh-agent -s)" > /dev/null 2>&1
        ssh-add --apple-use-keychain "$SSH_KEY_PATH" 2>/dev/null || ssh-add "$SSH_KEY_PATH"
        echo "  Key added to ssh-agent ✓"
    fi
else
    # Generate SSH key
    echo "Generating SSH key..."
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f "$SSH_KEY_PATH" -N ""

    echo ""
    echo "SSH key generated successfully ✓"
    echo ""

    # Start ssh-agent and add key
    echo "Adding key to ssh-agent..."
    eval "$(ssh-agent -s)" > /dev/null

    # Add to macOS keychain
    ssh-add --apple-use-keychain "$SSH_KEY_PATH" 2>/dev/null || ssh-add "$SSH_KEY_PATH"

    echo "Key added to ssh-agent ✓"
fi
echo ""

# Create/update SSH config
SSH_CONFIG="$HOME/.ssh/config"

if ! grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
    echo "Updating SSH config..."
    mkdir -p ~/.ssh
    cat >> "$SSH_CONFIG" << EOF

# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY_PATH
    AddKeysToAgent yes
    UseKeychain yes
EOF
    echo "SSH config updated ✓"
else
    echo "SSH config already configured ✓"
fi

echo ""

# Copy public key to clipboard
if command -v pbcopy &> /dev/null; then
    pbcopy < "${SSH_KEY_PATH}.pub"
    echo "✓ Public key copied to clipboard!"
else
    echo "Public key:"
    cat "${SSH_KEY_PATH}.pub"
fi

echo ""
echo "========================================"
echo "Git and GitHub setup complete!"
echo "========================================"
echo ""
echo "Git configuration:"
echo "  Name: $GIT_USERNAME"
echo "  Email: $GITHUB_EMAIL"
echo ""
echo "SSH key location:"
echo "  Private: $SSH_KEY_PATH"
echo "  Public: ${SSH_KEY_PATH}.pub"
echo ""
echo "Next steps:"
echo "  1. Go to https://github.com/settings/keys"
echo "  2. Click 'New SSH key'"
echo "  3. Paste the public key (already in clipboard)"
echo "  4. Give it a title (e.g., 'MacBook Pro')"
echo "  5. Click 'Add SSH key'"
echo ""
echo "Test the connection:"
echo "  ssh -T git@github.com"
echo ""
echo "To view your public key again:"
echo "  cat ${SSH_KEY_PATH}.pub"
