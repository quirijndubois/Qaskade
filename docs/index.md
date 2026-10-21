---
layout: home
title: Qaskade
---

# Qaskade

A keyboard-driven [Hyprland](https://hyprland.org) desktop shell powered by [Quickshell](https://quickshell.outfoxxed.me/). Modular, fully themeable, and documented end to end.

![Demo](https://github.com/quirijndubois/Qaskade/raw/main/demo.gif)

```bash
git clone https://github.com/quirijndubois/Qaskade.git
cd Qaskade
./install.sh
```

---

## Getting Started

- [Installation](installation.html) - dependencies, setup steps, Firefox sync
- [Install Script](install-script.html) - how `install.sh` works, watch mode, what gets skipped
- [Requirements](requirements.html) - full dependency list
- [Keybinds](keybinds.html) - all keybindings

---

## Config Files

Every file in the repo that gets synced to `~/.config/`:

- [Hyprland](hyprland.html) - monitors, autostart, animations, keybinds, window rules
- [Hypridle](hypridle.html) - idle timeouts, display sleep, auto-lock
- [Kitty](kitty.html) - terminal opacity, remote control, live color sync

---

## Shell Components

The Quickshell-based shell, each documented with a user guide and internal implementation details:

- [Bar](bar.html) - the status bar, notch layout, hover popup system, multi-monitor
- [Bar Modules](bar-modules.html) - CPU, memory, GPU, audio, music, battery, clock, Bluetooth, network, workspaces, tray
- [Notifications](notifications.html) - D-Bus notification server, in-bar display, history
- [Lock Screen](lock-screen.html) - Wayland session lock, blurred backdrop, animations, authentication
- [Settings Overlay](settings-overlay.html) - fuzzy search, all pages, filesystem browser, math evaluator
- [IPC & Shell Root](ipc.html) - how keybinds and scripts communicate with the running shell

---

## Theming

- [Theme Engine](theme-engine.html) - animated palette switching, system-wide sync, design tokens
- [Palette Extraction](palette-extraction.html) - extracting colors from wallpapers, WCAG enforcement, jitter
- [Palettes](themes.html) - all 18 built-in color themes

---

## Help

- [Troubleshooting](troubleshooting.html) - common issues and fixes
