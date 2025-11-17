#!/bin/bash
#
# <xbar.title>Claude API Usage</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Your Name</xbar.author>
# <xbar.author.github>yourusername</xbar.author.github>
# <xbar.desc>Displays Claude API rate limit info</xbar.desc>
# <xbar.dependencies>curl,jq</xbar.dependencies>
#
# Metadata tells SwiftBar/xbar to refresh every 5 minutes

# ============================================================
# CONFIGURATION - API Key Setup (Choose ONE method)
# ============================================================
#
# METHOD 1 (Recommended): macOS Keychain
# Run this command once to store your API key securely:
#   security add-generic-password -a "${USER}" -s "anthropic-api-key" -w
# Then use this line (already uncommented):
API_KEY=$(security find-generic-password -a "${USER}" -s "anthropic-api-key" -w 2>/dev/null)
#
# METHOD 2: Hardcoded (less secure, easier for testing)
# Uncomment and add your key:
# API_KEY="sk-ant-your-api-key-here"
#
# METHOD 3: Environment variable
# Set ANTHROPIC_API_KEY in your shell environment, then uncomment:
# API_KEY="${ANTHROPIC_API_KEY}"
#
# ============================================================

if [ "$API_KEY" = "your-api-key-here" ] || [ -z "$API_KEY" ]; then
    echo "⚠️ Configure API key"
    echo "---"
    echo "Edit script to add your Anthropic API key"
    echo "Path: $0"
    exit 0
fi

# Make minimal API request to get rate limit headers
# Using a very small request to minimize token usage
RESPONSE=$(curl -s -i -X POST https://api.anthropic.com/v1/messages \
    -H "x-api-key: $API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d '{
        "model": "claude-3-5-haiku-20241022",
        "max_tokens": 1,
        "messages": [{"role": "user", "content": "hi"}]
    }' 2>&1)

# Check if request failed
if [ $? -ne 0 ]; then
    echo "❌ API Error"
    echo "---"
    echo "Failed to connect to Anthropic API"
    exit 1
fi

# Extract rate limit headers (case-insensitive)
TOKENS_LIMIT=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-tokens-limit:" | head -1 | awk '{print $2}' | tr -d '\r')
TOKENS_REMAINING=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-tokens-remaining:" | head -1 | awk '{print $2}' | tr -d '\r')
TOKENS_RESET=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-tokens-reset:" | head -1 | awk '{print $2}' | tr -d '\r')

REQUESTS_LIMIT=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-requests-limit:" | head -1 | awk '{print $2}' | tr -d '\r')
REQUESTS_REMAINING=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-requests-remaining:" | head -1 | awk '{print $2}' | tr -d '\r')
REQUESTS_RESET=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-requests-reset:" | head -1 | awk '{print $2}' | tr -d '\r')

# Check if we got valid data
if [ -z "$TOKENS_REMAINING" ]; then
    echo "❌ No data"
    echo "---"
    echo "Could not parse rate limits"
    echo "Check API key validity"
    exit 1
fi

# Calculate percentages
TOKENS_PERCENT=$((TOKENS_REMAINING * 100 / TOKENS_LIMIT))
REQUESTS_PERCENT=$((REQUESTS_REMAINING * 100 / REQUESTS_LIMIT))

# Choose emoji based on remaining percentage
if [ "$TOKENS_PERCENT" -gt 50 ]; then
    EMOJI="🟢"
elif [ "$TOKENS_PERCENT" -gt 20 ]; then
    EMOJI="🟡"
else
    EMOJI="🔴"
fi

# Format numbers with commas for readability
format_number() {
    printf "%'d" "$1" 2>/dev/null || echo "$1"
}

TOKENS_REMAINING_FMT=$(format_number "$TOKENS_REMAINING")
TOKENS_LIMIT_FMT=$(format_number "$TOKENS_LIMIT")
REQUESTS_REMAINING_FMT=$(format_number "$REQUESTS_REMAINING")
REQUESTS_LIMIT_FMT=$(format_number "$REQUESTS_LIMIT")

# Calculate reset time in human-readable format
if [ -n "$TOKENS_RESET" ]; then
    RESET_DATE=$(date -r "$TOKENS_RESET" "+%H:%M:%S" 2>/dev/null || echo "Unknown")
else
    RESET_DATE="Unknown"
fi

# Menu bar output (first line)
echo "$EMOJI ${TOKENS_PERCENT}%"

# Dropdown menu (after ---)
echo "---"
echo "Tokens: ${TOKENS_REMAINING_FMT} / ${TOKENS_LIMIT_FMT} (${TOKENS_PERCENT}%)"
echo "Requests: ${REQUESTS_REMAINING_FMT} / ${REQUESTS_LIMIT_FMT} (${REQUESTS_PERCENT}%)"
echo "Resets at: ${RESET_DATE}"
echo "---"
echo "Refresh | refresh=true"
echo "Console | href=https://console.anthropic.com"
