#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["sense_energy>=0.14,<0.15"]
# ///
"""Read-only CLI for a Sense energy monitor (unofficial cloud API via sense_energy).

Credentials never live here. `login` is run by the human once; it trades
email/password(/MFA) for tokens cached in ~/.config/sense/auth.json (0600).
Every other command reuses those tokens and refreshes them when they expire.
"""

import argparse
import getpass
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from sense_energy import (
    Scale,
    Senseable,
    SenseAPITimeoutException,
    SenseAuthenticationException,
    SenseMFARequiredException,
)

AUTH_FILE = Path(os.environ.get("SENSE_AUTH_FILE", Path.home() / ".config/sense/auth.json"))
SCALES = {"day": Scale.DAY, "week": Scale.WEEK, "month": Scale.MONTH, "year": Scale.YEAR, "cycle": Scale.CYCLE}


def die(msg: str, code: int = 1):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def save_auth(sense: Senseable):
    AUTH_FILE.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "access_token": sense.sense_access_token,
        "refresh_token": sense.refresh_token,
        "user_id": sense.sense_user_id,
        "device_id": sense.device_id,
        "monitor_id": sense.sense_monitor_id,
    }
    # Write then chmod before rename so the token file is never world-readable, even briefly
    tmp = AUTH_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2))
    tmp.chmod(0o600)
    tmp.replace(AUTH_FILE)


def load_session() -> Senseable:
    if not AUTH_FILE.exists():
        die("not logged in. The user must run: ~/.claude/skills/sense/sense.py login", 2)
    auth = json.loads(AUTH_FILE.read_text())
    sense = Senseable(device_id=auth["device_id"])
    sense.load_auth(auth["access_token"], auth["user_id"], auth["device_id"], auth["refresh_token"])
    sense.set_monitor_id(auth["monitor_id"])
    return sense


def persist_if_renewed(sense: Senseable):
    # The library silently renews on 401; keep the rotated tokens or the next run starts from a dead one
    auth = json.loads(AUTH_FILE.read_text())
    if auth.get("access_token") != sense.sense_access_token or auth.get("refresh_token") != sense.refresh_token:
        save_auth(sense)


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
    if args.bw:
        email, password = bw_get("username", args.bw), bw_get("password", args.bw)
    else:
        email = input("Sense email: ").strip()
        password = getpass.getpass("Sense password: ")
    sense = Senseable()
    try:
        sense.authenticate(email, password)
    except SenseMFARequiredException:
        sense.validate_mfa(input("MFA code: ").strip())
    except SenseAuthenticationException as e:
        die(str(e))
    save_auth(sense)
    print(f"Logged in. Tokens cached at {AUTH_FILE} (monitor {sense.sense_monitor_id})")


def cmd_logout(args):
    if AUTH_FILE.exists():
        try:
            load_session().logout()
        except Exception:
            pass  # server-side logout is best effort; removing the local tokens is what matters
        AUTH_FILE.unlink()
    print("Logged out")


def cmd_now(sense: Senseable, args):
    sense.update_realtime()
    rt = sense.get_realtime()
    devices = sorted(
        ({"name": d.get("name", d["id"]), "w": round(float(d.get("w", 0)), 1)} for d in rt.get("devices", [])),
        key=lambda d: -d["w"],
    )
    return {
        "time": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "usage_w": round(sense.active_power, 1),
        "solar_w": round(sense.active_solar_power, 1),
        "voltage": [round(v, 1) for v in sense.active_voltage],
        "frequency_hz": round(sense.active_frequency, 2) if sense.active_frequency else None,
        "devices_on": devices,
    }


def cmd_usage(sense: Senseable, args):
    scale = SCALES[args.scale]
    dt = datetime.fromisoformat(args.date).replace(tzinfo=timezone.utc) if args.date else None
    sense.get_trend_data(scale, dt)
    stat = lambda k: sense.get_stat(scale, k)
    out = {
        "scale": args.scale,
        "start": sense.trend_start(scale).isoformat() if sense.trend_start(scale) else None,
        "usage_kwh": round(stat("consumption"), 2),
    }
    if sense._monitor.get("solar_configured"):
        out |= {
            "production_kwh": round(stat("production"), 2),
            "from_grid_kwh": round(stat("from_grid") or 0, 2),
            "to_grid_kwh": round(stat("to_grid") or 0, 2),
            "solar_powered_pct": stat("solar_powered"),
        }
    devices = [
        {"name": d.name, "kwh": round(d.energy_kwh[scale], 2)} for d in sense.devices if d.energy_kwh[scale] > 0
    ]
    out["devices"] = sorted(devices, key=lambda d: -d["kwh"])[: args.top]
    return out


def is_deleted(d: dict) -> bool:
    # Deleted devices stay in the API's device list, flagged rather than removed
    return d.get("tags", {}).get("UserDeleted") == "true"


def cmd_devices(sense: Senseable, args):
    rows = sense.get_discovered_device_data()
    if not args.all:
        rows = [d for d in rows if not is_deleted(d)]
    keep = ("id", "name", "icon", "tags", "last_state", "last_state_time")
    return [{k: d.get(k) for k in keep if k in d} | {"deleted": is_deleted(d)} for d in rows]


def cmd_device(sense: Senseable, args):
    rows = sense.get_discovered_device_data()
    q = args.name.lower()
    # An exact id always wins; name matches skip deleted devices so a rename doesn't collide with its ghost
    match = [d for d in rows if q == d["id"].lower()] or [
        d for d in rows if q in d.get("name", "").lower() and not is_deleted(d)
    ]
    if not match:
        ghosts = [d["id"] for d in rows if q in d.get("name", "").lower()]
        if ghosts:
            die(f"'{args.name}' only matches deleted devices; pass an id: {', '.join(ghosts)}")
        die(f"no device matching '{args.name}'")
    if len(match) > 1:
        return {"ambiguous": [{"id": d["id"], "name": d["name"]} for d in match]}
    return sense.get_device_info(match[0]["id"])


def cmd_always_on(sense: Senseable, args):
    return sense.always_on_info()


def cmd_status(sense: Senseable, args):
    return {"monitor": sense.get_monitor_data(), "status": sense.get_monitor_info()}


def cmd_timeline(sense: Senseable, args):
    return sense.get_all_usage_data({"n_items": args.n})


def cmd_raw(sense: Senseable, args):
    # Escape hatch for endpoints this script doesn't wrap; {monitor} and {user} get filled in
    path = args.path.lstrip("/").format(monitor=sense.sense_monitor_id, user=sense.sense_user_id)
    return sense._api_call(path)


def main():
    p = argparse.ArgumentParser(description="Sense energy monitor CLI (read-only)")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("login", help="(human only) authenticate and cache tokens")
    s.add_argument("--bw", metavar="ITEM", help="pull email/password from this Bitwarden item")
    sub.add_parser("logout", help="revoke and delete cached tokens")
    sub.add_parser("now", help="live watts, solar, voltage, devices currently on")
    s = sub.add_parser("usage", help="kWh totals and per-device breakdown")
    s.add_argument("scale", nargs="?", default="day", choices=SCALES)
    s.add_argument("--date", help="any date inside the period, YYYY-MM-DD (default: current period)")
    s.add_argument("--top", type=int, default=15, help="max devices to list")
    s = sub.add_parser("devices", help="discovered devices (deleted ones hidden)")
    s.add_argument("--all", action="store_true", help="include devices deleted in the app")
    s = sub.add_parser("device", help="detail for one device (name substring or id)")
    s.add_argument("name")
    sub.add_parser("always-on", help="always-on baseline info")
    sub.add_parser("status", help="monitor info, signal, detection progress")
    s = sub.add_parser("timeline", help="recent device on/off events")
    s.add_argument("-n", type=int, default=30)
    s = sub.add_parser("raw", help="GET an API path, e.g. 'app/monitors/{monitor}/devices/always_on'")
    s.add_argument("path")
    args = p.parse_args()

    if args.cmd == "login":
        return cmd_login(args)
    if args.cmd == "logout":
        return cmd_logout(args)

    handler = globals()[f"cmd_{args.cmd.replace('-', '_')}"]
    sense = load_session()
    try:
        result = handler(sense, args)
    except SenseAuthenticationException as e:
        die(f"auth failed ({e}); tokens may be revoked. The user must re-run login", 2)
    except SenseAPITimeoutException:
        die("Sense API timed out; retry in a minute")
    persist_if_renewed(sense)
    print(json.dumps(result, indent=2, default=str))


if __name__ == "__main__":
    main()
