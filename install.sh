#!/bin/bash

# Dotfiles installation script
# Run with: bash ~/8do/dotfiles/install.sh

set -e

DOTFILES_DIR="$HOME/8do/dotfiles"

echo "Installing dotfiles..."
echo ""

# Check and install system requirements
if [[ -f "$DOTFILES_DIR/macos/system-updates.sh" ]]; then
    bash "$DOTFILES_DIR/macos/system-updates.sh"
    echo ""
fi

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Homebrew already installed ✓"
fi

echo ""

# Backup existing .zshrc if it exists
if [[ -f "$HOME/.zshrc" ]]; then
    echo "Backing up existing .zshrc to .zshrc.backup"
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
fi

# Symlink .zshrc
echo "Linking .zshrc..."
ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

echo ""

# Install Homebrew packages
if [[ -f "$DOTFILES_DIR/homebrew/Brewfile" ]]; then
    echo "Installing Homebrew packages..."
    brew bundle --file="$DOTFILES_DIR/homebrew/Brewfile"
else
    echo "Brewfile not found, skipping package installation"
fi

echo ""

# Apply macOS defaults
read -p "Do you want to apply macOS defaults? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -f "$DOTFILES_DIR/macos/defaults.sh" ]]; then
        bash "$DOTFILES_DIR/macos/defaults.sh"
    else
        echo "macOS defaults script not found"
    fi
else
    echo "Skipping macOS defaults"
fi

echo ""
echo "Installation complete!"
echo "Please restart your terminal or run: source ~/.zshrc"
