---
name: artsonia
description: Save the kids' Artsonia artwork at full size with its project description. Use when the user pastes an artsonia.com link or art id, or asks to download, save, or grab artwork or a picture from Artsonia.
argument-hint: <id-or-url> [<id-or-url> ...]
allowed-tools: Bash(~/.claude/skills/artsonia/artsonia.sh:*)
---

# Artsonia artwork saver

Artsonia pages only show resized copies of the art. The image URL with no resize
params (`https://images.artsonia.com/art/<id>.jpg`) returns the original upload. The
script fetches that, plus the artwork details and the teacher's project description.

## Running it

Always call the script by this exact path, with one or more ids or URLs:

```
~/.claude/skills/artsonia/artsonia.sh <id-or-url> [...]
```

- Saves to `~/Pictures/Artsonia/<artist>/<id>-<project>.jpg` and a matching `.txt`.
- `-o DIR` or `ARTSONIA_DIR` changes the root folder.
- Already-saved artwork prints `have:` and is skipped, so re-running is safe.
- Exits non-zero if any id fails, with a `fail:` line saying why.

After it runs, tell the user where the files went, the pixel size, and quote the
project title and description from the `.txt` file.

## Notes

- The description is the teacher's text about the class project, not something the
  child wrote. Say so if it matters.
- Public pages need no login. If a page has no "created by" line it is private or
  removed. Don't try to work around that.
