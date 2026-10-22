---
layout: home
title: Lock Screen
---

# Lock Screen

Qaskade includes a Wayland session lock with a blurred-wallpaper backdrop, smooth enter/exit animations, and per-keystroke visual feedback.

---

## User Guide

### Locking

Press `Alt + Delete` to lock. The lock screen grows out of the center notch of the bar until it covers the screen, blurring the desktop behind it, and the bar clock grows into the big lock-screen clock. Unlocking plays it in reverse.

Hypridle also locks automatically after 1000 seconds of inactivity (configurable in `hypr/hypridle.conf`).

### Layout

- Your current wallpaper, blurred and darkened toward the palette background
- Date and a large clock near the top
- Your initial, username and a rounded password field near the bottom
- A power button in the bottom-right corner that expands to suspend, hibernate, restart and shut down

### Typing

- Each character adds a dot that grows in, and the row of dots glides to stay centered; deleting shrinks dots out
- The dots pulse while the password is being checked, and turn red with the field when it's wrong
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

`shell.qml` registers an `IpcHandler` with `target: "lock"`. `lock()` collects the on-screen rectangle and corner radius of every monitor's center notch (`notchRect` / `notchRadius` on each bar panel, skipped while the bar is hidden) and passes them to `lockScreen.lock(notches)`.

`lockInstant()` locks without the snapshot or reveal. Hypridle's `before_sleep_cmd` uses it, because taking the snapshot first would delay the lock and the desktop could briefly show on resume.

### Backdrop

The backdrop is the blurred snapshot (see below). Without a snapshot, it falls back to the current wallpaper, which `lock()` re-reads with `awww query` before locking. The image is blurred with `MultiEffect` (from `QtQuick.Effects`) and covered by a semi-transparent `Theme.base` layer so text stays legible. If no wallpaper is found, the surface is plain `Theme.base`.

### Reveal From the Notch

A session lock surface can't be transparent: once locked, Hyprland stops drawing the desktop behind it. So before locking, `lock()` runs `grim -o <output>` for every screen (in parallel, each capped at 1 second) into `$XDG_RUNTIME_DIR/qaskade-lock/`, and only then sets `wlLock.locked = true`. The snapshots are deleted on unlock.

Each lock surface shows its snapshot at the bottom. Above it is a "sheet" whose geometry is interpolated by `reveal` (0 → 1) from the notch rectangle to the full screen, with the notch's bottom corner radius shrinking to 0. Inside the sheet, a blurred copy of the same snapshot is drawn through a `MultiEffect` mask, so the blur spreads out from the notch. A `Theme.base` tint is drawn through the same mask, and its opacity rises to 0.45 with `reveal` to keep text legible. The blur and tint are static layers, so only the mask and the tint opacity change per frame.

The big clock lives outside the fading content. `lock()` also passes the on-screen rect of the bar clock (`clockRect()` on each bar panel, `null` when the clock is hidden or the center notch shows something else). The big clock starts scaled by `barFontSize / 112` and centered on that rect, and its scale and position are interpolated by the same `reveal`, so it grows into place with the sheet and shrinks back into the bar on unlock.

- **Lock** - `reveal` animates to 1 over 700ms; after 280ms the content enter animation starts.
- **Unlock** - the content exits, then `reveal` animates back to 0 over 460ms so the sheet shrinks into the notch, and then the lock is released.

A screen without a snapshot or notch entry (bar hidden, `grim` failed, `lockInstant`, a monitor plugged in while locked) skips the reveal and starts fully covered.

### Animations

The content shares one enter/exit animation on the `contentWrapper`:

- **Enter** - slides up from y+40 while fading in over 420ms (`OutExpo`)
- **Exit** - slides up to y-50 while fading out over 260ms (`InCubic`), then sets `wlLock.locked = false`

The **shake** on wrong password is a `SequentialAnimation` of 6 `NumberAnimation` steps moving `pwBoxShiftX` with decreasing amplitude - a damped spring approximation:

```
+13 → -11 → +9 → -6 → +3 → 0
durations: 50, 80, 70, 60, 50, 40ms
```


`pwBoxScale` and `pwBoxShiftX` are properties on the `WlSessionLockSurface`.

### Dot Animation

The dot row has a fixed `Repeater` of 16 slots instead of a model equal to the password length, since changing an integer model rebuilds every delegate and replays all their animations. Each slot is shown when `index < passwordInput.length`. A shown slot is 15px wide and a hidden one 0px, with a `Behavior` on width (180ms `OutCubic`), so the centered row slides smoothly instead of jumping a dot's width. The 7px dot inside scales and fades in or out (200ms / 150ms `OutCubic`). While `authRunning`, the row's opacity pulses between 1 and 0.35. The "Enter password" placeholder crossfades with the dots.

### Background Dimming

When the lock starts, `dim` animates from 0 to 1 over 10 seconds (`InOutSine`). A black layer, drawn through the same sheet mask, has opacity `0.8 × dim`, so the background ends at 20% brightness. The clock and sign-in sit above it and stay bright. On unlock, `dim` fades back to 0 while the content exits.

---

[← Notifications](notifications.html) • [Settings Overlay →](settings-overlay.html)
