#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Read-only CLI for the Lunch Money v2 API (https://lunchmoney.dev).

Lunch Money tokens always carry full read/write access, so read-only is enforced
here: the only HTTP method this script ever sends is GET.

The token never lives in this repo. `login` is run by the human once and stores it
in ~/.config/lunchmoney/token (0600). LUNCHMONEY_TOKEN overrides the file.
`--mock` talks to Lunch Money's demo server, which needs no token.
"""

import argparse
import getpass
import html
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path

LIVE_URL = "https://api.lunchmoney.dev/v2"
MOCK_URL = "https://mock.lunchmoney.dev/v2"
TOKEN_FILE = Path(os.environ.get("LUNCHMONEY_TOKEN_FILE", Path.home() / ".config/lunchmoney/token"))
PAGE_SIZE = 1000


def die(msg: str, code: int = 1):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


class Client:
    def __init__(self, mock: bool):
        self.base = MOCK_URL if mock else LIVE_URL
        self.token = None if mock else load_token()

    def get(self, path: str, params: dict | None = None):
        query = {k: str(v).lower() if isinstance(v, bool) else v for k, v in (params or {}).items() if v is not None}
        url = f"{self.base}/{path.lstrip('/')}"
        if query:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(query)
        headers = {"Accept": "application/json", "User-Agent": "lunchmoney-skill"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        req = urllib.request.Request(url, headers=headers, method="GET")
        # One retry on 429: the limit is 100 requests/min, so a single wait is enough for this script's volume
        for attempt in range(2):
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    return unescape(json.load(resp))
            except urllib.error.HTTPError as e:
                if e.code == 429 and attempt == 0:
                    time.sleep(min(int(e.headers.get("Retry-After", "10")), 60))
                    continue
                body = e.read().decode(errors="replace")[:500]
                if e.code == 401:
                    die(f"401 unauthorized ({body}). Token missing, revoked or wrong; the user must re-run login", 2)
                die(f"HTTP {e.code} for GET {path}: {body}")
            except urllib.error.URLError as e:
                die(f"network error for GET {path}: {e.reason}")


def unescape(x):
    # The API HTML-escapes user-entered text ("Penny&#x27;s"); undo it so names read and match normally
    if isinstance(x, str):
        return html.unescape(x)
    if isinstance(x, list):
        return [unescape(i) for i in x]
    if isinstance(x, dict):
        return {k: unescape(v) for k, v in x.items()}
    return x


def load_token() -> str:
    if tok := os.environ.get("LUNCHMONEY_TOKEN"):
        return tok.strip()
    if TOKEN_FILE.exists():
        return TOKEN_FILE.read_text().strip()
    die("not logged in. The user must run: ~/.claude/skills/lunchmoney/lunchmoney.py login", 2)


def bw_get(field: str, item: str) -> str:
    if not shutil.which("bw"):
        die("bw not installed")
    if not os.environ.get("BW_SESSION"):
        die("BW_SESSION not set. Run `export BW_SESSION=$(bw unlock --raw)` first")
    out = subprocess.run(["bw", "get", field, item], capture_output=True, text=True, check=False)
    if out.returncode != 0:
        die(f"bw get {field} failed: {out.stderr.strip()}")
    return out.stdout.strip()


def cmd_login(args):
    if not sys.stdin.isatty():
        die("login is interactive. The user must run it in their own terminal")
    token = bw_get("password", args.bw) if args.bw else getpass.getpass("Lunch Money API token: ").strip()
    if not token:
        die("empty token")
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    # Write then chmod before rename so the token is never world-readable, even briefly
    tmp = TOKEN_FILE.with_suffix(".tmp")
    tmp.write_text(token)
    tmp.chmod(0o600)
    tmp.replace(TOKEN_FILE)
    me = Client(mock=False).get("me")
    print(f"Logged in to budget '{me.get('budget_name')}' with key '{me.get('api_key_label')}'. Token at {TOKEN_FILE}")


def cmd_logout(args):
    TOKEN_FILE.unlink(missing_ok=True)
    print("Local token deleted. Revoke it too at https://my.lunchmoney.app/developers")


# --- lookups: the API returns bare IDs, so names come from these ---


class Lookups:
    def __init__(self, lm: Client):
        self.lm = lm
        self._cats = self._tags = self._accts = None

    def categories(self) -> dict[int, dict]:
        if self._cats is None:
            self._cats = {}

            def walk(rows, group=None):
                for c in rows:
                    self._cats[c["id"]] = {**c, "group_name": group}
                    walk(c.get("children") or [], c["name"])

            walk(self.lm.get("categories", {"format": "nested"})["categories"])
        return self._cats

    def tags(self) -> dict[int, str]:
        if self._tags is None:
            self._tags = {t["id"]: t["name"] for t in self.lm.get("tags")["tags"]}
        return self._tags

    def accounts(self) -> dict[tuple[str, int], dict]:
        if self._accts is None:
            self._accts = {}
            for a in self.lm.get("plaid_accounts")["plaid_accounts"]:
                self._accts[("plaid", a["id"])] = a
            for a in self.lm.get("manual_accounts")["manual_accounts"]:
                self._accts[("manual", a["id"])] = a
        return self._accts

    def cat_name(self, cid):
        if cid is None:
            return None
        return self.categories().get(cid, {}).get("name", f"#{cid}")

    def acct_name(self, txn):
        key = ("plaid", txn["plaid_account_id"]) if txn.get("plaid_account_id") else ("manual", txn.get("manual_account_id"))
        a = self.accounts().get(key)
        return (a.get("display_name") or a.get("name")) if a else None

    def resolve_category(self, q: str) -> int:
        if q.isdigit():
            return int(q)
        if q.lower() in ("none", "uncategorized"):
            return 0  # the API's filter value for uncategorized
        return self._resolve(q, {cid: c["name"] for cid, c in self.categories().items()}, "category")

    def resolve_tag(self, q: str) -> int:
        return int(q) if q.isdigit() else self._resolve(q, self.tags(), "tag")

    def resolve_account(self, q: str) -> tuple[str, int]:
        names = {k: f"{a.get('display_name') or ''} {a['name']} {a.get('institution_name') or ''}" for k, a in self.accounts().items()}
        if q.isdigit():
            hits = [k for k in names if k[1] == int(q)]
            if len(hits) == 1:
                return hits[0]
        return self._resolve(q, names, "account")

    @staticmethod
    def _resolve(q, names: dict, kind: str):
        exact = [k for k, n in names.items() if n.strip().lower() == q.lower()]
        hits = exact or [k for k, n in names.items() if q.lower() in n.lower()]
        if len(hits) == 1:
            return hits[0]
        if not hits:
            die(f"no {kind} matching '{q}'")
        die(f"'{q}' matches several {kind}s: " + "; ".join(names[k].strip() for k in hits))


# --- commands ---


def month_bounds(today: date | None = None) -> tuple[str, str]:
    today = today or date.today()
    start = today.replace(day=1)
    end = (start + timedelta(days=32)).replace(day=1) - timedelta(days=1)
    return start.isoformat(), end.isoformat()


def date_range(args, default_days: int | None = None) -> tuple[str, str]:
    if args.month:
        return month_bounds(date.fromisoformat(f"{args.month}-01"))
    if args.start or args.end:
        return args.start or "2000-01-01", args.end or date.today().isoformat()
    if default_days:
        return (date.today() - timedelta(days=default_days)).isoformat(), date.today().isoformat()
    return month_bounds()


def fetch_transactions(lm: Client, lk: Lookups, args) -> list[dict]:
    start, end = date_range(args, default_days=30)
    params = {"start_date": start, "end_date": end, "limit": PAGE_SIZE}
    if args.category:
        params["category_id"] = lk.resolve_category(args.category)
    if args.tag:
        params["tag_id"] = lk.resolve_tag(args.tag)
    if args.account:
        kind, aid = lk.resolve_account(args.account)
        params[f"{kind}_account_id"] = aid
    if args.status:
        params["status"] = args.status
    if args.pending:
        params["include_pending"] = True

    rows, offset = [], 0
    while True:
        page = lm.get("transactions", {**params, "offset": offset})
        rows += page["transactions"]
        if not page.get("has_more") or len(rows) >= args.max_fetch:
            break
        offset += PAGE_SIZE
    if args.payee:
        q = args.payee.lower()
        rows = [t for t in rows if q in (t.get("payee") or "").lower() or q in (t.get("original_name") or "").lower()]
    return rows


def slim(t: dict, lk: Lookups) -> dict:
    return {
        "id": t["id"],
        "date": t["date"],
        "payee": t.get("payee"),
        "amount": float(t["amount"]),
        "currency": t["currency"],
        "category": lk.cat_name(t.get("category_id")),
        "account": lk.acct_name(t),
        "tags": [lk.tags().get(i, f"#{i}") for i in t.get("tag_ids") or []],
        "status": t.get("status"),
        "pending": t.get("is_pending"),
        "notes": t.get("notes"),
        "recurring": t.get("recurring_id") is not None,
    }


def cmd_transactions(lm, lk, args):
    rows = fetch_transactions(lm, lk, args)
    start, end = date_range(args, default_days=30)
    out = [slim(t, lk) for t in sorted(rows, key=lambda t: t["date"], reverse=True)]
    return {
        "start": start,
        "end": end,
        "count": len(out),
        # Raw sums of every matched row, transfers included; use `spending` for real totals
        "sum_debits": round(sum(t["to_base"] for t in rows if t["to_base"] > 0), 2),
        "sum_credits": round(-sum(t["to_base"] for t in rows if t["to_base"] < 0), 2),
        "shown": min(len(out), args.limit),
        "transactions": out[: args.limit],
    }


def cmd_spending(lm, lk, args):
    rows = fetch_transactions(lm, lk, args)
    start, end = date_range(args, default_days=30)
    cats = lk.categories()
    totals, counts = defaultdict(float), defaultdict(int)
    for t in rows:
        # Split parents and group children would double count against their children/parents
        if t.get("is_split_parent") or t.get("group_parent_id") or t.get("status") == "delete_pending":
            continue
        c = cats.get(t.get("category_id")) or {}
        if c.get("exclude_from_totals"):
            continue
        key = (c.get("group_name") or c.get("name") or "Uncategorized") if args.by_group else (c.get("name") or "Uncategorized")
        totals[key] += t["to_base"]
        counts[key] += 1
    spend = sorted(((k, v) for k, v in totals.items() if v > 0), key=lambda kv: -kv[1])
    income = sorted(((k, -v) for k, v in totals.items() if v < 0), key=lambda kv: -kv[1])
    return {
        "start": start,
        "end": end,
        "currency": "primary currency (to_base)",
        "total_spent": round(sum(v for _, v in spend), 2),
        "total_income": round(sum(v for _, v in income), 2),
        "spending": [{"category": k, "amount": round(v, 2), "count": counts[k]} for k, v in spend],
        "income": [{"category": k, "amount": round(v, 2), "count": counts[k]} for k, v in income],
    }


def cmd_budget(lm, lk, args):
    start, end = date_range(args)
    data = lm.get("summary", {"start_date": start, "end_date": end, "include_totals": True})
    cats = lk.categories()
    rows = []
    for c in data.get("categories", []):
        meta = cats.get(c["category_id"], {})
        tot = c.get("totals", {})
        spent = round((tot.get("other_activity") or 0) + (tot.get("recurring_activity") or 0), 2)
        rows.append({
            "category": meta.get("name", f"#{c['category_id']}"),
            "group": meta.get("group_name"),
            "is_income": meta.get("is_income", False),
            "budgeted": tot.get("budgeted"),
            "activity": spent,
            "available": tot.get("available"),
            "recurring_remaining": tot.get("recurring_remaining"),
        })
    rows.sort(key=lambda r: (r["is_income"], -(r["activity"] or 0)))
    out = {"start": start, "end": end, "aligned_to_budget_period": data.get("aligned"), "categories": rows}
    if "totals" in data:
        out["totals"] = data["totals"]
    return out


def cmd_accounts(lm, lk, args):
    out = []
    for (kind, aid), a in lk.accounts().items():
        if a.get("status") == "closed" and not args.all:
            continue
        out.append({
            "id": aid,
            "source": kind,
            "name": a.get("display_name") or a["name"],
            "institution": a.get("institution_name"),
            "type": a.get("type"),
            "subtype": a.get("subtype"),
            "balance": float(a["balance"]) if a.get("balance") is not None else None,
            "currency": a.get("currency"),
            "balance_as_of": a.get("balance_as_of") or a.get("balance_last_update"),
            "status": a.get("status"),
        })
    return sorted(out, key=lambda a: (a["type"] or "", a["name"]))


def cmd_categories(lm, lk, args):
    return [
        {"id": cid, "name": c["name"], "group": c["group_name"], "is_group": c.get("is_group"),
         "is_income": c.get("is_income"), "exclude_from_budget": c.get("exclude_from_budget"),
         "exclude_from_totals": c.get("exclude_from_totals")}
        for cid, c in lk.categories().items() if args.all or not c.get("archived")
    ]


def cmd_tags(lm, lk, args):
    return [{"id": i, "name": n} for i, n in lk.tags().items()]


def cmd_recurring(lm, lk, args):
    start, end = date_range(args)
    data = lm.get("recurring_items", {"start_date": start, "end_date": end})["recurring_items"]
    out = []
    for r in data:
        crit, over, m = r.get("transaction_criteria", {}), r.get("overrides") or {}, r.get("matches") or {}
        out.append({
            "id": r["id"],
            "payee": over.get("payee") or crit.get("payee") or r.get("description"),
            "amount": float(crit["amount"]) if crit.get("amount") else None,
            "currency": crit.get("currency"),
            "every": f"{crit.get('quantity')} {crit.get('granularity')}",
            "category": lk.cat_name(over.get("category_id")),
            "status": r.get("status"),
            "expected_dates": m.get("expected_occurrence_dates"),
            "missing_dates": m.get("missing_transaction_dates"),
        })
    return {"start": start, "end": end, "recurring": out}


def cmd_me(lm, lk, args):
    return lm.get("me")


def cmd_raw(lm, lk, args):
    # Escape hatch for endpoints not wrapped here. Still GET-only, so it can't change data
    params = dict(kv.split("=", 1) for kv in args.param)
    return lm.get(args.path, params)


def add_range(s, month_default: bool):
    s.add_argument("--month", metavar="YYYY-MM", help="a whole calendar month")
    s.add_argument("--start", metavar="YYYY-MM-DD")
    s.add_argument("--end", metavar="YYYY-MM-DD", help="default: today")
    s.epilog = "Default range: " + ("current month." if month_default else "last 30 days.")


def add_txn_filters(s):
    add_range(s, month_default=False)
    s.add_argument("--category", help="name, id, or 'uncategorized'")
    s.add_argument("--tag", help="name or id")
    s.add_argument("--account", help="name/institution substring or id")
    s.add_argument("--payee", help="substring match on payee or original bank text")
    s.add_argument("--status", choices=["reviewed", "unreviewed"])
    s.add_argument("--pending", action="store_true", help="include pending transactions (excluded by default)")
    s.add_argument("--max-fetch", type=int, default=10000, help="stop paging after this many")


def main():
    p = argparse.ArgumentParser(description="Lunch Money CLI (read-only, GET requests only)")
    p.add_argument("--mock", action="store_true", default=os.environ.get("LUNCHMONEY_MOCK") == "1",
                   help="use the demo server (fake data, no token)")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("login", help="(human only) store an API token")
    s.add_argument("--bw", metavar="ITEM", help="read the token from this Bitwarden item's password field")
    sub.add_parser("logout", help="delete the stored token")
    sub.add_parser("me", help="budget name, primary currency, key label")
    s = sub.add_parser("accounts", help="Plaid and manual accounts with balances")
    s.add_argument("--all", action="store_true", help="include closed accounts")
    s = sub.add_parser("categories", help="categories with their groups")
    s.add_argument("--all", action="store_true", help="include archived")
    sub.add_parser("tags", help="tags")
    s = sub.add_parser("transactions", help="transactions with names filled in")
    add_txn_filters(s)
    s.add_argument("--limit", type=int, default=200, help="max rows to print (totals still cover all)")
    s = sub.add_parser("spending", help="totals per category, computed from transactions")
    add_txn_filters(s)
    s.add_argument("--by-group", action="store_true", help="roll categories up into their groups")
    s = sub.add_parser("budget", help="budgeted vs actual per category (GET /summary)")
    add_range(s, month_default=True)
    s = sub.add_parser("recurring", help="recurring items and which occurrences are missing")
    add_range(s, month_default=True)
    s = sub.add_parser("raw", help="GET any v2 path, e.g. raw summary -p start_date=2026-09-01 -p end_date=2026-09-30")
    s.add_argument("path")
    s.add_argument("-p", "--param", action="append", default=[], metavar="KEY=VALUE")
    args = p.parse_args()

    if args.cmd == "login":
        return cmd_login(args)
    if args.cmd == "logout":
        return cmd_logout(args)

    lm = Client(mock=args.mock)
    result = globals()[f"cmd_{args.cmd}"](lm, Lookups(lm), args)
    if args.mock and isinstance(result, dict):
        result = {"mock_data": True, **result}
    print(json.dumps(result, indent=2, default=str))


if __name__ == "__main__":
    main()
