---
layout: home
title: Install Script
---

# Install Script

`install.sh` syncs the repo's config directories into `~/.config/` using `rsync`, optionally watching for changes.

---

## User Guide

### Basic Install

```bash
./install.sh
```

Copies `hypr/`, `kitty/`, and `quickshell/` into `~/.config/hypr/`, `~/.config/kitty/`, and `~/.config/quickshell/`. Prints which files changed.

### Watch Mode

```bash
./install.sh --watch
```

After the initial sync, watches all three source directories for file changes using `inotifywait` and re-syncs automatically. Useful while editing configs.

### What Gets Skipped

Two paths are excluded from syncing:

- `main-items` - your personal settings menu order
- `user-settings.lua` - your machine-specific Hyprland overrides

These live in `~/.config/quickshell/` and `~/.config/hypr/` and are never overwritten by the install script.

---

## Internals

**File:** `install.sh`

### Sync with rsync

Each directory is synced with:

```sh
rsync -a --itemize-changes \
    --exclude=main-items \
    --exclude=user-settings.lua \
    "$src/" "$dest/"
```

`--itemize-changes` gives per-file output in the format `>f...` for changed files and `<f...` for received files. The script filters this with `awk '/^[><]f/ { print $2 }'` to extract just the filenames and prints them.

If anything under `hypr/` changed and Hyprland is running (`$HYPRLAND_INSTANCE_SIGNATURE` is set), the script runs `hyprctl reload`. Hyprland's auto-reload only watches `hyprland.lua` itself, so edits to the `conf/*.lua` files it `dofile`s would otherwise not take effect until the next login.

### main-items Bootstrap

On first install, if `~/.config/quickshell/main-items` doesn't exist, the script creates it with the default menu order:

```sh
printf 'appearance apps bluetooth wifi clipboard notifications emoji system power\n' \
    > "$quickshell_config/main-items"
```

This ensures the settings overlay has a working menu on a fresh install without overwriting a customized order on subsequent installs.

### Watch Mode

`inotifywait` monitors `hypr/`, `kitty/`, and `quickshell/` recursively for `modify`, `create`, `delete`, and `move` events:

```sh
inotifywait -m -r -e modify,create,delete,move hypr kitty quickshell \
    | while read -r _; do
        sync_all
    done
```

Every event triggers a full `sync_all`, which runs `rsync` on all three directories and reports any changed files.

---

[← Installation](installation.html) • [Requirements →](requirements.html)
