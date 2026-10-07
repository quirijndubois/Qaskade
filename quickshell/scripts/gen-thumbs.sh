#!/usr/bin/env bash
# Generate low-res thumbnails for all wallpapers into ~/wallpapers/.thumbs/
# Requires: ffmpeg (or ImageMagick convert as fallback)
# Usage: gen-thumbs.sh [--width N]  (default 400px wide)

WP_DIR="$HOME/wallpapers"
THUMB_DIR="$WP_DIR/.thumbs"
WIDTH=400

while [[ $# -gt 0 ]]; do
    case "$1" in
        --width) WIDTH="$2"; shift 2 ;;
        *) shift ;;
    esac
done

mkdir -p "$THUMB_DIR"

total=0
done_count=0
skip=0

for f in "$WP_DIR"/*.{jpg,jpeg,png,webp,gif,JPG,JPEG,PNG,WEBP,GIF}; do
    [[ -f "$f" ]] || continue
    (( total++ ))
    name="$(basename "$f")"
    out="$THUMB_DIR/$name"
    if [[ -f "$out" && "$out" -nt "$f" ]]; then
        (( skip++ ))
        continue
    fi
    if command -v ffmpeg &>/dev/null; then
        ffmpeg -y -loglevel error -i "$f" \
            -vf "scale=${WIDTH}:-2" \
            "$out" 2>/dev/null
    elif command -v convert &>/dev/null; then
        convert "$f" -resize "${WIDTH}x>" "$out" 2>/dev/null
    else
        echo "error: need ffmpeg or ImageMagick" >&2
        exit 1
    fi
    (( done_count++ ))
    echo "[${done_count}] $name" >&2
done

echo "done: ${done_count} generated, ${skip} up-to-date, ${total} total" >&2
