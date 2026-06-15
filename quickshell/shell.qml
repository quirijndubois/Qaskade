//@ pragma UseQApplication
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import "./modules"
import "./windows"

ShellRoot {
    id: root

    property bool settingsOpen: false
    property string requestedPage: "main"
    property bool sessionLocked: false
    property bool barVisible: true

    signal clipboardCopied()

    IpcHandler {
        target: "settings"

        function toggle()    { root.settingsOpen = !root.settingsOpen }
        function open()      { root.settingsOpen = true }
        function openApps()  { root.requestedPage = "apps"; root.settingsOpen = true }
        function close()     { root.settingsOpen = false }
    }

    IpcHandler {
        target: "clipboard"

        function copied() { root.clipboardCopied() }
    }

    IpcHandler {
        target: "lock"

        function lock() {
            root.sessionLocked = true
            lockScreen.lock()
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

    SettingsWindow {
        id: settingsWindow
        visible: root.settingsOpen
        requestedPage: root.requestedPage
        onCloseRequested: { root.requestedPage = "main"; root.settingsOpen = false }
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
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                required property var modelData
                screen: modelData

                anchors { top: true; left: true; right: true }
                exclusiveZone: root.barVisible ? Theme.barHeight : 0
                implicitHeight: Theme.barHeight + Theme.gapsOut + 300

                color: "transparent"

                mask: Region {
                    Region { item: barStrip }
                    Region { item: popupCard }
                }

                property var hyprMonitor: Hyprland.monitorFor(modelData)

                // ── Bar strip ─────────────────────────────────────────
                // For pills/islands, extend height by gapsOut so the pill is
                // visually centered between the screen edge and the first window
                // (which Hyprland pushes down by gapsOut from the exclusive zone).
                Rectangle {
                    id: barStrip
                    anchors { left: parent.left; right: parent.right }
                    y: root.barVisible ? 0 : -(Theme.barHeight + Theme.gapsOut + 10)
                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    height: (Theme.design === "pills" || Theme.design === "islands")
                            ? Theme.barHeight + Theme.gapsOut
                            : Theme.barHeight
                    color: (Theme.design === "islands" || Theme.design === "pills") ? "transparent" : Theme.base

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

                    function showClipboardNotif() {
                        barStrip.clipboardActive = true
                        clipboardTimer.restart()
                    }

                    Connections {
                        target: root
                        function onClipboardCopied() {
                            barStrip.showClipboardNotif()
                        }
                    }

                    Rectangle {
                        visible: Theme.design !== "islands" && Theme.design !== "pills"
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1
                        color: Theme.border
                    }

                    // ── Left island background ─────────────────────────
                    Rectangle {
                        visible: Theme.design === "islands"
                        anchors { left: parent.left; leftMargin: Theme.gapsOut; verticalCenter: parent.verticalCenter }
                        width: leftRow.implicitWidth + 24
                        height: parent.height - 8
                        color: Theme.surface
                        radius: 8
                        border.color: Theme.border
                        border.width: 1
                    }

                    Row {
                        id: leftRow
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: Theme.design === "islands" ? Theme.gapsOut + 12 : (Theme.showMenu ? Theme.gapsOut : 4)
                        }
                        spacing: Theme.design === "pills" ? 4 : 0

                        BarText {
                            text: "menu"
                            visible: Theme.showMenu
                            color: root.settingsOpen ? Theme.purple : Theme.subtext
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.settingsOpen = !root.settingsOpen
                            }
                        }
                        Separator { visible: Theme.showMenu && Theme.showClock && Theme.design !== "pills" }
                        ClockModule { visible: Theme.showClock; screen: modelData }
                        Separator { visible: Theme.showBattery && Theme.design !== "pills" }
                        BatteryModule { visible: Theme.showBattery; screen: modelData }
                        Separator { visible: Theme.showCpu && Theme.design !== "pills" }
                        CpuModule { visible: Theme.showCpu; screen: modelData }
                        Separator { visible: Theme.showMemory && Theme.design !== "pills" }
                        MemoryModule { visible: Theme.showMemory; screen: modelData }
                        Separator { visible: Theme.showGpu && Theme.design !== "pills" }
                        GpuModule { visible: Theme.showGpu; screen: modelData }
                    }

                    // ── Center island / pill background ────────────────
                    Rectangle {
                        visible: Theme.design === "islands" || Theme.design === "pills"
                        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                        width: barStrip.clipboardActive ? clipboardCenterRow.implicitWidth + 32 : barStrip.notifActive ? notifCenterRow.implicitWidth + 32 : centerRow.implicitWidth + 24
                        Behavior on width { NumberAnimation { duration: barStrip.clipboardActive ? 150 : 220; easing.type: Easing.OutCubic } }
                        height: Theme.design === "pills" ? Theme.barHeight - 8 : parent.height - 8
                        color: Theme.surface
                        radius: Theme.design === "pills" ? (Theme.barHeight - 8) / 2 : 8
                        border.color: Theme.border
                        border.width: 1
                    }

                    Row {
                        id: centerRow
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 0
                        opacity: barStrip.notifActive || barStrip.clipboardActive ? 0.0 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.InOutQuad } }

                        WorkspacesModule { monitor: hyprMonitor; screen: modelData; visible: Theme.showWorkspaces }
                    }

                    // ── In-bar notification display ────────────────────
                    Row {
                        id: notifCenterRow
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 8
                        opacity: barStrip.notifActive && !barStrip.clipboardActive ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

                        Text {
                            text: barStrip.notifApp
                            color: barStrip.notifUrgency === NotificationUrgency.Critical ? Theme.red
                                 : barStrip.notifUrgency === NotificationUrgency.Low      ? Theme.subtext
                                 : Theme.blue
                            font.family: Theme.barFontFamily
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                            width: Math.min(implicitWidth, 100)
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: barStrip.notifSummary !== ""
                            text: "·"
                            color: Theme.subtext
                            font.family: Theme.barFontFamily
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: barStrip.notifSummary
                            color: Theme.text
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            width: Math.min(implicitWidth, 200)
                            elide: Text.ElideRight
                        }
                    }

                    // ── Clipboard notification display ────────────────────
                    Row {
                        id: clipboardCenterRow
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 8
                        opacity: barStrip.clipboardActive ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

                        Text {
                            text: "✓"
                            color: Theme.green
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                            font.bold: true
                        }

                        Text {
                            text: "copied"
                            color: Theme.text
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                            font.bold: true
                        }
                    }

                    // ── Right island background ────────────────────────
                    Rectangle {
                        visible: Theme.design === "islands"
                        anchors { right: parent.right; rightMargin: Theme.gapsOut; verticalCenter: parent.verticalCenter }
                        width: rightRow.implicitWidth + 24
                        height: parent.height - 8
                        color: Theme.surface
                        radius: 8
                        border.color: Theme.border
                        border.width: 1
                    }

                    Row {
                        id: rightRow
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: Theme.design === "islands" ? Theme.gapsOut + 12 : Theme.gapsOut
                        }
                        spacing: Theme.design === "pills" ? 4 : 0

                        MusicModule { id: musicMod; screen: modelData }
                        Separator { visible: musicMod.visible && Theme.showAudio && Theme.design !== "pills" }
                        AudioModule { visible: Theme.showAudio; screen: modelData }
                        Separator { visible: Theme.showBluetooth && Theme.design !== "pills" }
                        BluetoothModule { visible: Theme.showBluetooth; screen: modelData }
                        Separator { visible: Theme.showNetwork && Theme.design !== "pills" }
                        NetworkModule { visible: Theme.showNetwork; screen: modelData }
                        Separator { visible: Theme.showInhibit && Theme.design !== "pills" }
                        InhibitModule { visible: Theme.showInhibit; screen: modelData }
                        Separator { visible: trayMod.visible && Theme.design !== "pills" }
                        TrayModule { id: trayMod }
                    }
                }

                // ── Hover popup card ───────────────────────────────────
                Rectangle {
                    id: popupCard

                    // Height: animate open/close and also animate between
                    // different module popup heights (e.g. cpu→clock)
                    property real targetH: (BarHover.activeModule !== "" && BarHover.activeScreen === modelData) ? BarHover.popupH : 0
                    property real animH: 0
                    Behavior on animH {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    onTargetHChanged: animH = targetH

                    // X: only animate when popup is already open (animH > 40)
                    // so first appearance snaps into position rather than sliding in.
                    anchors.top: barStrip.bottom
                    x: Math.max(4, Math.min(parent.width - width - 4, BarHover.anchorX - width / 2))
                    Behavior on x {
                        enabled: popupCard.animH > 40
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    width: 224
                    height: animH
                    radius: 6
                    color: Theme.surface
                    border.color: Theme.border
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
                                loaderA.sourceComponent = null
                                loaderB.sourceComponent = null
                                popupCard.prevAnchorX = -1
                                return
                            }

                            const hasHistory  = popupCard.prevAnchorX >= 0
                            const wasVisible  = popupCard.animH > 0
                            const shouldSlide = hasHistory && wasVisible
                            const goRight     = !hasHistory || BarHover.anchorX >= popupCard.prevAnchorX
                            popupCard.prevAnchorX = BarHover.anchorX
                            const w = popupCard.width
                            const margin = 12

                            if (popupCard.activeLoader === 0) {
                                loaderB.sourceComponent = BarHover.popupComponent
                                if (shouldSlide) {
                                    loaderBslide.from = goRight ? w : -w
                                    loaderBslide.to   = margin; loaderBslide.restart()
                                    loaderAslide.from = margin
                                    loaderAslide.to   = goRight ? -w : w; loaderAslide.restart()
                                } else {
                                    loaderB.x = margin; loaderA.x = -w
                                }
                                popupCard.activeLoader = 1
                            } else {
                                loaderA.sourceComponent = BarHover.popupComponent
                                if (shouldSlide) {
                                    loaderAslide.from = goRight ? w : -w
                                    loaderAslide.to   = margin; loaderAslide.restart()
                                    loaderBslide.from = margin
                                    loaderBslide.to   = goRight ? -w : w; loaderBslide.restart()
                                } else {
                                    loaderA.x = margin; loaderB.x = -w
                                }
                                popupCard.activeLoader = 0
                            }
                        }
                    }

                    Loader {
                        id: loaderA
                        x: parent.width; y: 12
                        width: parent.width - 24
                        height: parent.height - 24
                        NumberAnimation on x {
                            id: loaderAslide
                            duration: 220; easing.type: Easing.OutCubic
                        }
                    }

                    Loader {
                        id: loaderB
                        x: parent.width; y: 12
                        width: parent.width - 24
                        height: parent.height - 24
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
