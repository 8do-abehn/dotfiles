#!/bin/bash
set -euo pipefail
#
# <xbar.title>Claude Code Usage</xbar.title>
# <xbar.version>v2.0</xbar.version>
# <xbar.desc>Shows the current Claude Code 5-hour usage block from local logs</xbar.desc>
# <xbar.dependencies>ccusage,jq</xbar.dependencies>
#
# Refreshes every 5 minutes (the .5m in the filename).
#
# Reads Claude Code's own logs (~/.claude/projects) through ccusage, so it needs
# no API key, makes no API calls and costs nothing. The dollar figure is what the
# tokens would cost at API prices, not a bill; plan limits aren't published, so
# /usage inside Claude Code is the only place to see a percentage of your plan.

# SwiftBar starts plugins with a bare PATH that misses Homebrew. Appended rather
# than prepended so an existing PATH entry still wins.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

if ! command -v ccusage >/dev/null; then
    echo "✳ ?"
    echo "---"
    echo "ccusage not found: brew install ccusage"
    exit 0
fi

# --offline uses ccusage's bundled price table so a refresh never waits on a
# pricing download. stderr is kept apart so warnings can't corrupt the JSON.
err=$(mktemp)
trap 'rm -f "$err"' EXIT
if ! json=$(ccusage blocks --active --json --offline 2>"$err"); then
    echo "✳ ! | color=red"
    echo "---"
    echo "ccusage failed:"
    # each line of the message becomes a plain menu item
    head -5 "$err" | tr -d '|'
    exit 0
fi

# One tab-separated line per active block. Model names come from log files, so
# they're reduced to safe characters before SwiftBar sees them.
if ! block=$(jq -r '
    .blocks[0] // empty
    | [
        .costUSD,
        ((.endTime | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) - now | floor),
        (.startTime | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601),
        (.endTime | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601),
        .tokenCounts.inputTokens // 0,
        .tokenCounts.outputTokens // 0,
        .tokenCounts.cacheCreationInputTokens // 0,
        .tokenCounts.cacheReadInputTokens // 0,
        (.burnRate.costPerHour // 0),
        (.projection.totalCost // .costUSD),
        (.models | map(select(. != "<synthetic>") | gsub("[^A-Za-z0-9.-]"; "")) | join(" "))
      ]
    | @tsv' <<<"$json" 2>/dev/null); then
    echo "✳ ! | color=red"
    echo "---"
    echo "Couldn't parse ccusage output"
    exit 0
fi

if [[ -z "$block" ]]; then
    echo "✳ idle | color=gray"
    echo "---"
    echo "No Claude Code activity in the last 5 hours"
    echo "---"
    echo "Refresh | refresh=true"
    exit 0
fi

IFS=$'\t' read -r cost secs_left start end input output cache_write cache_read \
    burn projected models <<<"$block"

# printf rounds, and %'d adds thousands separators, but only with a real locale;
# SwiftBar provides none, so name one here. It has to be a local variable: bash
# ignores a locale given as a one-command prefix to its builtin printf.
money() { printf '$%.2f' "$1"; }
count() { local LC_NUMERIC=en_US.UTF-8; printf "%'d" "$1"; }

secs_left=$(( secs_left > 0 ? secs_left : 0 ))
left="$((secs_left / 3600))h$(printf '%02d' $((secs_left % 3600 / 60)))m"

echo "✳ $(money "$cost") · $left"
echo "---"
echo "Block: $(date -r "$start" '+%H:%M')–$(date -r "$end" '+%H:%M') · resets in $left"
echo "Cost (API-price equivalent): $(money "$cost")"
echo "At current pace: $(money "$projected") by reset · $(money "$burn")/h"
echo "---"
echo "Input: $(count "$input") tokens"
echo "Output: $(count "$output") tokens"
echo "Cache write: $(count "$cache_write") tokens"
echo "Cache read: $(count "$cache_read") tokens"
echo "---"
echo "Models: ${models:-none}"
echo "---"
echo "Refresh | refresh=true"
