#!/bin/bash
# Save Artsonia artwork at full size, plus its project description.
#
# Usage: artsonia.sh [-o DIR] <id-or-url> [<id-or-url> ...]
#
# Files land in DIR/<artist>/ (default ~/Pictures/Artsonia/<artist>/):
#   <id>-<project>.jpg  original upload, no resizing
#   <id>-<project>.txt  title, artist, grade, school, link, teacher's description
# Already-saved artwork is skipped, so re-running is safe.
set -euo pipefail

OUT_ROOT="${ARTSONIA_DIR:-$HOME/Pictures/Artsonia}"
UA="Mozilla/5.0"

usage() {
    echo "Usage: $(basename "$0") [-o DIR] <id-or-url> [<id-or-url> ...]" >&2
    exit 1
}

while getopts "o:h" opt; do
    case "$opt" in
        o) OUT_ROOT="$OPTARG" ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -ge 1 ]] || usage

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Lowercase, dashes only, so names are safe in any shell or filesystem
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

save_one() {
    local arg="$1" id page text created artist grade school project about slug dir base
    # Accept a bare id or any URL containing id=<digits>
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        id="$arg"
    elif [[ "$arg" =~ id=([0-9]+) ]]; then
        id="${BASH_REMATCH[1]}"
    else
        echo "skip: can't find an artwork id in '$arg'" >&2
        return 1
    fi

    page="$tmp/$id.html"
    if ! curl -sfL -A "$UA" "https://www.artsonia.com/museum/art.asp?id=$id" -o "$page"; then
        echo "fail: $id page didn't load" >&2
        return 1
    fi

    # The page is server-rendered, so plain text conversion keeps the fields in order
    text=$(textutil -convert txt -stdout "$page" | sed '/^[[:space:]]*$/d')
    created=$(grep -m1 '^created by ' <<<"$text" || true)
    if [[ -z "$created" ]]; then
        echo "fail: $id has no artwork details (private, removed, or page changed)" >&2
        return 1
    fi

    # "created by Artist1234 in Grade 1 at Example Elementary School"
    artist=$(sed -E 's/^created by ([^ ]+) .*/\1/' <<<"$created")
    grade=$(sed -nE 's/.* in (Grade [^ ]+|Kindergarten|Pre-K[^ ]*) .*/\1/p' <<<"$created")
    school=$(sed -nE 's/.* at (.*)$/\1/p' <<<"$created")
    project=$(grep -m1 '^from school project ' <<<"$text" | sed -E 's/^from school project "(.*)"$/\1/' || true)
    about=$(awk '/^About this School Project/{f=1; next} /^Artwork on keepsakes/{f=0} f' <<<"$text")

    slug=$(slugify "${project:-artwork}")
    dir="$OUT_ROOT/$artist"
    base="$dir/$id-$slug"
    mkdir -p "$dir"

    if [[ -s "$base.jpg" && -s "$base.txt" ]]; then
        echo "have: $base.jpg"
        return 0
    fi

    # No resize params on the image URL returns the original upload
    curl -sfL -A "$UA" "https://images.artsonia.com/art/$id.jpg" -o "$base.jpg.part"
    mv "$base.jpg.part" "$base.jpg"

    {
        echo "${project:-Untitled}"
        echo "$artist, ${grade:+$grade, }$school"
        echo "Artsonia art id #$id"
        echo "https://www.artsonia.com/museum/art.asp?id=$id"
        if [[ -n "$about" ]]; then
            echo
            echo "About this school project:"
            echo "$about"
        fi
    } >"$base.txt"

    local size
    size=$(sips -g pixelWidth -g pixelHeight "$base.jpg" | awk '/pixel/{print $2}' | paste -sd x -)
    echo "saved: $base.jpg ($size)"
}

rc=0
for arg in "$@"; do
    save_one "$arg" || rc=1
done
exit "$rc"
