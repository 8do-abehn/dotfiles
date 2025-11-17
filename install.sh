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

# Setup Claude Code configuration
echo "Setting up Claude Code configuration..."
mkdir -p "$HOME/.claude"

# Backup existing Claude Code files if they exist
if [[ -f "$HOME/.claude/CLAUDE.md" ]] && [[ ! -L "$HOME/.claude/CLAUDE.md" ]]; then
    echo "Backing up existing CLAUDE.md to CLAUDE.md.backup"
    cp "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md.backup"
fi

if [[ -f "$HOME/.claude/settings.json" ]] && [[ ! -L "$HOME/.claude/settings.json" ]]; then
    echo "Backing up existing settings.json to settings.json.backup"
    cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.backup"
fi

# Symlink Claude Code files
ln -sf "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"

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

# Set desktop background
if [[ -d "$DOTFILES_DIR/desktops" ]] && [[ -f "$DOTFILES_DIR/macos/set-desktop.sh" ]]; then
    read -p "Do you want to set a desktop background? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash "$DOTFILES_DIR/macos/set-desktop.sh"
    else
        echo "Skipping desktop background"
    fi
    echo ""
fi

# Setup SwiftBar plugins
if [[ -d "$DOTFILES_DIR/swiftbar" ]]; then
    echo "Setting up SwiftBar plugins..."
    mkdir -p "$HOME/swiftbar"

    # Symlink all SwiftBar scripts
    for script in "$DOTFILES_DIR/swiftbar"/*.sh; do
        if [[ -f "$script" ]]; then
            script_name=$(basename "$script")
            ln -sf "$script" "$HOME/swiftbar/$script_name"
            echo "Linked $script_name"
        fi
    done

    echo ""
    echo "SwiftBar setup complete!"
    echo "To configure API key for claude-usage widget:"
    echo "  security add-generic-password -a \"\${USER}\" -s \"anthropic-api-key\" -w"
    echo ""
fi

echo "Installation complete!"
echo "Please restart your terminal or run: source ~/.zshrc"
