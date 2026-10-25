---
name: ffb-week
description: Weekly fantasy football high score post for the Yahoo league. Use when the user says /ffb-week, asks who had the high score this week, or wants the weekly FFB update for the Facebook group.
argument-hint: "[week number | recap]"
allowed-tools: Bash(cat ~/.config/ffb-week/*), Bash(~/.claude/skills/ffb-week/ffb-config.sh init), Bash(pbcopy), Bash(open -a "Brave Browser" *)
---

# Weekly FFB high score

Finds the week's high score in the Yahoo league, writes the Facebook post in
Adam's usual one-line style, and records the weekly payout in the season's Google
Sheet. The league ID, group URL, sheet ID and owner names live in
`~/.config/ffb-week/`, not in this repo, because the dotfiles repo is public.

## 1. Load the local config

```
cat ~/.config/ffb-week/config.env ~/.config/ffb-week/owners.tsv
```

- `config.env` has `YAHOO_LEAGUE_ID`, `FB_GROUP_URL`, `SHEET_ID` (this season's
  "FFB - Draft Party 'YY" sheet) and `WEEKLY_PAYOUT` (dollars per weekly win).
- `owners.tsv` maps the Yahoo team name to the name used in the post. Lines starting
  with `#` are comments. If a team is missing, use the Yahoo manager name and tell
  the user so they can add it.

If the config is missing, run `~/.claude/skills/ffb-week/ffb-config.sh init` to
create it from the templates, then ask the user to restore it from Bitwarden
(`ffb-config.sh restore`, which they run after `bw unlock`) or to give you the
league ID, group URL and sheet ID. A new season needs a new `SHEET_ID` and
`YAHOO_LEAGUE_ID`; check both in August.

## 2. Read the scores from Yahoo (Claude in Chrome)

Load the chrome-browser skill first. Open a new tab on
`https://football.fantasysports.yahoo.com/f1/<YAHOO_LEAGUE_ID>` (the user is
already signed in to Yahoo in Chrome), then run this with `javascript_tool`.
Replace `LEAGUE` with the league ID and `WEEK` with the week number the user asked
for, or `0` for the latest finished week.

```js
const league = LEAGUE, want = WEEK;
async function week(w) {
  const html = await fetch('/f1/' + league + '?matchup_week=' + w + '&module=matchups&lhst=matchups',
    {credentials: 'include'}).then(r => r.text());
  const d = new DOMParser().parseFromString(html, 'text/html');
  const rows = [];
  d.querySelectorAll('li.Linkable.Listitem').forEach(li => {
    // Leaf numbers per matchup: team A actual, A projected, team B actual, B projected
    const n = [...li.querySelectorAll('*')]
      .filter(e => e.children.length === 0 && /^\d+\.\d\d$/.test(e.textContent.trim()))
      .map(e => +e.textContent.trim());
    const t = [...new Set([...li.querySelectorAll('a')].map(a => a.textContent.trim())
      .filter(x => x && x !== 'View Matchup' && !/^[\d.]+$/.test(x)))];
    rows.push({team: t[0], score: n[0], opp: t[1], oppScore: n[2]},
              {team: t[1], score: n[2], opp: t[0], oppScore: n[0]});
  });
  return {final: html.includes('Final results'), rows: rows.sort((a, b) => b.score - a.score)};
}
let w = want, r;
if (w) { r = await week(w); }
else { for (w = 1; w <= 18; w++) { const x = await week(w); if (!x.final) break; r = x; } w -= 1; }
// The extension blocks output that looks like query strings, so keep = & ? out of it
('WEEK ' + w + (r.final ? ' FINAL' : ' NOT FINAL') + '\n' +
  r.rows.map(x => x.team + ' | ' + x.score + ' | vs ' + x.opp + ' ' + x.oppScore).join('\n'))
  .replace(/[=&?]/g, ' ')
```

Close the tab when done. If the asked-for week is NOT FINAL, say so and stop
(Monday night games or stat corrections can still change it).

Check the result: 14 teams, and every score is a number. If the parse looks wrong,
fall back to `get_page_text` on the matchups URL. On that page each matchup lists
team A, then A's actual and projected scores, then B's actual and projected, then
team B.

## 3. Write the post

Adam's format from past seasons (one line, owner name, not team name):

```
High Score - Week <N> - <owner name> - <score> #winnings
```

Always show scores with two decimals (the snippet prints 107.90 as 107.9). If two
teams tie for the top score, list both owners joined with "and".

Copy it to the clipboard and open the group in Brave, where Adam is signed in to
Facebook:

```
printf '%s' '<post text>' | pbcopy
open -a "Brave Browser" "<FB_GROUP_URL>"
```

Then show the user the post text, the runner-up and the low score (for any
trash talk they want to add), and tell them it's on the clipboard.

## 4. Record the payout in the sheet

The sheet's **Payout** tab has one row per manager (column A = full name, B = team
name, C = Total) and one column per week: week 1 is column D, week N is the column
N-1 letters after D (D=1, E=2 ... Q=14). The weekly winner gets `WEEKLY_PAYOUT` in
their row under that week. Total and the owed columns are formulas, so don't touch
them.

1. Read the tab first: Drive `download_file_content` with
   `exportMimeType: "text/csv"` exports the first tab, which is Payout. Find the
   winner's row by the full name from `owners.tsv`. Rows start at 3.
2. If that week's column already has a value in any row, stop and show it; the week
   was already recorded.
3. Write the cell. With the Google Sheets connector, write the value directly
   (read the google-workspace skill first). Without it, use Claude in Chrome: open
   `https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit`, click the Name Box (the
   cell-address box left of the formula bar), type the cell (e.g. `I11`), Enter,
   type the amount, Enter.
4. Export the CSV again and check that the cell and the winner's Total changed.

If column B has a team name that doesn't match Yahoo (teams get renamed each
season), mention it and offer to fix it. Typing over a team name drops its link.

## Recap mode (`/ffb-week recap`)

For an end-of-season (or any time) summary instead of a single week:

1. Run the step 2 snippet once per finished week (or loop `week(w)` over 1..N in
   one call) and keep each week's top score.
2. Export the Payout tab (step 4) and read each manager's Total in column C.
3. Write one post, copied to the clipboard like step 3:

```
FFB High Scores - <year> season so far
Week 1 - <owner> - <score>
...
Most weekly wins: <owner> (<n>)
Season high: Week <N> - <owner> - <score>
Weekly winnings: <owner> $<total>, ... (only people above $0, highest first)
```

Don't write to the sheet in recap mode.

## Config backup

The local config isn't in git. After changing it, remind Adam to back it up himself
(the vault needs his unlock):

```
bw unlock   # then export the BW_SESSION it prints
~/.claude/skills/ffb-week/ffb-config.sh backup
```

`restore` writes both files back on a new machine. Never run `bw unlock` or handle
the master password yourself.

## Rules

- Never post to Facebook yourself. Adam pastes it and clicks Post.
- Writing the weekly payout to the sheet is part of the command; don't edit any
  other cells unless Adam asks.
- Read-only on Yahoo: don't click anything in the league, only read pages.
- Don't save owner emails anywhere. Yahoo's Managers page shows them; they aren't
  needed.
