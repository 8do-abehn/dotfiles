#!/bin/bash
# Dotfiles status checker
# Run with: ./status.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ISSUES=0

echo "=== Dotfiles Status ==="
echo

# Helper function to check a symlink
check_symlink() {
    local target="$1"
    local expected="$2"
    local name="$3"

    if [[ -L "$target" ]]; then
        actual=$(readlink "$target")
        if [[ "$actual" == "$expected" ]]; then
            echo -e "  ${GREEN}✓${NC} $name"
        else
            echo -e "  ${YELLOW}⚠${NC} $name -> $actual (expected $expected)"
            ISSUES=$((ISSUES + 1))
        fi
    elif [[ -e "$target" ]]; then
        echo -e "  ${RED}✗${NC} $name exists but is not a symlink"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "  ${RED}✗${NC} $name missing"
        ISSUES=$((ISSUES + 1))
    fi
}

# 1. Check symlinks
echo "Checking symlinks..."
# shellcheck disable=SC2088
check_symlink "$HOME/.zshrc" "$SCRIPT_DIR/zsh/.zshrc" '~/.zshrc'
# shellcheck disable=SC2088
check_symlink "$HOME/.claude/CLAUDE.md" "$SCRIPT_DIR/claude/CLAUDE.md" '~/.claude/CLAUDE.md'
# shellcheck disable=SC2088
check_symlink "$HOME/.claude/settings.json" "$SCRIPT_DIR/claude/settings.json" '~/.claude/settings.json'
# shellcheck disable=SC2088
check_symlink "$HOME/.ssh/config" "$SCRIPT_DIR/ssh/config" '~/.ssh/config'
echo

# 2. Check SwiftBar plugins
echo "Checking SwiftBar plugins..."
SWIFTBAR_DIR="$HOME/swiftbar"
if [[ -d "$SWIFTBAR_DIR" ]]; then
    while IFS= read -r -d '' plugin; do
        plugin_name=$(basename "$plugin")
        check_symlink "$SWIFTBAR_DIR/$plugin_name" "$plugin" "$plugin_name"
    done < <(find "$SCRIPT_DIR/swiftbar" -name "*.sh" -print0)
else
    echo -e "  ${YELLOW}⚠${NC} SwiftBar directory not found ($SWIFTBAR_DIR)"
fi
echo

# 3. Check Homebrew packages
echo "Checking Homebrew packages..."
if command -v brew &> /dev/null; then
    if [[ -f "$SCRIPT_DIR/homebrew/Brewfile" ]]; then
        if brew bundle check --file="$SCRIPT_DIR/homebrew/Brewfile" &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} All packages installed"
        else
            echo -e "  ${YELLOW}⚠${NC} Some packages missing:"
            brew bundle check --file="$SCRIPT_DIR/homebrew/Brewfile" 2>&1 | grep -v "^Homebrew" | head -10 | sed 's/^/      /'
        fi
    else
        echo -e "  ${RED}✗${NC} Brewfile not found"
    fi
else
    echo -e "  ${RED}✗${NC} Homebrew not installed"
fi
echo

# 4. Check pre-commit hooks
echo "Checking pre-commit hooks..."
if command -v pre-commit &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} pre-commit installed"
    if [[ -f "$SCRIPT_DIR/.git/hooks/pre-commit" ]] && grep -q "pre-commit" "$SCRIPT_DIR/.git/hooks/pre-commit" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} hooks installed in repo"
    else
        echo -e "  ${YELLOW}⚠${NC} hooks not installed (run: pre-commit install)"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} pre-commit not installed (run: brew install pre-commit)"
fi
echo

# 5. Check shellcheck
echo "Checking development tools..."
if command -v shellcheck &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} shellcheck installed"
else
    echo -e "  ${YELLOW}⚠${NC} shellcheck not installed (run: brew install shellcheck)"
fi
echo

# 6. Check Git config
echo "Checking Git configuration..."
GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
GIT_SIGNING=$(git config --global commit.gpgsign 2>/dev/null || echo "false")

if [[ -n "$GIT_NAME" ]]; then
    echo -e "  ${GREEN}✓${NC} user.name: $GIT_NAME"
else
    echo -e "  ${RED}✗${NC} user.name not set"
fi

if [[ -n "$GIT_EMAIL" ]]; then
    echo -e "  ${GREEN}✓${NC} user.email: $GIT_EMAIL"
else
    echo -e "  ${RED}✗${NC} user.email not set"
fi

if [[ "$GIT_SIGNING" == "true" ]]; then
    echo -e "  ${GREEN}✓${NC} commit signing enabled"
else
    echo -e "  ${YELLOW}⚠${NC} commit signing not enabled"
fi
echo

# Summary
echo "=== Summary ==="
if [[ $ISSUES -eq 0 ]]; then
    echo -e "${GREEN}All checks passed!${NC}"
else
    echo -e "${YELLOW}$ISSUES issue(s) found${NC}"
    echo "Run ./install.sh to fix symlinks"
fi
