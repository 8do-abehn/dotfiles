---
name: jellyfin-kids
description: Control what the kids can watch on Jellyfin (jellyfin01). Covers auditing the `kids` and `littles` profiles, hiding or allowing a title by giving it a rating, re-applying ratings after files move or get published, and changing a profile's cap, schedule or libraries. Use when the user asks what the kids can see, wants something hidden from or shown to the kids, asks why a kid could see a title, mentions the kids' Jellyfin profiles, bedtime or parental controls, or after moving, renaming or publishing files in the Jellyfin library (riplab, borrowed/).
argument-hint: [audit | hide <title> | allow <title> | after-move | why <profile> <title> | profile <name>]
allowed-tools: Bash(~/.claude/skills/jellyfin-kids/jf.py:*), Bash(~/8do/riplab/bin/jellyfin_ratings.sh:*), Bash(~/8do/riplab/bin/jellyfin_kids_audit.sh:*)
---

# Jellyfin kids profiles

jellyfin01 (`http://10.150.70.14:8096`) hides titles from the kids **by parental rating
alone**. The source of truth is riplab's `docs/jellyfin-ratings.json`, and the full
background is `docs/jellyfin-kids.md` in `~/8do/riplab`. Read it if anything here is unclear.

| Profile | Cap | Unrated | Schedule |
|---|---|---|---|
| `kids` (older kids) | PG / TV-PG (10) | blocked | 6am–7:30pm |
| `littles` (youngest) | G / TV-Y7 (7) | blocked | 6am–7pm |
| `barbie` (grandparent) | none | shown | none. **Unrestricted on purpose. Never "fix" it.** |

So a rating in the JSON means: **G = both see it, PG = `kids` only, PG-13 or higher = neither.**
Unrated is hidden from both, which is the safe default for new rips.

## Tools

- `~/.claude/skills/jellyfin-kids/jf.py`: read-only lookups
  - `find <text>`: exact name, year, rating and path (use these exact values in the JSON)
  - `sees <profile> <text>`: visible or hidden, and why
  - `policy <profile>`: cap, unrated blocks, schedule, libraries
- `~/8do/riplab/bin/jellyfin_ratings.sh [--dry-run]`: sets and locks every rating in the
  JSON, including every season and episode of a series. Idempotent.
- `~/8do/riplab/bin/jellyfin_kids_audit.sh --no-notify`: read-only report into
  `~/Documents/jellyfin-audit/YYYY-MM-DD.md`. Point `AUDIT_STATE_DIR`/`AUDIT_REPORT_DIR` at
  the scratchpad for ad-hoc runs, so the monthly "new since last audit" baseline is left alone.

If `~/8do/riplab/bin/jellyfin_ratings.sh` doesn't exist, PR #99 isn't merged yet. Use the
`~/8do/riplab-kids` worktree, which holds that branch.

## Workflows

**audit:** run the audit and summarize. Problems first, then "Unrated and not in the JSON":
offer a suggested rating for each one so the user only has to correct you.

**hide / allow a title:**
1. `jf.py find` to get the exact type, name and year.
2. Suggest a rating with a one-line reason (hide = PG-13, or keep a higher real rating
   such as R; `kids` only = PG; both = G). Ask only if it's genuinely unclear.
3. Add or edit one line in `docs/jellyfin-ratings.json`: one title per line, with `was` set to
   the current rating and a short `why`.
4. `jellyfin_ratings.sh --dry-run`, then apply, then `jf.py sees` for both profiles.
5. Commit on a branch and open a PR. Never commit to main.

**after-move:** after any move, rename or publish, run `jellyfin_ratings.sh` (dry run first,
and show the count), then the audit. Moves are what break this; see below.

**why can a kid see X:** run `jf.py sees <profile> X`. If an *episode* leaks, the series is
missing from the JSON or its episodes kept their own lower rating: add the series and
re-run the ratings script.

**change a profile:** back up the policy JSON to the scratchpad, change only the field asked
for, and POST the whole policy to `/Users/{id}/Policy`. Then update `EXPECT` in
`jellyfin_kids_audit.sh` and the table in `docs/jellyfin-kids.md` in the same PR, or every
audit will flag it.

## Gotchas (each one has bitten before)

- **Moves wipe ratings.** Jellyfin keys items by file path and keeps ratings, locks and tags
  only in its database. The 2026-11-19 move of 1,312 files into `borrowed/` re-exposed the
  pre-Code cartoons for a week. Ratings live in the JSON, never only in the UI.
- **An episode's own rating beats its series'.** *The Office* is TV-14, but its TV-PG episodes
  were visible to `kids`. The ratings script rates every episode, so add the series to the JSON.
- **The bulk `/Items` listing can be stale** right after a save. Confirm with a single-item
  read, `/Users/{adminId}/Items/{id}`, or with `jf.py sees`.
- **Never lower a real rating** to hide something (Evil Dead Collection stays R). Raise only.
- **Keep the API key off command lines.** The scripts read `~/.api_jellyfin` and pass it in a
  curl config file or request header. Never echo it. If it's missing or revoked, ask the
  user to create one under Dashboard → API Keys and save it themselves.
- **The `no-kids` tag is retired.** Don't add tags or BlockedTags.
- **Don't move files to fix visibility.** Moving is what caused the problem.
