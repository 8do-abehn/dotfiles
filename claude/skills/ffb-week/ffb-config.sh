#!/usr/bin/env bash
# Manage the ffb-week local config, which lives outside the public dotfiles repo.
#   init     create ~/.config/ffb-week from the templates if it's missing
#   backup   save config.env and owners.tsv to a Bitwarden secure note
#   restore  write them back from that note (new machine)
# backup/restore need an unlocked vault: run `bw unlock` and export BW_SESSION first.
set -euo pipefail

CONFIG_DIR="$HOME/.config/ffb-week"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTE_NAME="ffb-week config"
# Separates the two files inside the single secure note
MARKER="### owners.tsv ###"

note_id() {
    bw list items --search "$NOTE_NAME" | jq -r --arg n "$NOTE_NAME" '.[] | select(.name == $n) | .id' | head -1
}

case "${1:-}" in
init)
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"
    # Never overwrite real settings; only fill in what's missing
    [[ -f "$CONFIG_DIR/config.env" ]] || install -m 600 "$SKILL_DIR/config.example.env" "$CONFIG_DIR/config.env"
    [[ -f "$CONFIG_DIR/owners.tsv" ]] || install -m 600 "$SKILL_DIR/owners.example.tsv" "$CONFIG_DIR/owners.tsv"
    echo "config in $CONFIG_DIR"
    ;;
backup)
    notes="$(cat "$CONFIG_DIR/config.env"; echo "$MARKER"; cat "$CONFIG_DIR/owners.tsv")"
    id="$(note_id)"
    if [[ -n "$id" ]]; then
        bw get item "$id" | jq --arg n "$notes" '.notes = $n' | bw encode | bw edit item "$id" >/dev/null
        echo "updated Bitwarden note '$NOTE_NAME'"
    else
        bw get template item | jq --arg name "$NOTE_NAME" --arg n "$notes" \
            '.type = 2 | .secureNote = {type: 0} | .name = $name | .notes = $n | .login = null' \
            | bw encode | bw create item >/dev/null
        echo "created Bitwarden note '$NOTE_NAME'"
    fi
    ;;
restore)
    id="$(note_id)"
    [[ -n "$id" ]] || { echo "no Bitwarden note named '$NOTE_NAME'" >&2; exit 1; }
    notes="$(bw get item "$id" | jq -r .notes)"
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"
    umask 077
    printf '%s\n' "$notes" | sed "/^$MARKER\$/,\$d" > "$CONFIG_DIR/config.env"
    printf '%s\n' "$notes" | sed "1,/^$MARKER\$/d" > "$CONFIG_DIR/owners.tsv"
    echo "restored $CONFIG_DIR"
    ;;
*)
    echo "usage: $(basename "$0") init|backup|restore" >&2
    exit 2
    ;;
esac
