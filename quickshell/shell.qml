//@ pragma UseQApplication
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import "./components"
import "./modules"
import "./windows"

ShellRoot {
    id: root

    property bool settingsOpen: false
    property bool sessionLocked: false
    property bool barVisible: true
    property bool wallpaperPickerOpen: false

    // Monitor whose center notch hosts the settings / wallpaper panel.
    property string hostMonitor: ""

    function _claimHost() {
        hostMonitor = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }

    // Only one large panel at a time.
    onSettingsOpenChanged: if (settingsOpen) { wallpaperPickerOpen = false; _claimHost() }
    onWallpaperPickerOpenChanged: if (wallpaperPickerOpen) { settingsOpen = false; _claimHost() }

    signal clipboardCopied()

    IpcHandler {
        target: "settings"

        function toggle()      { root.settingsOpen = !root.settingsOpen }
        function open()        { root.settingsOpen = true }
        function openApps()    { settingsWindow.navigate("apps"); root.settingsOpen = true }
        function openSearch()  { settingsWindow.navigate("search"); root.settingsOpen = true }
        function openEmoji()   { settingsWindow.navigate("emoji"); root.settingsOpen = true }
        function close()       { root.settingsOpen = false }
    }

    IpcHandler {
        target: "clipboard"

        function copied() { root.clipboardCopied() }
    }

    IpcHandler {
        target: "lock"

        // Grows the lock screen out of the center notch of each monitor
        function lock() {
            root.sessionLocked = true
            const notches = {}
            for (const p of barVariants.instances)
                if (p.modelData && root.barVisible) notches[p.modelData.name] = { rect: p.notchRect, radius: p.notchRadius, clock: p.clockRect() }
            lockScreen.lock(notches)
        }

        // No snapshot or animation; for locking right before suspend
        function lockInstant() {
            root.sessionLocked = true
            lockScreen.lock(null)
        }
    }

    IpcHandler {
        target: "statusbar"

        function toggle() { root.barVisible = !root.barVisible }
        function show()   { root.barVisible = true }
        function hide()   { root.barVisible = false }
    }

    IpcHandler {
        target: "theme"

        function setCustom() { Theme.loadCustomPalette() }
    }

    IpcHandler {
        target: "osd"

        function brightness(pct: string): void { OsdState.showBrightness(parseInt(pct)) }
    }

    IpcHandler {
        target: "wallpaper"

        function show()   { root.wallpaperPickerOpen = true }
        function hide()   { root.wallpaperPickerOpen = false }
        function toggle() { root.wallpaperPickerOpen = !root.wallpaperPickerOpen }
    }

    LockScreen {
        id: lockScreen
        onLockReleased: root.sessionLocked = false
    }

    Process {
        command: ["sh", "-c", "pgrep -x awww-daemon > /dev/null || awww-daemon"]
        running: true
    }

    Process {
        command: ["sh", "-c", "last=''; while sleep 0.5; do current=$(wl-paste 2>/dev/null); if [ \"$current\" != \"$last\" ] && [ -n \"$current\" ]; then sleep 0.05; if [ \"$(wl-paste 2>/dev/null)\" = \"$current\" ]; then quickshell ipc -c default call clipboard copied 2>/dev/null || true; last=\"$current\"; fi; fi; done"]
        running: true
    }

    // Single instances, reparented into the host monitor's center notch.
    SettingsWindow {
        id: settingsWindow
        open: root.settingsOpen
        onCloseRequested: { root.settingsOpen = false }
    }

    WallpaperPicker {
        id: wallpaperPicker
        shown: root.wallpaperPickerOpen
        onCloseRequested: { root.wallpaperPickerOpen = false }
    }

    Connections {
        target: settingsWindow
        function onClipboardCopyTriggered() {
            root.clipboardCopied()
        }
    }

    Process {
        id: monitorReenableProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // Debounce: hotplug events can fire in bursts
    Timer {
        id: monitorReenableTimer
        interval: 1000
        repeat: false
        onTriggered: {
            monitorReenableProc.command = ["sh", "-c",
                "if [ -f \"$HOME/.config/hypr/user-settings.lua\" ]; then" +
                "  sed -i 's/, disabled = true//g' \"$HOME/.config/hypr/user-settings.lua\";" +
                "fi; hyprctl reload"
            ]
            monitorReenableProc.running = false
            monitorReenableProc.running = true
        }
    }

    // Re-enable all monitors whenever the connected monitor set changes,
    // so a disconnected monitor can never leave the system with no active output.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            monitorReenableTimer.restart()
        }
    }

    Variants {
        id: barVariants
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: panel
                required property var modelData
                screen: modelData

                anchors { top: true; left: true; right: true }
                exclusiveZone: root.barVisible ? Theme.barHeight : 0
                implicitHeight: Theme.barHeight + 560

                color: "transparent"

                mask: Region {
                    Region { item: leftIsland }
                    Region { item: centerIsland }
                    Region { item: rightIsland }
                    Region { item: popupCard }
                }

                property var hyprMonitor: Hyprland.monitorFor(modelData)
                // Where the center notch sits on screen; the lock screen grows out of it
                readonly property rect notchRect: Qt.rect(centerIsland.x, barStrip.y + centerIsland.y, centerIsland.width, centerIsland.height)
                readonly property real notchRadius: centerIsland.cornerRadius

                // On-screen rect of this bar's clock, or null when none is showing
                function clockRect() {
                    for (const row of [leftRow, centerRow, rightRow]) {
                        const c = row.clock
                        if (!c.visible || c.width <= 0) continue
                        if (row === centerRow && centerIsland.mode !== "modules") return null
                        const p = c.mapToItem(null, 0, 0)
                        return Qt.rect(p.x, p.y, c.width, c.height)
                    }
                    return null
                }

                // ── Center notch modes ────────────────────────────────
                // Settings and the wallpaper picker only expand on the host
                // monitor; transient states (OSD, clipboard, notification)
                // show on every monitor.
                readonly property bool isHost: !!hyprMonitor && hyprMonitor.name === root.hostMonitor
                readonly property string panelMode: isHost && root.settingsOpen ? "settings"
                                                  : isHost && root.wallpaperPickerOpen ? "wallpaper"
                                                  : ""
                readonly property string centerMode: panelMode !== "" ? panelMode
                                                   : OsdState.active ? "osd"
                                                   : barStrip.clipboardActive ? "clipboard"
                                                   : barStrip.notifActive ? "notification"
                                                   : "modules"

                // Keyboard input goes to whichever large panel is open here.
                WlrLayershell.keyboardFocus: panelMode !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                // Clicking anywhere outside the notch closes the open panel.
                property bool grabReady: false
                onPanelModeChanged: {
                    grabReady = false
                    if (panelMode !== "") grabTimer.restart()
                }
                Timer { id: grabTimer; interval: 80; onTriggered: panel.grabReady = true }
                HyprlandFocusGrab {
                    windows: [panel]
                    active: panel.panelMode !== "" && panel.grabReady
                    onCleared: {
                        root.settingsOpen = false
                        root.wallpaperPickerOpen = false
                    }
                }

                // Move the shared panels into this monitor's notch while it hosts.
                Binding { target: settingsWindow;  property: "parent"; value: settingsSlot;  when: panel.isHost }
                Binding { target: wallpaperPicker; property: "parent"; value: wallpaperSlot; when: panel.isHost }

                // ── Bar ───────────────────────────────────────────────
                // Up to three notches hang from the top edge: left, center
                // and right. Each only appears when it has visible modules.
                Item {
                    id: barStrip
                    anchors { left: parent.left; right: parent.right }
                    height: Theme.barHeight
                    y: root.barVisible ? 0 : -(Theme.barHeight + 12)
                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.20, 0.00, 0.00, 1.00, 1.0, 1.0] } }

                    property bool notifActive: false
                    property string notifApp: ""
                    property string notifSummary: ""
                    property int notifUrgency: 1

                    property bool clipboardActive: false

                    Timer {
                        id: notifTimer
                        interval: 5000
                        onTriggered: barStrip.notifActive = false
                    }

                    Timer {
                        id: clipboardTimer
                        interval: 2000
                        onTriggered: barStrip.clipboardActive = false
                    }

                    Connections {
                        target: Notifications
                        function onNewNotification(n) {
                            barStrip.notifApp = n.appName || ""
                            barStrip.notifSummary = n.summary || ""
                            barStrip.notifUrgency = n.urgency
                            barStrip.notifActive = true
                            notifTimer.restart()
                        }
                    }

                    Connections {
                        target: root
                        function onClipboardCopied() {
                            barStrip.clipboardActive = true
                            clipboardTimer.restart()
                        }
                    }

                    Island {
                        id: leftIsland
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.gapsOut + shoulder
                        contentWidth: leftRow.implicitWidth
                        suppressed: panel.centerMode === "wallpaper"

                        BarRow {
                            id: leftRow
                            pos: "left"
                            screen: panel.modelData
                            monitor: panel.hyprMonitor
                            menuActive: root.settingsOpen
                            onMenuClicked: root.settingsOpen = !root.settingsOpen
                        }
                    }

                    Island {
                        id: centerIsland
                        anchors.horizontalCenter: parent.horizontalCenter
                        z: 1

                        readonly property string mode: panel.centerMode
                        readonly property int osdWidth: 260
                        readonly property real wallpaperWidth: Math.min(panel.width - 2 * (Theme.gapsOut + shoulder + padding), 1240)

                        contentWidth: mode === "settings"     ? settingsWindow.implicitWidth
                                    : mode === "wallpaper"    ? wallpaperWidth
                                    : mode === "osd"          ? osdWidth
                                    : mode === "clipboard"    ? clipboardRow.implicitWidth
                                    : mode === "notification" ? Math.min(Math.max(notifCard.implicitWidth, 220), 420)
                                    : centerRow.implicitWidth
                        contentHeight: mode === "settings"     ? settingsWindow.implicitHeight + 12
                                     : mode === "wallpaper"    ? wallpaperPicker.implicitHeight + 14
                                     : mode === "osd"          ? Theme.barHeight + 6
                                     : mode === "notification" ? 58
                                     : Theme.barHeight

                        NotchView {
                            current: centerIsland.mode === "modules"
                            width: centerRow.implicitWidth
                            height: Theme.barHeight
                            anchors.horizontalCenter: parent.horizontalCenter

                            BarRow {
                                id: centerRow
                                pos: "center"
                                screen: panel.modelData
                                monitor: panel.hyprMonitor
                                menuActive: root.settingsOpen
                                onMenuClicked: root.settingsOpen = !root.settingsOpen
                            }
                        }

                        // ── Notification banner ───────────────────────
                        NotchView {
                            current: centerIsland.mode === "notification"
                            anchors.fill: parent

                            Row {
                                id: notifCard
                                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter; verticalCenterOffset: 2 }
                                width: Math.min(implicitWidth, 420)
                                spacing: 12

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30; height: 30; radius: 15
                                    color: barStrip.notifUrgency === NotificationUrgency.Critical ? Theme.alpha(Theme.red, 0.2) : Theme.selected

                                    Icon {
                                        anchors.centerIn: parent
                                        name: "bell"
                                        size: 15
                                        color: barStrip.notifUrgency === NotificationUrgency.Critical ? Theme.red : Theme.text
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Label {
                                        text: barStrip.notifApp || "Notification"
                                        color: Theme.subtext
                                        font.pixelSize: Theme.textXs
                                        font.weight: Font.Medium
                                        width: Math.min(implicitWidth, 370)
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        text: barStrip.notifSummary
                                        font.pixelSize: Theme.textSm + 1
                                        font.weight: Font.DemiBold
                                        width: Math.min(implicitWidth, 370)
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        // ── Clipboard confirmation ────────────────────
                        NotchView {
                            current: centerIsland.mode === "clipboard"
                            anchors.fill: parent

                            Row {
                                id: clipboardRow
                                anchors.centerIn: parent
                                spacing: 6

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "check"
                                    size: Theme.barFontSize + 2
                                    color: Theme.green
                                }

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Copied"
                                    font.pixelSize: Theme.barFontSize
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        // ── Volume / brightness ───────────────────────
                        NotchView {
                            id: osdView
                            current: centerIsland.mode === "osd"
                            instant: true
                            // Laid out at its final size from the start; the growing
                            // notch reveals it instead of squeezing the level bar.
                            anchors.centerIn: parent
                            width: centerIsland.osdWidth
                            height: Theme.barHeight + 6

                            readonly property bool isVolume: OsdState.type === "volume"
                            // Volume can reach 150 %; the bar shows 0–100 % and turns red above.
                            readonly property real level: OsdState.muted ? 0
                                                        : isVolume ? Math.min(1, OsdState.value)
                                                        : OsdState.value

                            Icon {
                                id: osdIcon
                                anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                                size: 16
                                name: !osdView.isVolume ? "brightness"
                                    : OsdState.muted || OsdState.value === 0 ? "volumeMute"
                                    : OsdState.value < 0.33 ? "volumeLow"
                                    : OsdState.value < 0.66 ? "volumeMedium"
                                    : "volumeHigh"
                                color: OsdState.muted ? Theme.subtext : Theme.text
                            }

                            Rectangle {
                                anchors {
                                    left: osdIcon.right; leftMargin: 12
                                    right: osdValue.left; rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 5
                                radius: 2.5
                                color: Theme.track

                                Rectangle {
                                    width: parent.width * osdView.level
                                    height: parent.height
                                    radius: parent.radius
                                    color: osdView.isVolume && OsdState.value > 1.0 ? Theme.red : Theme.text
                                    Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                                }
                            }

                            Label {
                                id: osdValue
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                width: 36
                                horizontalAlignment: Text.AlignRight
                                text: OsdState.muted ? "Off" : Math.round(OsdState.value * 100) + "%"
                                color: OsdState.muted ? Theme.subtext : Theme.text
                                font.pixelSize: Theme.textSm
                                font.weight: Font.Medium
                            }
                        }

                        // ── Settings ──────────────────────────────────
                        NotchView {
                            id: settingsSlot
                            current: centerIsland.mode === "settings"
                            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                            width: settingsWindow.implicitWidth
                            height: settingsWindow.implicitHeight
                        }

                        // ── Wallpaper picker ──────────────────────────
                        NotchView {
                            id: wallpaperSlot
                            current: centerIsland.mode === "wallpaper"
                            anchors { top: parent.top; topMargin: 4; horizontalCenter: parent.horizontalCenter }
                            width: centerIsland.wallpaperWidth
                            height: wallpaperPicker.implicitHeight
                        }
                    }

                    Island {
                        id: rightIsland
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.gapsOut + shoulder
                        contentWidth: rightRow.implicitWidth
                        suppressed: panel.centerMode === "wallpaper"

                        BarRow {
                            id: rightRow
                            pos: "right"
                            screen: panel.modelData
                            monitor: panel.hyprMonitor
                            menuActive: root.settingsOpen
                            onMenuClicked: root.settingsOpen = !root.settingsOpen
                        }
                    }
                }

                // ── Hover popup card ───────────────────────────────────
                Rectangle {
                    id: popupCard

                    readonly property int pad: 16
                    readonly property bool open: BarHover.activeModule !== "" && BarHover.activeScreen === panel.modelData && panel.panelMode === ""
                    readonly property var currentItem: activeLoader === 0 ? loaderA.item : loaderB.item

                    // Height follows the content of whichever loader is in front.
                    property real targetH: open && currentItem ? currentItem.implicitHeight + pad * 2 : 0
                    property real animH: 0
                    // A popup that animates its own height sets `resizing`;
                    // the card then tracks it frame by frame instead of easing after it.
                    Behavior on animH {
                        enabled: !(popupCard.currentItem && popupCard.currentItem.resizing)
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    onTargetHChanged: animH = targetH

                    // A popup can ask for a wider card with a `popupWidth` property
                    readonly property real targetW: currentItem && currentItem.popupWidth ? currentItem.popupWidth : 300

                    y: barStrip.y + Theme.barHeight + 8
                    // X: only animate when popup is already open (animH > 40)
                    // so first appearance snaps into position rather than sliding in.
                    // Placed by the final width, not the animating one, so x and
                    // width ease together as one motion instead of x chasing width.
                    x: Math.max(Theme.gapsOut, Math.min(parent.width - targetW - Theme.gapsOut, BarHover.anchorX - targetW / 2))
                    Behavior on x {
                        enabled: popupCard.animH > 40
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    width: targetW
                    Behavior on width {
                        enabled: popupCard.animH > 40
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    height: animH
                    visible: animH > 0.5
                    opacity: open ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    radius: Theme.radiusLg
                    color: Theme.base
                    border.color: Theme.hairline
                    border.width: 1
                    clip: true

                    HoverHandler {
                        onHoveredChanged: hovered ? BarHover.keepAlive() : BarHover.startHide()
                    }

                    // Sliding popup content — two loaders alternate so old
                    // slides out while new slides in from the correct side.
                    property int  activeLoader: 0
                    property real prevAnchorX:  -1

                    Connections {
                        target: BarHover
                        function onPopupComponentChanged() {
                            if (BarHover.popupComponent === null) {
                                popupClearTimer.restart()
                                popupCard.prevAnchorX = -1
                                return
                            }
                            popupClearTimer.stop()

                            const hasHistory  = popupCard.prevAnchorX >= 0
                            const wasVisible  = popupCard.animH > 0
                            const shouldSlide = hasHistory && wasVisible
                            const goRight     = !hasHistory || BarHover.anchorX >= popupCard.prevAnchorX
                            popupCard.prevAnchorX = BarHover.anchorX
                            const m = popupCard.pad

                            const incoming = popupCard.activeLoader === 0 ? loaderB : loaderA
                            const outgoing = popupCard.activeLoader === 0 ? loaderA : loaderB
                            const inSlide  = popupCard.activeLoader === 0 ? loaderBslide : loaderAslide
                            const outSlide = popupCard.activeLoader === 0 ? loaderAslide : loaderBslide

                            incoming.sourceComponent = BarHover.popupComponent
                            // Slide by the wider of the old and new card, so the
                            // outgoing content clears the card whichever way it resizes.
                            const newW = incoming.item && incoming.item.popupWidth ? incoming.item.popupWidth : 300
                            const w = Math.max(popupCard.width, newW)
                            if (shouldSlide) {
                                inSlide.from = goRight ? w : -w
                                inSlide.to = m; inSlide.restart()
                                outSlide.from = m
                                outSlide.to = goRight ? -w : w; outSlide.restart()
                            } else {
                                incoming.x = m; outgoing.x = -w
                            }
                            popupCard.activeLoader = popupCard.activeLoader === 0 ? 1 : 0
                        }
                    }

                    // Keep content alive while the card collapses.
                    Timer {
                        id: popupClearTimer
                        interval: 220
                        onTriggered: {
                            loaderA.sourceComponent = null
                            loaderB.sourceComponent = null
                        }
                    }

                    Loader {
                        id: loaderA
                        // Shown while in front or sliding out
                        visible: popupCard.activeLoader === 0 || loaderAslide.running
                        x: parent.width; y: popupCard.pad
                        width: parent.width - popupCard.pad * 2
                        NumberAnimation on x {
                            id: loaderAslide
                            duration: 220; easing.type: Easing.OutCubic
                        }
                    }

                    Loader {
                        id: loaderB
                        visible: popupCard.activeLoader === 1 || loaderBslide.running
                        x: parent.width; y: popupCard.pad
                        width: parent.width - popupCard.pad * 2
                        NumberAnimation on x {
                            id: loaderBslide
                            duration: 220; easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
