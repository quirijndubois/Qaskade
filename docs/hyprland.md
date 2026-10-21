---
layout: home
title: Hyprland Config
---

# Hyprland Config

Qaskade uses a modern Lua-based Hyprland config (`hypr/hyprland.lua`) instead of the traditional INI format. The `hl` global provides the full Hyprland API.

---

## User Guide

### Monitors

The config ships with a two-monitor setup. Edit `hyprland.lua` to match your outputs:

```lua
hl.monitor({ output = "DP-2",    mode = "1920x1080", position = "0x0",    scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1080", position = "1920x0", scale = 1 })
```

Workspaces 1-5 default to `DP-2`, workspaces 6-9 to `HDMI-A-1`. You can also change this live from **Settings → System → Monitor Layout**.

### Programs

Three variables at the top control which apps keybinds launch:

```lua
local terminal    = "kitty"
local fileManager = "kitty -e yazi"
local browser     = "firefox"
```

### Autostart

Programs started on login:

| Program | Purpose |
|---|---|
| `kitty` | Terminal with hyfetch on launch |
| `quickshell` | The Qaskade shell itself |
| `solaar --window=hide` | Logitech peripheral manager (hidden) |
| `hypridle` | Idle/sleep management |
| `awww-daemon` | Wallpaper transition daemon |
| `wl-paste --watch cliphist store` | Clipboard history collection |

### Appearance

| Setting | Value | Notes |
|---|---|---|
| `gaps_in` | 5px | Gap between windows |
| `gaps_out` | 10px | Gap between windows and screen edge |
| `border_size` | 0 | Borders disabled |
| `rounding` | 10px | Window corner radius |
| `blur` | enabled, 5px, 3 passes | Compositor blur |
| `shadow` | enabled, range 4 | Subtle window shadows |
| `layout` | dwindle | Default tiling layout |

### Window Rules

Client maximize requests are ignored, and no app may inhibit idle:

```lua
hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "none" })
```

The settings overlay needs no rule - it is part of the bar's layer surface, not a window.

### Input

- **Mouse sensitivity** - `0.4` (adjustable live from Settings)
- **Natural scroll** - enabled on touchpad (adjustable live from Settings)
- **Scroll factor** - `0.4` (adjustable live from Settings)
- **3-finger swipe** - horizontal swipe switches workspaces
- **Mouse drag** - `Alt + LMB` to drag windows, `Alt + RMB` or `Alt + Ctrl + LMB` to resize

### Cursor Zoom

`Alt + =` and `Alt + -` zoom the cursor in steps of 0.25 between 1.0 and 3.0. `Alt + 0` resets to 1.0. Zoom is handled in Lua:

```lua
local function zoom(offset)
    local current = hl.get_config("cursor.zoom_factor") or 1.0
    current = math.max(MIN_ZOOM, math.min(MAX_ZOOM, current + offset))
    hl.config({ cursor = { zoom_factor = current } })
end
```

### Multimedia Keys

Volume, brightness, mic, and media playback keys all work out of the box. Media keys use `wpctl` for volume and `playerctl` for playback.

---

## Internals

**File:** `hypr/hyprland.lua`

### Lua API

Hyprland's Lua config replaces the traditional `.conf` format. The `hl` global exposes:

- `hl.monitor(...)` - configure outputs
- `hl.workspace_rule(...)` - assign workspaces to monitors
- `hl.config({ ... })` - set nested config values
- `hl.curve(name, { ... })` - define bezier curves
- `hl.animation({ ... })` - configure animation properties
- `hl.bind(key, action, opts)` - register keybindings
- `hl.gesture({ ... })` - register touchpad gestures
- `hl.env(key, value)` - set environment variables
- `hl.on(event, fn)` - event callbacks (e.g. `hyprland.start`)
- `hl.window_rule({ ... })` - add window rules
- `hl.get_config(path)` - read a config value at runtime

### Animation Curves

5 custom bezier curves are defined:

| Name | Points | Character |
|---|---|---|
| `easeOutQuint` | `(0.23,1), (0.32,1)` | Fast decelerate, smooth stop |
| `easeInOutCubic` | `(0.65,0.05), (0.36,1)` | Slow start and end |
| `linear` | `(0,0), (1,1)` | Constant speed |
| `almostLinear` | `(0.5,0.5), (0.75,1)` | Near-linear with slight ease-out |
| `quick` | `(0.15,0), (0.1,1)` | Instant start, smooth stop |

These are applied across windows, layers, and workspace transitions. Windows use `easeOutQuint` for a snappy feel; workspaces and fades use `almostLinear` for a smoother feel.

### User Settings Override

The last lines of `hyprland.lua` load `user-settings.lua` if it exists:

```lua
local _us = os.getenv("HOME") .. "/.config/hypr/user-settings.lua"
local _f = io.open(_us, "r")
if _f then _f:close(); dofile(_us) end
```

This file is excluded from `install.sh` syncing and git tracking, making it the right place for machine-specific overrides (different monitors, peripherals, sensitivity).

### Environment Variables

| Variable | Value | Purpose |
|---|---|---|
| `XCURSOR_SIZE` | 24 | X11 cursor size |
| `HYPRCURSOR_SIZE` | 24 | Hyprland cursor size |
| `QT_QPA_PLATFORMTHEME` | qt6ct | Qt6 theming via qt6ct |

---

[← Keybinds](keybinds.html) • [Hypridle →](hypridle.html)
