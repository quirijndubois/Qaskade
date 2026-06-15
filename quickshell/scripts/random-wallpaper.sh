#!/bin/bash
WP_DIR="$HOME/wallpapers"
QS_DIR="$HOME/.config/quickshell"
PYTHON="$HOME/.conda/envs/pywalfox/bin/python3"

mapfile -t files < <(ls "$WP_DIR" 2>/dev/null)
[ "${#files[@]}" -eq 0 ] && exit 1
wallpaper="$WP_DIR/${files[RANDOM % ${#files[@]}]}"

transitions=(fade left right top bottom wipe wave grow center any outer)
trans="${transitions[RANDOM % ${#transitions[@]}]}"
awww img --transition-type "$trans" --transition-duration 1.5 --transition-fps 60 "$wallpaper" &

colors=$("$PYTHON" "$QS_DIR/scripts/extract-palette.py" "$wallpaper") || exit 1

printf '%s' "$colors" > "$QS_DIR/custom-palette"
quickshell ipc -c default call theme setCustom
