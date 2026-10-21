#!/bin/sh

CONFIG_DIR="$HOME/.config"
WATCH_MODE=0

# Enable watch mode if --watch is passed
if [ "$1" = "--watch" ]; then
  WATCH_MODE=1
fi

sync_dir() {
  src="$1"
  dest="$CONFIG_DIR/$1"

  # Capture rsync output, exclude main-items (user-specific)
  changes=$(rsync -a --itemize-changes --exclude=main-items --exclude=user-settings.lua "$src/" "$dest/" \
    | awk '/^[><]f/ { print $2 }')

  if [ -n "$changes" ]; then
    echo "$changes" | while read -r file; do
      echo "$file has been modified!"
    done
    return 0
  else
    return 1
  fi
}

sync_all() {
  changed=0

  for dir in hypr kitty quickshell; do
    if sync_dir "$dir"; then
      changed=1
      # Hyprland only watches hyprland.lua, not the conf/*.lua files it dofile()s
      if [ "$dir" = "hypr" ] && [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        hyprctl reload >/dev/null && echo "Hyprland reloaded!"
      fi
    fi
  done

  if [ "$changed" -eq 0 ]; then
    echo "No files changed!"
  fi
}

# Initial sync
sync_all

# Create default main-items order if it doesn't exist yet
quickshell_config="$CONFIG_DIR/quickshell"
if [ ! -f "$quickshell_config/main-items" ]; then
  printf 'appearance apps bluetooth wifi clipboard notifications emoji system power\n' > "$quickshell_config/main-items"
  echo "main-items has been created!"
fi

echo "Install complete"

# Watch mode
if [ "$WATCH_MODE" -eq 1 ]; then
  echo "Watching for changes..."
  inotifywait -m -r -e modify,create,delete,move \
    hypr kitty quickshell |
  while read -r _; do
    sync_all
  done
fi
