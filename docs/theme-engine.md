---
layout: home
title: Theme Engine
---

# Theme Engine

The theme engine provides live-animated color transitions, 18 built-in palettes, custom palette support, and system-wide color syncing.

---

## User Guide

### Switching Palettes

Open **Settings → Appearance** and select any palette. The transition animates over 500ms.

### Available Palettes

**Dark:** Catppuccin Mocha (default), Macchiato, Frappe, Tokyo Night, Gruvbox, Nord, Dracula, Rose Pine, One Dark, Everforest, Solarized Dark

**Light:** Catppuccin Latte, Solarized Light, Gruvbox Light, Nord Light, Rose Pine Dawn, One Light

### System Sync

Every palette change automatically updates:

| Target | How | Running apps |
|---|---|---|
| **Kitty** | `update-kitty-colors.sh` over remote-control sockets | Live |
| **Firefox** | pywalfox (if installed) | Live |
| **Hyprland borders** | `hyprctl eval` | Live |
| **GTK 3** | Generated theme `Qaskade-A` / `Qaskade-B` built on adw-gtk3 | Live - each sync switches to the other name, which makes GTK 3 reload |
| **GTK 4 / libadwaita** | `~/.config/gtk-4.0/gtk.css` + gsettings `color-scheme` and `accent-color` | Light/dark and accent live; full palette for apps started afterwards (libadwaita only reads custom colors at startup) |
| **Qt / KDE apps** | `kdeglobals` color groups + Breeze style, then a `KGlobalSettings` D-Bus notification | Live (needs `QT_QPA_PLATFORMTHEME=kde`, set in `hypr/conf/env.lua`) |
| **Electron, Chromium, portals** | gsettings `color-scheme` | Light/dark live |

GTK and Qt are handled by `quickshell/scripts/sync-system-colors.py`, which `Theme.qml` runs (debounced by 150ms) with the 11 palette colors.

Apps started through D-Bus or systemd (Dolphin opened from another app, portals, …) don't inherit Hyprland's environment, so `hypr/conf/autostart.lua` exports `QT_QPA_PLATFORMTHEME` with `dbus-update-activation-environment`. As a fallback, the qt6ct palette is kept in sync too: an app that still starts with `qt6ct` opens with the right colors, but won't update live.

### One Visual Language

There is a single bar design. Everything in the shell (bar, popups, settings, OSD, lock screen) draws from the same design tokens in `Theme.qml`, so a palette change restyles all of it at once.

---

## Internals

**File:** `quickshell/Theme.qml`

### Singleton Architecture

`Theme.qml` is a `pragma Singleton` - a single instance shared across all QML files. Any file can read `Theme.base`, `Theme.accent`, etc. directly without passing references.

### Animated Color Properties

Every color property has a `Behavior` that animates transitions:

```qml
property color blue: "#89b4fa"
Behavior on blue { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
```

When `applyPalette("nord")` is called, all 11 color properties update simultaneously and animate to their new values over 500ms.

### Target Colors

Rapid palette switches would send intermediate animated color values to Kitty/Firefox if using the animated properties directly. To avoid this, a `_target` object stores the intended final values:

```qml
property var _target: ({ base: "#1e1e2e", ... })
```

`applyPalette` sets `_target` first, then sets the animated properties. External sync scripts always read from `_target`.

### Palette Application

```qml
function applyPalette(n) {
    let b, sf, bo, tx, sx, bl, gn, rd, ye, te, pu
    if (n === "nord") {
        b="#2e3440"; sf="#3b4252"; ...
    }
    // ... 17 more palette branches
    root._target = { base: b, ... }
    base = b; surface = sf; ...
}
```

Each palette defines 11 values: `base`, `surface`, `border`, `text`, `subtext`, `blue`, `green`, `red`, `yellow`, `teal`, `purple`.

### Custom Palette

`loadCustomPalette()` reads `~/.config/quickshell/custom-palette` (written by `extract-palette.py`) and parses the 11 space-separated hex values:

```qml
function loadCustomPalette() {
    customPaletteProc.running = true
}
Process {
    id: customPaletteProc
    command: ["cat", homeDir + "/.config/quickshell/custom-palette"]
    stdout: StdioCollector {
        onStreamFinished: {
            const parts = this.text.trim().split(" ")
            // assign to base, surface, border, text, subtext, blue, green, red, yellow, teal, purple
        }
    }
}
```

### Design Tokens

Alongside the palette, `Theme.qml` exposes the shared design tokens:

- **Fonts** - `fontFamily` is the first installed of Inter, SF Pro Text, Geist, Noto Sans or Cantarell (falling back to `sans-serif`); `monoFamily` (JetBrains Mono) is used only for clipboard entries, file paths and IP addresses; `iconFamily` is Symbols Nerd Font Mono
- **Type scale** - `textXs` 11 … `textXl` 24 px
- **Radii** - `radiusSm` 6, `radiusMd` 10, `radiusLg` 16
- **Overlays** - `hairline`, `hover`, `selected` and `track` are the text color at low alpha, so they work on dark and light palettes
- **Icons** - `Theme.icons` maps names like `bluetooth` or `volumeHigh` to Nerd Font glyphs; use them through `components/Icon.qml`

Reusable building blocks live in `quickshell/components/` (`Label`, `Icon`, `ListRow`, `PageHeader`, `Toggle`, `Slider`, `Meter`, …).

### Kitty Color Sync

`update-kitty-colors.sh` iterates `/tmp/kitty-*` Unix sockets and sends a color update to each live Kitty instance using Kitty's remote control protocol (`kitty @ --to unix:... set-colors`). This means all open terminals update instantly without restart.

---

[← IPC & Shell Root](ipc.html) • [Palette Extraction →](palette-extraction.html)
