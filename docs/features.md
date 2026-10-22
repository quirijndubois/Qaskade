---
layout: home
title: Features
---

# Features

## Custom Quickshell Panel

- **Modular bar** - workspaces, clock, battery, CPU (per-core), GPU (NVIDIA), memory, audio, network, Bluetooth, MPRIS music player, system tray, and sleep inhibit - each independently toggleable
- **Hover popups** - every module shows rich info on hover (CPU per-core chart + top processes, GPU utilization + VRAM, memory bar + top processes, per-app audio sliders, battery time remaining, music controls with seek bar, network IP/SSID, Bluetooth device list)
- **Notification center** - incoming notifications appear briefly in the center notch. Hover it for the 5 most recent notifications with per-item dismiss and clear-all. Full history in settings.
- **MPRIS music visualization** - animated bars when music plays; the popup shows album art, a seek bar and transport controls
- **System tray** - any StatusNotifierItem app

## Settings Overlay (`Alt+S`)

- **Fuzzy search** across wallpapers, palettes, layouts, bar modules, apps, Bluetooth devices, clipboard history, monitors, and system settings
- **Appearance page** - choose a color palette, place bar modules left/center/right, and manage wallpaper tags
- **Monitor arrangement page** - place monitors beside each other and assign workspaces to specific monitors
- **System settings page** - sections for displays (scale, enable/disable, arrangement), mouse and touchpad (pointer speed, natural scrolling, scroll speed), windows (tiling layout, blur), and the shell (bar text size, Vim keys)
- **Notification history** - view recent notifications, manually dismiss, or clear all
- **Filesystem browser** - navigate directories and open files with `xdg-open`
- **Math evaluator** - type expressions like `5 * (3 + 2)`, `2^16`, `(100 - 32) / 1.8` and get instant results
- **Keyboard-driven** - full navigation with arrows, Enter, Escape; reorder menu with `Shift+Up`/`Shift+Down` (persisted); optional vim binds mode (`hjkl` + `i` for search)

## Theming & Layout

- **18 color palettes** - Dark: Catppuccin Mocha/Macchiato/Frappe, Tokyo Night, Gruvbox, Nord, Dracula, Rose Pine, One Dark, Everforest, Solarized Dark. Light: Catppuccin Latte, Solarized Light, Gruvbox Light, Nord Light, Rose Pine Dawn, One Light
- **Smooth transitions** - switch themes with animated 500ms transitions, live synced to Kitty, Firefox, and system dark/light mode
- **Wallpaper extraction** - press `A` on any wallpaper to automatically extract dominant colors and apply them system-wide with WCAG-enforced contrast
- **Random wallpaper** - `Alt+R` picks a random wallpaper with animated transition and applies extracted palette
- **One cohesive design** - a notch-style bar whose center notch expands into settings, the wallpaper picker, notifications and the volume/brightness indicator (Dynamic Island style)
- **4 Hyprland layouts** - dwindle, master, scrolling, monocle
- **Custom animations** - 5 hand-tuned bezier curves for windows, workspaces, fade, and layers
- **Adjustable bar font size** - customize text size while maintaining proportions

## System Management

- **Monitor layout** - configure position, scale, enable/disable monitors, assign workspaces
- **Wallpaper manager** - browse and apply images with smooth transitions (fade, slide, wipe, wave, grow), per-monitor
- **App launcher** - browse `.desktop` entries with icons
- **Bluetooth manager** - pair, connect, disconnect devices from settings
- **WiFi manager** - scan networks, connect with password entry, disconnect, and forget saved networks
- **Clipboard history** - browse and re-copy entries via `cliphist`; searchable from fuzzy finder
- **System settings** - live configuration via `hyprctl` and persistent `user-settings.lua`
- **Blur toggle** - enable/disable Hyprland compositor blur

## Lock Screen

- **Wayland session lock** - password auth via `unix_chkpwd`. Lock with `Alt+Delete`.
- **Blurred wallpaper backdrop** - large clock, username and a rounded password field; power menu in the corner
- **Typing animations** - each dot pops in; password box pulses on keystroke; wrong password triggers shake

---

[← Home](index.html) • [Installation →](installation.html)
