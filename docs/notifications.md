---
layout: home
title: Notifications
---

# Notifications

Qaskade registers as the system notification daemon and displays notifications in the bar and a hover popup.

---

## User Guide

### In-bar Display

When a notification arrives, the workspace pill in the center of the bar animates wider and shows the app name and summary for 5 seconds. Colors reflect urgency:

- **Normal** - blue
- **Low** - muted/dim
- **Critical** - red

### Notification Popup

Hover the workspace pill to open the notification popup, which shows the 5 most recent notifications. Each entry displays:

- A colored left-border strip (blue / dim / red by urgency)
- App name
- Summary
- An `×` dismiss button

**Clear all** at the bottom dismisses all entries with a staggered slide-out animation (50ms delay between items).

### Notification History

Full history is accessible in **Settings → Notifications**. Entries can be dismissed individually or all at once.

### Conflict with dunst

Quickshell and dunst both register as `org.freedesktop.Notifications` on D-Bus. If dunst starts first it wins and Quickshell won't receive any notifications. Mask it:

```bash
systemctl --user mask dunst
```

---

## Internals

**Files:** `quickshell/Notifications.qml`, `quickshell/modules/WorkspacesModule.qml`, `quickshell/shell.qml`

### Singleton History Store

`Notifications.qml` is a `pragma Singleton`. It wraps a `NotificationServer` and maintains a plain JS array of notification objects:

```qml
property var history: []
property int _nextId: 0

NotificationServer {
    keepOnReload: true
    onNotification: function(n) {
        root._nextId++
        const entry = { id: root._nextId, appName, summary, body, urgency }
        const next = root.history.concat([entry])
        root.history = next.length > 50 ? next.slice(-50) : next
        root.newNotification(entry)
    }
}
```

History is capped at 50 entries. Entries are plain JS objects (not QML notification objects) so they survive notification expiry or app close. `keepOnReload: true` keeps the D-Bus registration alive across Quickshell reloads.

### In-bar Notification State

`shell.qml`'s bar strip listens to `Notifications.newNotification` via a `Connections` block and stores the current notification in local properties (`notifApp`, `notifSummary`, `notifUrgency`, `notifActive`). A `Timer` of 5000ms resets `notifActive`.

The center of the bar has three overlapping `Row` items:
1. `centerRow` - workspace pill (normal state)
2. `notifCenterRow` - notification display
3. `clipboardCenterRow` - clipboard copy confirmation

Each fades in/out using `opacity` with a 150ms `InOutQuad` transition. The pill's `width` also animates to fit the new content (`OutCubic`, 220ms).

### Dismiss Animation

Each notification item in the popup has a `SequentialAnimation`:

```qml
ParallelAnimation {
    NumberAnimation { property: "x"; to: 160; duration: 180; easing: InCubic }
    NumberAnimation { property: "opacity"; to: 0; duration: 140; easing: InCubic }
}
ScriptAction { script: Notifications.dismiss(id) }
```

"Clear all" staggers this with a 50ms delay per item using individual per-item `Timer`s, then calls `Notifications.clearAll()` after all animations finish.

---

[← Bar Modules](bar-modules.html) • [Lock Screen →](lock-screen.html)
