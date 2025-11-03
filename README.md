# Dotfiles

Personal dotfiles configuration for macOS.

## Structure

```
dotfiles/
├── zsh/
│   └── .zshrc                  # Zsh configuration
├── ssh/
│   ├── config                  # SSH client configuration
│   └── install.sh              # SSH config symlink installer
├── homebrew/
│   └── Brewfile                # Homebrew packages
├── macos/
│   ├── defaults.sh             # macOS system preferences
│   └── system-updates.sh       # System components (Rosetta, etc.)
├── git/
│   └── setup.sh                # Git config & GitHub SSH key setup
├── install.sh                  # Main installation script
└── README.md
```

## Installation

### Full Installation

Run the installation script to set up everything:

```bash
bash ~/8do/dotfiles/install.sh
```

This will:
- Check and install system requirements (Rosetta on Apple Silicon)
- Install Homebrew (if not already installed)
- Symlink `.zshrc` to your home directory
- Install all packages from the Brewfile
- Optionally apply macOS system preferences

### Manual Installation

#### Zsh Configuration

```bash
ln -sf ~/8do/dotfiles/zsh/.zshrc ~/.zshrc
source ~/.zshrc
```

#### SSH Configuration

```bash
bash ~/8do/dotfiles/ssh/install.sh
```

This will:
- Backup existing SSH config (if not already a symlink)
- Symlink `ssh/config` to `~/.ssh/config`
- Set correct permissions (600)

#### Homebrew Packages

```bash
brew bundle --file=~/8do/dotfiles/homebrew/Brewfile
```

#### System Updates (Rosetta, etc.)

```bash
bash ~/8do/dotfiles/macos/system-updates.sh
```

#### macOS Defaults

```bash
bash ~/8do/dotfiles/macos/defaults.sh
```

#### Git & GitHub SSH Setup

```bash
bash ~/8do/dotfiles/git/setup.sh
```

This will:
- Set global git config (name and email)
- Generate SSH key for GitHub
- Add key to ssh-agent and macOS keychain
- Update SSH config
- Copy public key to clipboard for adding to GitHub

## Customization

### Adding Homebrew Packages

Edit `homebrew/Brewfile` and add:

```ruby
brew "package-name"        # CLI tools
cask "app-name"           # Applications
```

Then run:

```bash
brew bundle --file=~/8do/dotfiles/homebrew/Brewfile
```

### Modifying Zsh Config

Edit `zsh/.zshrc` and reload:

```bash
source ~/.zshrc
# or use the alias:
zshreload
```

### Adjusting macOS Settings

Edit `macos/defaults.sh` to customize system preferences.

## Features

### Zsh Configuration
- Homebrew integration
- Command history settings
- Useful aliases (ll, la, brewup, etc.)
- Git aliases
- Custom prompt with git branch display
- Color support

### Included Packages
- Development: git, wget, curl, tree
- Browsers: Brave Browser
- Productivity: Bitwarden, Slack, Microsoft Teams
- Entertainment: Spotify, Minecraft
- DevOps: Docker Desktop, Tailscale, VSCodium
- Mac App Store: STTS (via mas)

### macOS Defaults
- Natural scrolling disabled
- Tap to click enabled
- Fast keyboard repeat
- Dock auto-hide
- Finder enhancements
- And more...

## Updating

To update packages:

```bash
brewup  # alias for: brew update && brew upgrade && brew cleanup
```

## Backup

The installation script automatically backs up your existing `.zshrc` to `.zshrc.backup`.

## Notes

- Tested on macOS (Apple Silicon)
- Some macOS defaults changes require logout/restart
- Customize to your preferences!
