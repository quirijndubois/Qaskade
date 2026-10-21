# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Qaskade is a Hyprland desktop "rice": a Quickshell (QML) shell plus the Hyprland, hypridle and Kitty configs it depends on. There is no build step, test suite or linter. The repo is the source of truth, and `install.sh` rsyncs `hypr/`, `kitty/` and `quickshell/` into `~/.config/`.

The entire shell and hyprland setup must be confined to this project repo. Running install.sh on another one of my machines should replicate the entire rice.

- `./install.sh` does a one-shot sync. `./install.sh --watch` re-syncs on every change (inotifywait), which is how changes are tested live.
- The sync excludes the user-specific files `quickshell/main-items` and `hypr/user-settings.lua`.
- **Only edit files in this repo. Do not copy them into `~/.config/` or run `install.sh`.** The user deploys changes themselves.

Because the code runs from `~/.config`, the QML and scripts reference `$HOME/.config/quickshell/scripts/...` and `$HOME/.config/quickshell/<state-file>` with absolute paths, not paths relative to the repo.

`docs/` is a Jekyll (minima) GitHub Pages site with the user guide and an "Internals" write-up for each feature. Update the matching page when you change behavior it describes.

## Quickshell architecture

- **`quickshell/shell.qml`** is the root `ShellRoot`. It owns global state (`settingsOpen`, `barVisible`, `sessionLocked`, `wallpaperPickerOpen`), instantiates the windows, runs background `Process`es (clipboard watcher, awww-daemon watchdog), and builds the bar per screen through `Variants`. It also exposes every `IpcHandler` target (`settings`, `clipboard`, `lock`, `statusbar`, `theme`, `osd`, `wallpaper`). Hyprland keybinds and the scripts call these with `qs ipc -c default call <target> <fn>`. If you rename or add an IPC function, check `hypr/conf/keybindings.lua` and `quickshell/scripts/` for callers.
- **Singletons** (`pragma Singleton`, registered in `quickshell/qmldir`) are `Theme`, `Notifications`, `OsdState`, `BarHover` and `InhibitState`. Each subdirectory (`modules/`, `windows/`) has its own `qmldir`. A new QML type must be registered there.
- **`Theme.qml`** is the central config and state singleton:
  - It holds the palettes. `applyPalette(name)` is a big if-chain over the built-in palettes, each with 11 colors. The colors animate through `Behavior`s, and `_target` holds the final values that are pushed to external apps so they never see animation frames.
  - It holds the design tokens (fonts, type scale, radii, `hairline`/`hover`/`selected`/`track` overlays, `icons` glyph map) and the bar module positions (`showClock`, … each `left`/`center`/`right`/`disabled`). There is one bar design; don't reintroduce design variants.
  - On every palette change it syncs colors out to Kitty (`update-kitty-colors.sh` over Kitty remote-control sockets), Firefox (pywalfox), Hyprland borders, and GTK 3/4 + Qt/KDE via `scripts/sync-system-colors.py`. GTK 3 goes live by alternating between two generated theme names (`Qaskade-A`/`Qaskade-B`); Qt goes live through the KDE platform theme (`QT_QPA_PLATFORMTHEME=kde`) and a `KGlobalSettings` D-Bus signal; libadwaita can only pick up accent and light/dark live.
  - It persists every setting as a small plain-text file under `~/.config/quickshell/` (`theme`, `bar-modules`, `custom-palette`, …). `saveToFile()` writes them and `Process { cat … }` loaders read them back. Follow that pattern for new persistent settings.
- **`windows/SettingsWindow.qml`** (~5k lines) is the keyboard-driven overlay: launcher, palette, wallpapers, bluetooth, wifi, clipboard, system settings, power, emoji, and more. It is a single component switched by `root.page`. When you add a page, add it to each `root.page === "..."` dispatch chain: page-enter loading, Enter/activate, and the `maxIdx` navigation bounds. System settings apply live through `hyprctl` and persist into `~/.config/hypr/user-settings.lua`.
- **`components/`** holds shared UI pieces (`Label`, `Icon`, `ListRow`, `PageHeader`, `Toggle`, `Slider`, `Meter`, …). Build new UI from these instead of raw `Text`/`Rectangle` styling.
- **`modules/`** contains the bar widgets. `BarRow` holds every module for one position, and `shell.qml` places three `Island` notches (left/center/right). Hover popups are `Component`s passed to `BarHover.show(id, comp, x, screen)`; the card sizes itself to the content's `implicitHeight`.
- **The center notch is the only place panels appear.** Settings, the wallpaper picker, the OSD, notifications and the clipboard confirmation are modes of the center `Island` (`panel.centerMode` in `shell.qml`), not separate windows. `SettingsWindow` and `WallpaperPicker` are plain Items instantiated once and reparented into the host monitor's notch. New overlays should become another mode rather than a new window. The lock screen is the exception (it needs its own session-lock surface).
- **`scripts/`** holds helpers that QML runs through `Process`:
  - `extract-palette.py` turns a wallpaper into `custom-palette` and then triggers `theme setCustom` over IPC.
  - `random-wallpaper.sh` sets a random wallpaper with awww.
  - `auto-tag-wallpaper.py` tags wallpapers through a local Ollama model.
  - `gen-thumbs.sh` maintains the wallpaper thumbnail cache.
  - `list_apps.py` supplies the app launcher.

## Hyprland config

The Hyprland config is written in **Lua**, not hyprlang. `hypr/hyprland.lua` `dofile`s each file in `hypr/conf/*.lua` (monitors, autostart, env, appearance, layouts, rules, input, keybindings). It then loads the untracked `~/.config/hypr/user-settings.lua` if that file exists. `hypr/hypridle.conf` uses the normal hypridle syntax.
