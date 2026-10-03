# SwiftBar Plugins

SwiftBar plugins for macOS menu bar widgets.

## Setup

1. **Install SwiftBar:**
   ```bash
   brew install swiftbar
   ```

2. **Create symlinks:**
   ```bash
   ln -sf ~/8do/dotfiles/swiftbar/claude-usage.5m.sh ~/swiftbar/claude-usage.5m.sh
   ln -sf ~/8do/dotfiles/swiftbar/flashforge-printer.1m.sh ~/swiftbar/flashforge-printer.1m.sh
   ```

3. **Configure API key** (one-time setup):
   ```bash
   # This will prompt you to enter your Anthropic API key securely
   security add-generic-password -a "${USER}" -s "anthropic-api-key" -w
   ```

4. **Set SwiftBar plugin folder:**
   - Open SwiftBar preferences
   - Set plugin folder to: `~/swiftbar`

## Plugins

### claude-usage.5m.sh
Displays Claude API rate limit information in the menu bar.

- Shows token/request usage percentage
- Green/yellow/red indicator based on remaining quota
- Refreshes every 5 minutes
- Click for detailed view

**Requirements:**
- Anthropic API key stored in macOS Keychain (see setup step 3)
- Internet connection

**To update refresh rate:**
Rename file: `.5m.sh` = 5 minutes, `.1m.sh` = 1 minute, etc.

### flashforge-printer.1m.sh
Shows Flashforge Adventurer 5M print status in the menu bar.

- Menu bar: `🖨 42% · L105/250` while printing, `idle` or `off` otherwise
- Dropdown: file name, progress, layer, nozzle and bed temps
- macOS notification when a print finishes or stops
- Refreshes every minute, read-only queries over the printer's LAN port 8899

**Setup** (keeps the printer IP out of the repo):
```bash
mkdir -p ~/.config/swiftbar && echo 'PRINTER_HOST=<printer ip>' > ~/.config/swiftbar/flashforge-printer.conf
```
