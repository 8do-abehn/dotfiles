#!/usr/bin/env python3
"""Read-only Jellyfin lookups for the kids-profile skill.

  jf.py find <text>             titles matching <text>: type, exact name, year, rating, path
  jf.py sees <profile> <text>   whether a profile can see each matching title, and why not
  jf.py policy <profile>        a profile's cap, unrated blocks, schedule, libraries

The admin key is read from ~/.api_jellyfin and sent only in a request header, never on a
command line. Nothing here changes Jellyfin; ratings change through riplab's
bin/jellyfin_ratings.sh so the JSON stays the source of truth.
"""
import json, os, sys, urllib.parse, urllib.request

URL = os.environ.get("JELLYFIN_URL", "http://10.150.70.14:8096")
KEY = open(os.path.expanduser(os.environ.get("JELLYFIN_KEY_FILE", "~/.api_jellyfin"))).read().strip()
SCORE = {"G": 0, "TV-G": 0, "TV-Y": 0, "TV-Y7": 7, "TV-Y7-FV": 7, "PG": 10, "TV-PG": 10,
         "PG-13": 13, "TV-14": 14, "R": 17, "TV-MA": 17, "NC-17": 18}


def get(path, **q):
    req = urllib.request.Request(f"{URL}{path}?{urllib.parse.urlencode(q)}",
                                 headers={"Authorization": f'MediaBrowser Token="{KEY}"'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def user(name):
    u = next((u for u in get("/Users") if u["Name"] == name), None)
    if not u:
        sys.exit(f"no profile named {name}")
    return u


def find(text):
    return get("/Items", Recursive="true", SearchTerm=text, IncludeItemTypes="Movie,Series,BoxSet",
               Fields="OfficialRating,ProductionYear,Path,ParentId")["Items"]


def main(argv):
    if len(argv) >= 2 and argv[0] == "find":
        for i in find(" ".join(argv[1:])):
            print(f'{i["Type"]}\t{i["Name"]}\t{i.get("ProductionYear")}\t{i.get("OfficialRating") or "unrated"}\t{i.get("Path")}')
    elif len(argv) >= 3 and argv[0] == "sees":
        u = user(argv[1]); p = u["Policy"]
        visible = {i["Id"] for i in get(f'/Users/{u["Id"]}/Items', Recursive="true",
                                        SearchTerm=" ".join(argv[2:]), IncludeItemTypes="Movie,Series,BoxSet")["Items"]}
        for i in find(" ".join(argv[2:])):
            r = i.get("OfficialRating")
            if i["Id"] in visible:
                why = "VISIBLE"
            elif not r and i["Type"] in (p.get("BlockUnratedItems") or []):
                why = "hidden: unrated"
            elif SCORE.get(r, -1) > (p.get("MaxParentalRating") or 99):
                why = f'hidden: {r} is over the cap'
            else:
                why = "hidden: other (library access, tag, or schedule)"
            print(f'{why}\t{i["Type"]}\t{i["Name"]} ({i.get("ProductionYear")})\t{r or "unrated"}')
    elif len(argv) == 2 and argv[0] == "policy":
        p = user(argv[1])["Policy"]
        folders = {f["Id"]: f["Name"] for f in get("/Library/MediaFolders")["Items"]}
        print(json.dumps({
            "MaxParentalRating": p.get("MaxParentalRating"),
            "BlockUnratedItems": p.get("BlockUnratedItems"),
            "BlockedTags": p.get("BlockedTags"),
            "AccessSchedules": [(s["DayOfWeek"], s["StartHour"], s["EndHour"]) for s in p.get("AccessSchedules") or []],
            "Libraries": "all" if p.get("EnableAllFolders") else [folders.get(f, f) for f in p.get("EnabledFolders") or []],
            "IsAdministrator": p.get("IsAdministrator"),
        }, indent=1))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
