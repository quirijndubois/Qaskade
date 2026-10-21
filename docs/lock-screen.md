---
layout: home
title: Lock Screen
---

# Lock Screen

Qaskade includes a Wayland session lock with a blurred-wallpaper backdrop, smooth enter/exit animations, and per-keystroke visual feedback.

---

## User Guide

### Locking

Press `Alt + Delete` to lock. The screen fades in from below.

Hypridle also locks automatically after 1000 seconds of inactivity (configurable in `hypr/hypridle.conf`).

### Layout

- Your current wallpaper, blurred and darkened toward the palette background
- Date and a large clock near the top
- Your initial, username and a rounded password field near the bottom
- A power button in the bottom-right corner that expands to suspend, hibernate, restart and shut down

### Typing

- Each character adds a dot that pops in
- The password box pulses (scales up briefly) on every keystroke
- Wrong password triggers a damped horizontal shake then resets the input
- `Backspace` removes last character; `Ctrl+Backspace` clears all; `Escape` clears all and closes the power menu
- `Enter` submits

---

## Internals

**File:** `quickshell/windows/LockScreen.qml`

### Wayland Session Lock

Lock is implemented with Quickshell's `WlSessionLock` / `WlSessionLockSurface`, which uses the `ext-session-lock-v1` Wayland protocol. When `wlLock.locked = true`, the compositor hands exclusive input and rendering to the lock surface until `wlLock.locked = false`.

### Authentication

Password is authenticated via `/usr/bin/unix_chkpwd`, a setuid helper that can verify PAM passwords without root:

```qml
authProc.command = [
    "sh", "-c",
    "IFS= read -r pw && printf '%s\\000' \"$pw\" | /usr/bin/unix_chkpwd \"$1\" nullok",
    "--", root.username
]
```

The password is piped to stdin. Exit code 0 = success, non-zero = failure.

Username is resolved at startup by running `id -un` in a `Process`.

### IPC

The lock is triggered externally by Hyprland keybinds via Quickshell IPC:

```
qs ipc call lock lock
```

`shell.qml` registers an `IpcHandler` with `target: "lock"` that calls `lockScreen.lock()`.

### Backdrop

`lock()` re-reads the current wallpaper with `awww query` before locking. The image is blurred with `MultiEffect` (from `QtQuick.Effects`) and covered by a semi-transparent `Theme.base` layer so text stays legible. If no wallpaper is found, the surface is plain `Theme.base`.

### Animations

The content shares one enter/exit animation on the `contentWrapper`:

- **Enter** - slides up from y+40 while fading in over 420ms (`OutExpo`)
- **Exit** - slides up to y-50 while fading out over 260ms (`InCubic`), then sets `wlLock.locked = false`

The **shake** on wrong password is a `SequentialAnimation` of 6 `NumberAnimation` steps moving `pwBoxShiftX` with decreasing amplitude - a damped spring approximation:

```
+13 → -11 → +9 → -6 → +3 → 0
durations: 50, 80, 70, 60, 50, 40ms
```

The **pulse** on keystroke scales the password box to 1.03 in 60ms (`OutCubic`) then returns with an overshoot bounce (`OutBack`, overshoot: 1.8).

`pwBoxScale` and `pwBoxShiftX` are properties on the `WlSessionLockSurface`.

### Dot Animation

Each password dot is a `Rectangle` with a `NumberAnimation on scale` from 0.4 to 1 (160ms `OutBack`) and `NumberAnimation on opacity` from 0 to 1 (120ms).

---

[← Notifications](notifications.html) • [Settings Overlay →](settings-overlay.html)
