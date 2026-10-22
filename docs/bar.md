---
layout: home
title: Bar
---

# Bar

The status bar is a Quickshell `PanelWindow` anchored to the top of each monitor. Modules sit in up to three notches that hang from the top edge (left, center and right), with a hover popup card below.

---

## User Guide

### Toggling

`Alt + D` toggles the bar on and off with a smooth slide animation.

### Layout

Each module is assigned to the left, center or right notch, or turned off, in **Settings → Appearance → Bar layout**. A notch with no modules is not drawn. Within a notch, modules always appear in this order:

Menu · Workspaces · Clock · Now playing · CPU · Memory · GPU · Keep awake · Network · Bluetooth · Sound · Battery · Tray

By default everything important sits in the center notch: workspace dots, the clock, network bars, Bluetooth, sound and battery.

The center notch also shows incoming notifications and a "Copied" confirmation for a few seconds.

### Expanding Notch

The center notch grows into whatever needs attention, Dynamic Island style:

- **Volume / brightness** - widens into a level bar for 1.5 seconds
- **Notifications** - grows into a two-line banner with the app and summary
- **Clipboard** - shows a short "Copied" confirmation
- **Settings** (`Alt + S`, `Alt + Space`, …) - expands into the full settings panel
- **Wallpaper picker** (`Alt + O`) - expands into a wide strip of wallpapers; the side notches fade out while it is open

Settings and the wallpaper picker open on the focused monitor. Press `Escape` or click outside to collapse back.

### Hover Popups

Hovering any bar module opens a popup card below the bar. Moving between modules slides the popup content left or right. The popup stays open if you move the cursor into it. It closes 180ms after leaving.

---

## Internals

**Files:** `quickshell/shell.qml`, `quickshell/BarHover.qml`, `quickshell/modules/Island.qml`, `quickshell/modules/BarRow.qml`, `quickshell/modules/BarText.qml`

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

### Notches

`Island.qml` draws one notch: a `Rectangle` with only its bottom corners rounded, plus two small `Shape`s that form concave "shoulders" so the notch blends into the screen edge. Its width animates to `contentWidth + padding * 2`.

`BarRow.qml` is a `Row` holding every module for one position (`pos: "left" | "center" | "right"`). Each module is visible when its `Theme.showX` equals `pos`. Because `Row` skips hidden children, spacing stays even. Modules that poll in the background (CPU, memory, GPU, network) are wrapped in `Loader`s, so they only run where they are shown.

### Transparent Input Region

The `PanelWindow` is taller than the bar (it extends down to cover the popup card area), but only registers input for the notches and the popup card using a `mask`:

```qml
mask: Region {
    Region { item: leftIsland }
    Region { item: centerIsland }
    Region { item: rightIsland }
    Region { item: popupCard }
}
```

### Notch Modes

Each bar `PanelWindow` computes a `centerMode`: `settings` or `wallpaper` (only on the host monitor), then `osd`, `clipboard`, `notification`, and finally `modules`. The center `Island` takes its `contentWidth` / `contentHeight` from the mode, and animates both with a slight `OutBack` overshoot. Every view is a `NotchView` that fades in as the notch grows and fades out quickly as it shrinks.

`SettingsWindow` and `WallpaperPicker` exist once in `shell.qml` and are moved into the host monitor's notch with a `Binding` on `parent`.

### BarHover Singleton

`BarHover.qml` is a `pragma Singleton` that acts as a shared state machine for the popup system:

```qml
property string activeModule: ""
property Component popupComponent: null
property real anchorX: 0
property var activeScreen: null
```

Each module calls `BarHover.show(id, component, x, screen)` on hover. A 180ms `hideTimer` fires on mouse leave - `keepAlive()` cancels it if the cursor enters the popup card. The card's height follows the `implicitHeight` of the loaded popup content, so modules don't declare a height.

### Dual-Loader Slide

The popup card uses two `Loader`s that alternate, so the old content slides out while the new slides in. Slide direction is determined by comparing the new `anchorX` to the previous one - moving right slides in from the right.

### BarText

`BarText.qml` is the basic bar item: an optional glyph (`icon`), an optional dim caption (`caption`, e.g. `CPU`) and an optional value (`text`). It shows its `modulePopup` while hovered. Most simple modules extend it.

---

[← Kitty](kitty.html) • [Bar Modules →](bar-modules.html)
