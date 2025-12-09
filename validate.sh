#!/bin/bash
# Local validation script for dotfiles
# Run before committing: ./validate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

echo "=== Dotfiles Validation ==="
echo

# 1. Shellcheck
echo "Checking shell scripts with shellcheck..."
if command -v shellcheck &> /dev/null; then
    while IFS= read -r -d '' script; do
        if shellcheck -e SC1091 "$script" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $script"
        else
            echo -e "  ${RED}✗${NC} $script"
            ERRORS=$((ERRORS + 1))
        fi
    done < <(find . -name "*.sh" -type f ! -path "./.git/*" -print0)
else
    echo -e "  ${YELLOW}⚠ shellcheck not installed (brew install shellcheck)${NC}"
fi
echo

# 2. Check for set -euo pipefail in scripts
echo "Checking error handling (set -euo pipefail)..."
while IFS= read -r -d '' script; do
    if grep -q "set -euo pipefail" "$script"; then
        echo -e "  ${GREEN}✓${NC} $script has full error handling"
    elif grep -q "set -e" "$script"; then
        echo -e "  ${YELLOW}⚠${NC} $script has basic error handling (consider 'set -euo pipefail')"
    else
        echo -e "  ${YELLOW}⚠${NC} $script missing error handling"
    fi
done < <(find . -name "*.sh" -type f ! -path "./.git/*" -print0)
echo

# 3. Validate JSON
echo "Validating JSON files..."
while IFS= read -r -d '' json; do
    if python3 -m json.tool "$json" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $json"
    else
        echo -e "  ${RED}✗${NC} $json - invalid JSON"
        ERRORS=$((ERRORS + 1))
    fi
done < <(find . -name "*.json" -type f ! -path "./.git/*" -print0)
echo

# 4. Brewfile syntax
echo "Validating Brewfile..."
if [ -f "homebrew/Brewfile" ]; then
    if ruby -c homebrew/Brewfile > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Brewfile syntax valid"
    else
        echo -e "  ${RED}✗${NC} Brewfile syntax error"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo

# 5. Check for potential secrets
echo "Scanning for potential secrets..."
SECRETS_FOUND=0
while IFS= read -r -d '' file; do
    # Look for common secret patterns
    if grep -qE "(api_key|apikey|secret|password|token).*=.*['\"][^'\"]+['\"]" "$file" 2>/dev/null; then
        if [[ ! "$file" =~ \.example$ ]] && [[ ! "$file" =~ README ]]; then
            echo -e "  ${YELLOW}⚠${NC} Potential secret in: $file"
            SECRETS_FOUND=1
        fi
    fi
done < <(find . -type f ! -path "./.git/*" ! -name "*.backup*" ! -name "*.jpg" ! -name "*.png" -print0)
if [ $SECRETS_FOUND -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} No obvious secrets found"
fi
echo

# 6. Check symlink targets exist
echo "Checking symlink targets..."
SYMLINK_COUNT=0
for script in install.sh ssh/install.sh; do
    if [ -f "$script" ]; then
        # Extract ln -sf targets from install scripts
        # shellcheck disable=SC2016
        while IFS= read -r target; do
            if [ -n "$target" ] && [ -e "$target" ]; then
                echo -e "  ${GREEN}✓${NC} $target exists"
                SYMLINK_COUNT=$((SYMLINK_COUNT + 1))
            elif [ -n "$target" ]; then
                echo -e "  ${RED}✗${NC} $target missing"
                ERRORS=$((ERRORS + 1))
            fi
        done < <(grep -oE '\$SCRIPT_DIR/[^"]+' "$script" 2>/dev/null | sed 's/\$SCRIPT_DIR\///' || true)
    fi
done
if [ $SYMLINK_COUNT -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} No issues detected"
fi
echo

# Summary
echo "=== Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS error(s) found${NC}"
    exit 1
fi
