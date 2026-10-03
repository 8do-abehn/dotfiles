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

3. **Set SwiftBar plugin folder:**
   - Open SwiftBar preferences
   - Set plugin folder to: `~/swiftbar`

## Plugins

### claude-usage.5m.sh
Shows Claude Code usage for the current 5-hour block, read from Claude Code's
local logs (`~/.claude/projects`) by [ccusage](https://github.com/ryoppippi/ccusage).

- Menu bar: `✳ $32.26 · 3h13m` (block cost so far, time until it resets), or `✳ idle`
- Dropdown: block window, projected cost and burn rate, token breakdown, models
- No API key, no API calls, no network (`--offline` uses ccusage's bundled prices)
- Refreshes every 5 minutes

The dollar figure is what those tokens would cost at API prices, not a bill.
Anthropic doesn't publish Pro/Max plan limits, so this can't show a percentage of
your plan; run `/usage` inside Claude Code for that.

Caveats: ccusage starts each block on the hour, so the reset time is an estimate.
A model newer than ccusage's bundled price table is counted as $0 until you
`brew upgrade ccusage`.

**Requirements:** `ccusage` (in the Brewfile: `brew install ccusage`)

The old version of this plugin read an API key from the Keychain. If an old
machine still has that entry, remove it with
`security delete-generic-password -a "${USER}" -s anthropic-api-key`.

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
