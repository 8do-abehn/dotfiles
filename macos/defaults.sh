#!/bin/bash

# macOS defaults configuration
# Run with: bash ~/8do/dotfiles/macos/defaults.sh

echo "Configuring macOS defaults..."

# Scroll direction (natural scrolling disabled)
# Set to true for natural scrolling, false for traditional
defaults write -g com.apple.swipescrolldirection -bool false

# Screenshot location (change as needed)
defaults write com.apple.screencapture location -string "${HOME}/Desktop/screenshots"

# Screenshot format (options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture type -string "png"

# Desktop - Use Stacks
defaults write com.apple.desktop use-stacks -bool true

echo "macOS defaults configured!"
echo "Note: Some changes may require logout/restart to take effect."
echo ""
echo "Restarting affected applications..."

killall Finder
killall Dock
killall SystemUIServer

echo "Done!"
