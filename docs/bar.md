---
layout: home
title: Bar
---

# Bar

The status bar is a Quickshell `PanelWindow` anchored to the top of each monitor. It renders bar modules on the left and right, workspaces in the center, and a hover popup card below.

---

## User Guide

### Toggling

`Alt + D` toggles the bar on and off with a smooth slide animation.

### Layout

Modules are arranged in three groups:

**Left** - Menu, Clock, Battery, CPU, Memory, GPU

**Center** - Workspaces (also shows notification summaries and clipboard confirmations)

**Right** - Music, Audio, Bluetooth, Network, Sleep Inhibit, System Tray

Each module can be independently shown or hidden via **Settings → Appearance**.

### Bar Designs

8 visual styles are available via **Settings → Appearance → Design**:

| Design | Description |
|---|---|
| `default` | Solid bar with separator pipes |
| `compact` | Reduced padding, tighter |
| `islands` | Three floating rounded rectangles (left, center, right) |
| `pills` | Each module is its own rounded chip on a transparent bar |
| `bold` | Larger text, heavier separators |
| `minimal` | Minimal decoration |
| `clean` | Sans-serif font |
| `hacker` | Retro terminal style |

### Hover Popups

Hovering any bar module opens a popup card below the bar. Moving between modules slides the popup content left or right. The popup stays open if you move the cursor into it. It closes 180ms after leaving.

---

## Internals

**Files:** `quickshell/shell.qml`, `quickshell/BarHover.qml`, `quickshell/modules/BarText.qml`, `quickshell/modules/Separator.qml`

### Multi-Monitor with Variants

The bar is instantiated once per screen using Quickshell's `Variants`:

```qml
Variants {
    model: Quickshell.screens
    delegate: Component {
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            exclusiveZone: root.barVisible ? Theme.barHeight : 0
        }
    }
}
```

`exclusiveZone` reserves space at the top of the screen so windows don't overlap the bar.

### Transparent Input Region

The `PanelWindow` is taller than the bar (it extends down to cover the popup card area), but only registers input for the bar strip and popup card using a `mask`:

```qml
mask: Region {
    Region { item: barStrip }
    Region { item: popupCard }
}
```

This lets mouse events pass through the transparent gap between bar and popup.

### Bar Visibility

When `barVisible` is false, the bar strip slides off screen:

```qml
y: root.barVisible ? 0 : -(Theme.barHeight + Theme.gapsOut + 10)
Behavior on y { NumberAnimation { duration: 300; easing: OutCubic } }
```

`exclusiveZone` is also set to 0 so windows expand to fill the top.

### BarHover Singleton

`BarHover.qml` is a `pragma Singleton` that acts as a shared state machine for the popup system:

```qml
property string activeModule: ""
property Component popupComponent: null
property real anchorX: 0
property real popupH: 104
property var activeScreen: null
```

Each module calls `BarHover.show(id, component, x, height, screen)` on hover. A 180ms `hideTimer` fires on mouse leave - `keepAlive()` cancels it if the cursor enters the popup card.

### Dual-Loader Slide

The popup card uses two `Loader`s that alternate, so the old content slides out while the new slides in:

```
Module A → Module B:
  loaderB loads new component, animates from +width to margin
  loaderA animates from margin to -width (slides out left or right)
  activeLoader flips between 0 and 1
```

Slide direction is determined by comparing the new `anchorX` to the previous one - moving right slides in from the right.

### BarText

`BarText.qml` is a simple `Text` subclass with `JetBrains Mono`, the configured `barFontSize`, and `barFontBold`. All text-based modules extend it.

### Separator

`Separator.qml` renders the pipe character (`separatorText` from Theme, default `  │  `) in `Theme.border` color. Separators are hidden in `pills` mode.

---

[← Kitty](kitty.html) • [Bar Modules →](bar-modules.html)
