---
name: sense
description: Check the home Sense energy monitor - live power draw, what's on right now, daily/weekly/monthly kWh, per-device usage, always-on baseline, recent device events. Use when the user asks about electricity use, power draw, energy usage, what's running, what uses the most power, or mentions Sense.
argument-hint: [now | usage day|week|month|year | devices | device <name> | always-on | timeline | status]
allowed-tools: Bash(~/.claude/skills/sense/sense.py:*)
---

# Sense energy monitor

Read-only access to the user's Sense monitor through the unofficial cloud API
(`sense_energy` Python library). There is no official or local API, so data comes
from `api.sense.com`, and a fair amount of it is Sense's own device-detection guesses.

## Running it

Always call the script by this exact path (uv installs the dependency on first run):

```
~/.claude/skills/sense/sense.py <command>
```

All commands print JSON.

| Command | Returns |
|---|---|
| `now` | live watts, solar watts, voltage per leg, Hz, devices currently on with watts |
| `usage [day\|week\|month\|year\|cycle] [--date YYYY-MM-DD] [--top N]` | kWh total (plus solar/grid split if solar exists) and per-device kWh for that period |
| `devices` | every discovered device: id, name, tags, last state |
| `device <name-or-id>` | detail for one device (name matches as substring) |
| `always-on` | always-on baseline |
| `timeline [-n 30]` | recent on/off events |
| `status` | monitor overview, wifi signal, detection progress |
| `raw <path>` | GET any API path; `{monitor}` and `{user}` are filled in |

If the user passed an argument to `/sense`, run that command. With no argument, run
`now` and `usage day`, then summarize.

## Login is the user's job, never yours

If a command exits 2 with "not logged in" or "auth failed", stop and ask the user to
run this in their own terminal (it prompts for email, password and MFA code):

```
~/.claude/skills/sense/sense.py login
```

Or pull credentials from Bitwarden after `export BW_SESSION=$(bw unlock --raw)`:

```
~/.claude/skills/sense/sense.py login --bw <item-name>
```

Never ask for, type, or pass the Sense password yourself. Tokens are cached in
`~/.config/sense/auth.json` (mode 0600) and refresh themselves; never print or
`cat` that file.

## Reading the numbers

- Report watts as W or kW and energy as kWh. Put numbers in context: a typical US
  home averages about 1.2 kW (roughly 29 kWh/day).
- **"Other"** is power Sense hasn't attributed to a detected device. It's usually the
  biggest bucket; say so rather than treating it as one appliance.
- **"Always On"** is the baseline that never turns off (networking, standby, and here
  probably homelab gear). It's a good lever for savings, so call it out when it's large.
- Device names are Sense's guesses ("Motor 3", "Heat 2") unless the user renamed them.
  Don't claim a device is definitely what its name says.
- Sense rate-limits realtime to about once a minute. Don't poll `now` in a tight loop.
  For a trend, use `usage` or `timeline` instead.
- `raw "app/monitors/{monitor}/history/usage?scale=MONTH&start=..."` does NOT reliably
  honor past `start` dates: requests for March/April returned May or September data.
  Always check the `start` field in the response before trusting it. `scale=YEAR` with
  a Jan 1 start works and gives per-device monthly totals in `device_breakdown`.
- Device models are learned from specific appliances. After an appliance is replaced,
  its old device goes quiet and the new one's energy lands in "Other" or a wrong device.
- The API is unofficial and can change. On unexpected errors or empty fields, show
  the raw error and try `raw` against the endpoint before guessing at a cause.
