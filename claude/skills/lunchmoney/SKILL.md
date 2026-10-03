---
name: lunchmoney
description: Read the user's Lunch Money budget - transactions, spending by category, budget vs actual, account balances, recurring bills, uncategorized or unreviewed transactions. Use when the user asks about spending, budget, money, bills, subscriptions, account balances, what they spent on something, or mentions Lunch Money.
argument-hint: [spending | budget | transactions | accounts | recurring] [--month YYYY-MM]
allowed-tools: Bash(~/.claude/skills/lunchmoney/lunchmoney.py:*)
---

# Lunch Money

Read-only access to the user's Lunch Money budget through the official v2 API
(`https://api.lunchmoney.dev/v2`, docs at https://lunchmoney.dev). The script only
ever sends GET requests, so it cannot change, categorize or delete anything. That's
deliberate: Lunch Money API tokens always have full write access, so this script is
the only thing keeping it read-only. Don't work around it with curl.

## Running it

Always call the script by this exact path. Every command prints JSON.

```
~/.claude/skills/lunchmoney/lunchmoney.py <command> [options]
```

| Command | Returns |
|---|---|
| `spending [range] [--by-group]` | spent and income per category, largest first |
| `budget [range]` | budgeted vs activity vs available per category |
| `transactions [range] [filters] [--limit N]` | transactions with category/account/tag names filled in |
| `accounts [--all]` | Plaid and manual accounts with balances (`--all` adds closed) |
| `recurring [range]` | recurring bills and income, with expected and missing dates |
| `categories`, `tags`, `me` | lookups; `me` shows budget name and primary currency |
| `raw <path> [-p key=value ...]` | GET any v2 path not wrapped above |

**Range** (any command that takes one): `--month 2026-09`, or `--start`/`--end` as
YYYY-MM-DD. With no range, `budget` and `recurring` use the current month and
`transactions`/`spending` use the last 30 days.

**Filters** (`transactions` and `spending`): `--category` (name, id, or
`uncategorized`), `--tag`, `--account` (name or institution substring), `--payee`
(substring, also matches the raw bank text), `--status reviewed|unreviewed`,
`--pending` (pending transactions are excluded unless this is set).

If the user passed an argument to `/lunchmoney`, run that command. With no argument,
run `spending` and `budget` for the current month, then summarize.

`--mock` (or `LUNCHMONEY_MOCK=1`) uses Lunch Money's demo server: fake data, no token.
Use it for testing the script, never to answer a question about the user's money.
Output from it carries `"mock_data": true`.

## Login is the user's job, never yours

If a command exits 2 with "not logged in" or "401", stop and ask the user to run
this in their own terminal (it prompts for the token without echoing it):

```
~/.claude/skills/lunchmoney/lunchmoney.py login
```

Or from Bitwarden, after `export BW_SESSION=$(bw unlock --raw)`, with the token in
the item's password field:

```
~/.claude/skills/lunchmoney/lunchmoney.py login --bw <item-name>
```

Tokens are created at https://my.lunchmoney.app/developers. Never ask for, type, or
pass the token yourself. It's stored in `~/.config/lunchmoney/token` (mode 0600);
never print or `cat` that file. `LUNCHMONEY_TOKEN` in the environment overrides it.

## Reading the numbers

- **Sign convention: positive = money out, negative = money in**, whatever the
  user's display setting is. `spending` already splits these into `spending` and
  `income` with positive amounts.
- Use `spending` for "how much did I spend". It skips categories marked "exclude from
  totals" (transfers, credit card payments), split parents, group children and
  delete-pending rows, so nothing is double counted. The `sum_debits`/`sum_credits`
  on `transactions` are raw sums of every row matched, transfers included.
- Totals use `to_base` (converted to the primary currency). Per-transaction `amount`
  is in that transaction's own `currency`.
- `budget` comes from Lunch Money's own summary. `activity` is the category's net
  spending. A negative `available` means over budget. A `null` budgeted means no
  budget is set for that category.
- Recurring items' `missing_dates` are expected charges with no matching transaction
  yet. That's normal for future dates; only call out past ones.
- Rate limit is 100 requests/min. One command is at most a few requests, but don't
  loop over months one call at a time when a single `--start`/`--end` range works.
- `transactions` caps output at `--limit` (default 200) but `count` and the sums
  cover everything matched. For big ranges prefer `spending`, or narrow with filters.
- The v2 API still changes (breaking renames happened in early 2026). On an
  unexpected error or missing field, show the raw error and try `raw` against the
  endpoint before guessing. The spec is at https://lunchmoney.dev/v2/openapi.
