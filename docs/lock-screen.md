---
layout: home
title: Lock Screen
---

# Lock Screen

Qaskade includes a Wayland session lock with 5 designs, smooth enter/exit animations, and per-keystroke visual feedback.

---

## User Guide

### Locking

Press `Alt + Delete` to lock. The screen fades in from below.

Hypridle also locks automatically after 1000 seconds of inactivity (configurable in `hypr/hypridle.conf`).

### Designs

Switch designs via **Settings → Appearance → Lock Screen**. The selected design persists across restarts.

| Design | Description |
|---|---|
| `default` | Large clock, date, username, password box |
| `minimal` | Floating pill with sliding dots only |
| `clock` | Oversized 164px time, compact pill below |
| `terminal` | Console card with `user@qaskade ~ %` prompt and blinking cursor |
| `split` | Time on the left, password input on the right |
| `random` | Picks a different design on every lock |

### Typing

- Each character adds a dot that slides in from the previous dot's position
- The password box pulses (scales up briefly) on every keystroke
- Wrong password triggers a damped horizontal shake then resets the input
- `Backspace` removes last character; `Ctrl+Backspace` clears all; `Escape` clears all
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

### Design Selection

```qml
function lock() {
    const all = ["default", "minimal", "clock", "terminal", "split"]
    resolvedDesign = Theme.lockDesign === "random"
        ? all[Math.floor(Math.random() * all.length)]
        : Theme.lockDesign
    wlLock.locked = true
}
```

Random design is resolved at lock time, not stored.

### Animations

All designs share the same enter/exit animation on the `contentWrapper`:

- **Enter** - slides up from y+50 while fading in over 420ms (`OutExpo`)
- **Exit** - slides up to y-60 while fading out over 260ms (`InCubic`), then sets `wlLock.locked = false`

The **shake** on wrong password is a `SequentialAnimation` of 6 `NumberAnimation` steps moving `pwBoxShiftX` with decreasing amplitude - a damped spring approximation:

```
+13 → -11 → +9 → -6 → +3 → 0
durations: 50, 80, 70, 60, 50, 40ms
```

The **pulse** on keystroke scales the password box to 1.045 in 60ms (`OutCubic`) then returns with an overshoot bounce (`OutBack`, overshoot: 1.8).

Both `pwBoxScale` and `pwBoxShiftX` are properties on the `WlSessionLockSurface` so all designs can bind to them without duplication.

### Dot Slide Animation

Each password dot is a `Rectangle` with a `NumberAnimation on slide` from -14 to 0 (240ms `OutCubic`) and `NumberAnimation on opacity` from 0 to 1 (120ms). This makes each dot appear to slide in from the left (from where the previous dot was).

---

[← Notifications](notifications.html) • [Settings Overlay →](settings-overlay.html)
