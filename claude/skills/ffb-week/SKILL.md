---
name: ffb-week
description: Weekly fantasy football high score post for the Yahoo league. Use when the user says /ffb-week, asks who had the high score this week, or wants the weekly FFB update for the Facebook group.
argument-hint: "[week number]"
allowed-tools: Bash(cat ~/.config/ffb-week/*), Bash(pbcopy), Bash(open -a "Brave Browser" *)
---

# Weekly FFB high score

Finds the week's high score in the Yahoo league and writes the Facebook post in
Adam's usual one-line style. The league ID, group URL and owner names live in
`~/.config/ffb-week/`, not in this repo, because the dotfiles repo is public.

## 1. Load the local config

```
cat ~/.config/ffb-week/config.env ~/.config/ffb-week/owners.tsv
```

- `config.env` has `YAHOO_LEAGUE_ID` and `FB_GROUP_URL`.
- `owners.tsv` maps the Yahoo team name to the name used in the post. Lines starting
  with `#` are comments. If a team is missing, use the Yahoo manager name and tell
  the user so they can add it.

If the config is missing, stop and ask the user for the league ID and group URL.

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

## Rules

- Never post to Facebook yourself. Adam pastes it and clicks Post.
- Read-only on Yahoo: don't click anything in the league, only read pages.
- Don't save owner emails anywhere. Yahoo's Managers page shows them; they aren't
  needed.
