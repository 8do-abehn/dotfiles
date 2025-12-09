#!/bin/bash
set -euo pipefail

# Set Desktop Background Script
# Run with: bash ~/8do/dotfiles/macos/set-desktop.sh [image-name]

DESKTOPS_DIR="$HOME/8do/dotfiles/desktops"

# Check if desktops directory exists
if [[ ! -d "$DESKTOPS_DIR" ]]; then
    echo "Error: Desktops directory not found at $DESKTOPS_DIR"
    exit 1
fi

# If image name provided, use it; otherwise list available images
if [[ -n "$1" ]]; then
    IMAGE_NAME="$1"
    IMAGE_PATH="$DESKTOPS_DIR/$IMAGE_NAME"

    if [[ ! -f "$IMAGE_PATH" ]]; then
        echo "Error: Image '$IMAGE_NAME' not found in $DESKTOPS_DIR"
        echo ""
        echo "Available images:"
        ls -1 "$DESKTOPS_DIR"
        exit 1
    fi
else
    # List available images and prompt
    echo "Available desktop images:"
    echo ""
    ls -1 "$DESKTOPS_DIR"
    echo ""
    read -rp "Enter image filename: " IMAGE_NAME
    IMAGE_PATH="$DESKTOPS_DIR/$IMAGE_NAME"

    if [[ ! -f "$IMAGE_PATH" ]]; then
        echo "Error: Image not found"
        exit 1
    fi
fi

# Set desktop background for all displays
echo "Setting desktop background to: $IMAGE_NAME"

osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$IMAGE_PATH\""

echo "Desktop background set successfully ✓"
