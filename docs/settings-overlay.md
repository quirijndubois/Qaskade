---
layout: home
title: Settings Overlay
---

# Settings Overlay

The settings overlay is Qaskade's central control panel - a floating window with fuzzy search across all configuration options.

---

## User Guide

### Opening

`Alt + S` toggles the overlay. The window is also reachable from the `menu` label on the left of the bar.

### Navigation

- **Type** to fuzzy-search across all items on the current page
- **Arrow keys** to move selection
- **Enter** to activate/select
- **Escape** to close or go back
- **Shift + Up / Down** to reorder main menu items (order is saved)

#### Vim Binds

Enable **vim binds** under Settings → System → navigation to switch to a modal navigation style:

- `h` / `l` - go back / activate item (same as Left / Right)
- `j` / `k` - move selection down / up
- `i` - enter search mode (type to fuzzy-search)
- `Escape` - exit search mode (or close/go back if not in search mode)

The setting is persisted to `~/.config/quickshell/vim-binds`.

### Pages

| Page | Access | Contents |
|---|---|---|
| Main | Default | Menu of all sections, fuzzy-searchable |
| Appearance | Main → appearance | Palettes, bar designs, lock screen, module toggles, font size |
| Wallpaper | Main → wallpaper | Browse `~/wallpapers/`, press `A` to extract palette |
| Palette | Appearance → palette | 18 color themes |
| Design | Appearance → design | 8 bar designs |
| Lock Screen | Appearance → lock screen | 5 lock designs |
| Monitor Layout | Main → monitor layout | Enable/disable monitors, resolution, scale, position, workspace assignment |
| System | Main → system | **monitors** - per-monitor scale, enable/disable, layout; **input** - mouse sensitivity, natural scroll, scroll factor; **window** - layout, blur; **navigation** - vim binds |
| Bluetooth | Main → bluetooth | Pair, connect, disconnect devices |
| WiFi | Main → wifi | Scan, connect, disconnect, and forget networks |
| Clipboard | Main → clipboard | Browse and re-copy clipboard history entries |
| Apps | Main → apps | Browse and launch `.desktop` applications |
| Notifications | Main → notifications | Full notification history with dismiss |
| Layout | System → layout | Switch between dwindle, master, scrolling, monocle |

### Special Search Behaviors

- **Absolute path** (starts with `/` or `~/`) - switches to filesystem browser mode, navigating directories. `Enter` opens the file with `xdg-open`.
- **Math expression** (`5 * (3 + 2)`, `2^16`) - evaluates and shows result. `Enter` copies the result to clipboard.
- **No results** - shows a "search web" fallback that opens DuckDuckGo.

---

## Internals

**File:** `quickshell/windows/SettingsWindow.qml`

### Window and Focus

`SettingsWindow` is a `FloatingWindow` (Quickshell type). It uses `HyprlandFocusGrab` to steal keyboard focus from other windows while open. A 80ms timer delays focus grab activation after the window appears to avoid input race conditions.

When opened from a specific monitor (e.g. via `Alt + S` on monitor 2), `moveMonitorProc` runs `hyprctl dispatch movewindow` to reposition the window to the correct monitor.

### Page System

Navigation is tracked with:
```qml
property string page: "main"
property var navStack: []
```

Navigating to a sub-page pushes the current page onto `navStack`. Escape pops it. This allows multi-level navigation (e.g. main → appearance → palette).

`onPageChanged` triggers side effects: loading Bluetooth devices, refreshing clipboard, querying monitors, etc.

### Fuzzy Search

Items are scored with a simple fuzzy matcher:

```qml
function fuzzyScore(query, str) {
    if (str === query) return 100
    if (str.startsWith(query)) return 50
    // sequential character match
    let qi = 0
    for (let i = 0; i < str.length && qi < query.length; i++) {
        if (str[i] === query[qi]) qi++
    }
    return qi === query.length ? 10 : 0
}
```

All items across the current page are filtered and sorted by score. Score 0 = hidden.

### Filesystem Browser

When `searchQuery` starts with `/` or `~/`:
```qml
property bool isPathMode: searchQuery.length > 0 && (searchQuery[0] === "/" || searchQuery.startsWith("~/"))
```

`pathDir` (everything up to the last `/`) is passed to `ls -1p` to list directory contents. Results are filtered by `pathFilter` (everything after the last `/`). `Enter` on a directory appends it to `searchQuery`; on a file calls `xdg-open`.

### Math Evaluator

If no other results match, the query is evaluated with `eval()` inside a try/catch. `^` is replaced with `**` for exponentiation. If the result is a finite number, it's shown and `Enter` copies it via `wl-copy`.

### Monitor Layout

Monitor data is fetched from `hyprctl monitors -j`. The layout page renders each monitor as a draggable rectangle positioned according to its `x`/`y` offsets, scaled to fit the view. Changes are applied live via `hyprctl keyword monitor`.

### Workspace Rules

Workspace-to-monitor assignments are read from `hyprctl workspacerules -j` and written back via `hyprctl keyword workspace rules`.

### WiFi Page

Network list is fetched with:
```bash
nmcli -e no -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list
```

Results are deduplicated by SSID and sorted - connected network first, then descending signal strength. Signal strength is shown as `▂▄▆█` bars colored green / yellow / teal / red by level.

**Keybinds on the wifi page:**

| Key | Action |
|---|---|
| `Enter` | Connect (open networks) / disconnect (active network) / open password prompt (secured) |
| `r` | Force rescan via `nmcli dev wifi rescan` then refresh list |
| `Delete` | Forget the selected network (`nmcli connection delete`) |

**Password prompt** - pressing Enter on a secured, unconnected network opens a modal overlay. Type the password (shown as `•` dots with a blinking cursor) and press Enter. Leaving the field empty and pressing Enter tries saved credentials. Escape cancels. `nmcli` stderr is shown in red if the connection fails.

### main-items Persistence

The order of items in the main menu is stored in `~/.config/quickshell/main-items` as a space-separated list. `Shift+Up`/`Shift+Down` reorders the in-memory array and immediately rewrites the file.

---

[← Lock Screen](lock-screen.html) • [IPC & Shell Root →](ipc.html)
