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
│   ├── system-updates.sh       # System components (Rosetta, etc.)
│   └── set-desktop.sh          # Desktop background configuration
├── git/
│   ├── setup.sh                # Git config & GitHub SSH key setup
│   └── pgp-setup.sh            # PGP key import & Git signing setup
├── claude/
│   ├── CLAUDE.md               # Claude Code global instructions
│   └── settings.json           # Claude Code settings
├── swiftbar/
│   ├── claude-usage.5m.sh      # Claude API usage monitor widget
│   └── README.md               # SwiftBar plugin docs
├── desktops/
│   └── *.jpg                   # Desktop background images
├── install.sh                  # Main installation script
├── status.sh                   # Check if dotfiles are in sync
├── validate.sh                 # Local validation script
├── .pre-commit-config.yaml     # Pre-commit hooks configuration
├── .secrets.baseline           # Known false positives for secret scanning
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
- Set up Claude Code configuration
- Install all packages from the Brewfile
- Set up SwiftBar plugins
- Optionally apply macOS system preferences
- Optionally set desktop background

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

#### Desktop Background

```bash
bash ~/8do/dotfiles/macos/set-desktop.sh
```

#### Git & GitHub SSH Setup

```bash
bash ~/8do/dotfiles/git/setup.sh
```

#### PGP Key Setup (from Bitwarden)

```bash
bash ~/8do/dotfiles/git/pgp-setup.sh
```

This will:
- Retrieve PGP keys from Bitwarden
- Import keys into GPG
- Configure Git for commit signing

## Development

### Status Check

Check if your dotfiles are in sync (useful after making changes on another machine):

```bash
./status.sh
```

This checks:
- Symlinks point to the correct files
- SwiftBar plugins are installed
- Homebrew packages are installed
- Pre-commit hooks are set up
- Git configuration is complete

### Validation

Run the local validation script before committing:

```bash
./validate.sh
```

This checks:
- Shell scripts with shellcheck
- Error handling (`set -euo pipefail`)
- JSON file validity
- Brewfile syntax
- Potential secrets

### Pre-commit Hooks

Install pre-commit hooks for automatic validation:

```bash
brew install pre-commit shellcheck
pre-commit install
```

Hooks run automatically on `git commit` and check:
- Shell script linting (shellcheck)
- Secret detection (detect-secrets)
- JSON/YAML validation
- File formatting

### CI

GitHub Actions runs on all PRs:
- Shellcheck linting
- Config file validation
- Secret scanning
- Brewfile syntax check

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

### Adding Desktop Backgrounds

Add images to `desktops/` and run:

```bash
bash ~/8do/dotfiles/macos/set-desktop.sh
```

## Features

### Zsh Configuration
- Homebrew integration
- Command history settings
- Useful aliases (ll, la, brewup, etc.)
- Git aliases
- Custom prompt with git branch display
- Color support

### Claude Code
- Global instructions in `CLAUDE.md`
- Settings symlinked to `~/.claude/`

### SwiftBar Plugins
- Claude API usage monitor (shows rate limit status in menu bar)

### macOS Defaults
- Natural scrolling disabled
- Screenshots to `~/Desktop/screenshots`
- Desktop stacks enabled

## Updating

To update packages:

```bash
brewup  # alias for: brew update && brew upgrade && brew cleanup
```

## Backup

The installation script automatically backs up existing files before symlinking.

## Notes

- Tested on macOS (Apple Silicon)
- All scripts use `set -euo pipefail` for robust error handling
- Some macOS defaults changes require logout/restart
