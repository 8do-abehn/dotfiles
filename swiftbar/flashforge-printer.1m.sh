#!/bin/bash
set -euo pipefail
#
# <xbar.title>Flashforge Printer Status</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.desc>Shows Adventurer 5M print progress and notifies when a print ends</xbar.desc>
# <xbar.dependencies>nc</xbar.dependencies>
#
# Refreshes every minute (the .1m in the filename).
#
# The printer address lives outside the repo so no LAN IPs get committed:
#   echo 'PRINTER_HOST=<printer ip>' > ~/.config/swiftbar/flashforge-printer.conf

CONF="$HOME/.config/swiftbar/flashforge-printer.conf"
STATE_DIR="${SWIFTBAR_PLUGIN_CACHE_PATH:-$HOME/Library/Caches/flashforge-printer}"
STATE_FILE="$STATE_DIR/last_status"
PORT=8899

PRINTER_HOST=""
# shellcheck source=/dev/null
[[ -f "$CONF" ]] && source "$CONF"

if [[ -z "$PRINTER_HOST" ]]; then
    echo "🖨 ?"
    echo "---"
    echo "Set PRINTER_HOST in $CONF"
    exit 0
fi

# Flashforge's legacy LAN protocol: "~<gcode>\r\n" over TCP 8899. The printer only
# answers the first command per connection, so each query gets its own connection.
# These are read-only queries; no M601 control handshake is needed for them.
query() {
    printf '~%s\r\n' "$1" | nc -G 3 -w 3 "$PRINTER_HOST" "$PORT" 2>/dev/null | tr -d '\r' || true
}

field() {
    # print the value after "Key:" from the response text
    sed -n "s/^$1: *//p" <<<"$2" | head -1
}

status_raw=$(query M119)
if [[ -z "$status_raw" ]]; then
    echo "🖨 off | color=gray"
    echo "---"
    echo "No answer from $PRINTER_HOST:$PORT (asleep or powered off)"
    exit 0
fi

machine=$(field MachineStatus "$status_raw")
file=$(field CurrentFile "$status_raw")
progress_raw=$(query M27)
temps=$(query M105 | grep '^T0' || true)

# "SD printing byte 42/100" is already a percentage
pct=$(sed -n 's/^SD printing byte \([0-9]*\)\/.*/\1/p' <<<"$progress_raw")
layer=$(field Layer "$progress_raw")
nozzle=$(sed -n 's/^T0:\([0-9.]*\)\/\([0-9.]*\).*/\1°\/\2°/p' <<<"$temps")
bed=$(sed -n 's/.*B:\([0-9.]*\)\/\([0-9.]*\).*/\1°\/\2°/p' <<<"$temps")

# Notify once when a print stops being a print. The previous status is cached so a
# finished print notifies on the transition, not on every refresh afterwards.
mkdir -p "$STATE_DIR"
last=$(cat "$STATE_FILE" 2>/dev/null || true)
echo "$machine" > "$STATE_FILE"
if [[ "$last" == "BUILDING_FROM_SD" && "$machine" != "BUILDING_FROM_SD" ]]; then
    osascript -e "display notification \"${file:-print} is now ${machine}\" with title \"Printer\" sound name \"Glass\"" || true
fi

case "$machine" in
    BUILDING_FROM_SD) echo "🖨 ${pct:-?}% · L${layer:-?}" ;;
    READY)            echo "🖨 idle | color=gray" ;;
    *)                echo "🖨 ${machine} | color=orange" ;;
esac

echo "---"
echo "Status: $machine"
[[ -n "$file" ]]   && echo "File: $file"
[[ -n "$pct" ]]    && echo "Progress: ${pct}%"
[[ -n "$layer" ]]  && echo "Layer: $layer"
[[ -n "$nozzle" ]] && echo "Nozzle: $nozzle"
[[ -n "$bed" ]]    && echo "Bed: $bed"
echo "---"
echo "Refresh | refresh=true"
