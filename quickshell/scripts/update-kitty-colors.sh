#!/bin/bash
# Update kitty colors from a color scheme file

COLORS_FILE="${1:-$HOME/.config/kitty/color_scheme.conf}"

if [ ! -f "$COLORS_FILE" ]; then
    exit 1
fi

# Extract colors from the file and build color arguments
COLOR_ARGS=""
while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Parse "color0 #123456" format
    if [[ "$line" =~ ^([a-z0-9_]+)[[:space:]]+(.+)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        COLOR_ARGS="$COLOR_ARGS $key=$value"
    fi
done < "$COLORS_FILE"

# Apply colors to all kitty instances via their sockets
if [ -n "$COLOR_ARGS" ]; then
    for sock in /tmp/kitty-*; do
        [ -S "$sock" ] && kitten @ --to "unix:$sock" set-colors --all --configured $COLOR_ARGS 2>/dev/null
    done
fi
