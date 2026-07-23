#!/bin/bash
WP_DIR="$HOME/wallpapers"
QS_DIR="$HOME/.config/quickshell"
PYTHON="$HOME/.conda/envs/pywalfox/bin/python3"

cat_name=""
[ -f "$QS_DIR/wallpaper-category" ] && cat_name=$(tr -d '[:space:]' < "$QS_DIR/wallpaper-category")

if [ -z "$cat_name" ] || [ "$cat_name" = "all" ]; then
    mapfile -t files < <(ls "$WP_DIR" 2>/dev/null | grep -iE '\.(jpg|jpeg|png|webp|gif)$')
else
    mapfile -t files < <(python3 -c "
import json, sys
try:
    tags = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for f, ts in tags.items():
    if sys.argv[2] in ts:
        print(f)
" "$QS_DIR/wallpaper-tags.json" "$cat_name" 2>/dev/null)
    # fall back to all if the category is empty
    [ "${#files[@]}" -eq 0 ] && mapfile -t files < <(ls "$WP_DIR" 2>/dev/null | grep -iE '\.(jpg|jpeg|png|webp|gif)$')
fi

[ "${#files[@]}" -eq 0 ] && exit 1
wallpaper="$WP_DIR/${files[RANDOM % ${#files[@]}]}"

transitions=(fade left right top bottom wipe wave grow center any outer)
trans="${transitions[RANDOM % ${#transitions[@]}]}"
awww img --transition-type "$trans" --transition-duration 0.5 --transition-fps 60 "$wallpaper" &

colors=$("$PYTHON" "$QS_DIR/scripts/extract-palette.py" "$wallpaper") || exit 1

printf '%s' "$colors" > "$QS_DIR/custom-palette"
quickshell ipc -c default call theme setCustom
