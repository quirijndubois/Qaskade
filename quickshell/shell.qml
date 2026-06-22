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

                    // "any module before position N is visible in row R" chains.
                    // Each property adds one more module to the OR chain.
                    // Used by separators so two visible adjacent modules always get a divider
                    // even when the module between them in the list is in a different row.
                    property bool _bL1:  Theme.showMenu       === "left"
                    property bool _bL2:  _bL1  || Theme.showClock      === "left"
                    property bool _bL3:  _bL2  || Theme.showBattery    === "left"
                    property bool _bL4:  _bL3  || Theme.showCpu        === "left"
                    property bool _bL5:  _bL4  || Theme.showMemory     === "left"
                    property bool _bL6:  _bL5  || Theme.showGpu        === "left"
                    property bool _bL7:  _bL6  || Theme.showWorkspaces === "left"
                    property bool _bL8:  _bL7  || (musicModL && musicModL.visible)
                    property bool _bL9:  _bL8  || Theme.showAudio      === "left"
                    property bool _bL10: _bL9  || Theme.showBluetooth  === "left"
                    property bool _bL11: _bL10 || Theme.showNetwork    === "left"
                    property bool _bL12: _bL11 || Theme.showInhibit    === "left"

                    property bool _bC1:  Theme.showMenu       === "center"
                    property bool _bC2:  _bC1  || Theme.showClock      === "center"
                    property bool _bC3:  _bC2  || Theme.showBattery    === "center"
                    property bool _bC4:  _bC3  || Theme.showCpu        === "center"
                    property bool _bC5:  _bC4  || Theme.showMemory     === "center"
                    property bool _bC6:  _bC5  || Theme.showGpu        === "center"
                    property bool _bC7:  _bC6  || Theme.showWorkspaces === "center"
                    property bool _bC8:  _bC7  || (musicModC && musicModC.visible)
                    property bool _bC9:  _bC8  || Theme.showAudio      === "center"
                    property bool _bC10: _bC9  || Theme.showBluetooth  === "center"
                    property bool _bC11: _bC10 || Theme.showNetwork    === "center"
                    property bool _bC12: _bC11 || Theme.showInhibit    === "center"

                    property bool _bR1:  Theme.showMenu       === "right"
                    property bool _bR2:  _bR1  || Theme.showClock      === "right"
                    property bool _bR3:  _bR2  || Theme.showBattery    === "right"
                    property bool _bR4:  _bR3  || Theme.showCpu        === "right"
                    property bool _bR5:  _bR4  || Theme.showMemory     === "right"
                    property bool _bR6:  _bR5  || Theme.showGpu        === "right"
                    property bool _bR7:  _bR6  || Theme.showWorkspaces === "right"
                    property bool _bR8:  _bR7  || (musicModR && musicModR.visible)
                    property bool _bR9:  _bR8  || Theme.showAudio      === "right"
                    property bool _bR10: _bR9  || Theme.showBluetooth  === "right"
                    property bool _bR11: _bR10 || Theme.showNetwork    === "right"
                    property bool _bR12: _bR11 || Theme.showInhibit    === "right"

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
                            leftMargin: Theme.design === "islands" ? Theme.gapsOut + 12 : (Theme.showMenu === "left" ? Theme.gapsOut : 4)
                        }
                        spacing: Theme.design === "pills" ? 4 : 0

                        BarText {
                            text: "menu"
                            visible: Theme.showMenu === "left"
                            color: root.settingsOpen ? Theme.purple : Theme.subtext
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.settingsOpen = !root.settingsOpen
                            }
                        }
                        Separator { visible: Theme.showClock      === "left" && barStrip._bL1  && Theme.design !== "pills" }
                        ClockModule { visible: Theme.showClock === "left"; screen: modelData }
                        Separator { visible: Theme.showBattery  === "left" && barStrip._bL2  && Theme.design !== "pills" }
                        BatteryModule { visible: Theme.showBattery === "left"; screen: modelData }
                        Separator { visible: Theme.showCpu      === "left" && barStrip._bL3  && Theme.design !== "pills" }
                        CpuModule { visible: Theme.showCpu === "left"; screen: modelData }
                        Separator { visible: Theme.showMemory   === "left" && barStrip._bL4  && Theme.design !== "pills" }
                        MemoryModule { visible: Theme.showMemory === "left"; screen: modelData }
                        Separator { visible: Theme.showGpu      === "left" && barStrip._bL5  && Theme.design !== "pills" }
                        GpuModule { visible: Theme.showGpu === "left"; screen: modelData }
                        Separator { visible: Theme.showWorkspaces === "left" && barStrip._bL6 && Theme.design !== "pills" }
                        WorkspacesModule { monitor: hyprMonitor; screen: modelData; visible: Theme.showWorkspaces === "left" }
                        Separator { visible: musicModL.visible  && barStrip._bL7  && Theme.design !== "pills" }
                        MusicModule { id: musicModL; targetRow: "left"; screen: modelData }
                        Separator { visible: Theme.showAudio    === "left" && barStrip._bL8  && Theme.design !== "pills" }
                        AudioModule { visible: Theme.showAudio === "left"; screen: modelData }
                        Separator { visible: Theme.showBluetooth === "left" && barStrip._bL9 && Theme.design !== "pills" }
                        BluetoothModule { visible: Theme.showBluetooth === "left"; screen: modelData }
                        Separator { visible: Theme.showNetwork  === "left" && barStrip._bL10 && Theme.design !== "pills" }
                        NetworkModule { visible: Theme.showNetwork === "left"; screen: modelData }
                        Separator { visible: Theme.showInhibit  === "left" && barStrip._bL11 && Theme.design !== "pills" }
                        InhibitModule { visible: Theme.showInhibit === "left"; screen: modelData }
                        Separator { visible: trayModL.visible   && barStrip._bL12 && Theme.design !== "pills" }
                        TrayModule { id: trayModL; targetRow: "left" }
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
                        spacing: Theme.design === "pills" ? 4 : 0
                        opacity: barStrip.notifActive || barStrip.clipboardActive ? 0.0 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.InOutQuad } }

                        BarText {
                            text: "menu"
                            visible: Theme.showMenu === "center"
                            color: root.settingsOpen ? Theme.purple : Theme.subtext
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.settingsOpen = !root.settingsOpen
                            }
                        }
                        Separator { visible: Theme.showClock      === "center" && barStrip._bC1  && Theme.design !== "pills" }
                        ClockModule { visible: Theme.showClock === "center"; screen: modelData }
                        Separator { visible: Theme.showBattery  === "center" && barStrip._bC2  && Theme.design !== "pills" }
                        BatteryModule { visible: Theme.showBattery === "center"; screen: modelData }
                        Separator { visible: Theme.showCpu      === "center" && barStrip._bC3  && Theme.design !== "pills" }
                        CpuModule { visible: Theme.showCpu === "center"; screen: modelData }
                        Separator { visible: Theme.showMemory   === "center" && barStrip._bC4  && Theme.design !== "pills" }
                        MemoryModule { visible: Theme.showMemory === "center"; screen: modelData }
                        Separator { visible: Theme.showGpu      === "center" && barStrip._bC5  && Theme.design !== "pills" }
                        GpuModule { visible: Theme.showGpu === "center"; screen: modelData }
                        Separator { visible: Theme.showWorkspaces === "center" && barStrip._bC6 && Theme.design !== "pills" }
                        WorkspacesModule { monitor: hyprMonitor; screen: modelData; visible: Theme.showWorkspaces === "center" }
                        Separator { visible: musicModC.visible  && barStrip._bC7  && Theme.design !== "pills" }
                        MusicModule { id: musicModC; targetRow: "center"; screen: modelData }
                        Separator { visible: Theme.showAudio    === "center" && barStrip._bC8  && Theme.design !== "pills" }
                        AudioModule { visible: Theme.showAudio === "center"; screen: modelData }
                        Separator { visible: Theme.showBluetooth === "center" && barStrip._bC9 && Theme.design !== "pills" }
                        BluetoothModule { visible: Theme.showBluetooth === "center"; screen: modelData }
                        Separator { visible: Theme.showNetwork  === "center" && barStrip._bC10 && Theme.design !== "pills" }
                        NetworkModule { visible: Theme.showNetwork === "center"; screen: modelData }
                        Separator { visible: Theme.showInhibit  === "center" && barStrip._bC11 && Theme.design !== "pills" }
                        InhibitModule { visible: Theme.showInhibit === "center"; screen: modelData }
                        Separator { visible: trayModC.visible   && barStrip._bC12 && Theme.design !== "pills" }
                        TrayModule { id: trayModC; targetRow: "center" }
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

                        BarText {
                            text: "menu"
                            visible: Theme.showMenu === "right"
                            color: root.settingsOpen ? Theme.purple : Theme.subtext
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.settingsOpen = !root.settingsOpen
                            }
                        }
                        Separator { visible: Theme.showClock      === "right" && barStrip._bR1  && Theme.design !== "pills" }
                        ClockModule { visible: Theme.showClock === "right"; screen: modelData }
                        Separator { visible: Theme.showBattery  === "right" && barStrip._bR2  && Theme.design !== "pills" }
                        BatteryModule { visible: Theme.showBattery === "right"; screen: modelData }
                        Separator { visible: Theme.showCpu      === "right" && barStrip._bR3  && Theme.design !== "pills" }
                        CpuModule { visible: Theme.showCpu === "right"; screen: modelData }
                        Separator { visible: Theme.showMemory   === "right" && barStrip._bR4  && Theme.design !== "pills" }
                        MemoryModule { visible: Theme.showMemory === "right"; screen: modelData }
                        Separator { visible: Theme.showGpu      === "right" && barStrip._bR5  && Theme.design !== "pills" }
                        GpuModule { visible: Theme.showGpu === "right"; screen: modelData }
                        Separator { visible: Theme.showWorkspaces === "right" && barStrip._bR6 && Theme.design !== "pills" }
                        WorkspacesModule { monitor: hyprMonitor; screen: modelData; visible: Theme.showWorkspaces === "right" }
                        Separator { visible: musicModR.visible  && barStrip._bR7  && Theme.design !== "pills" }
                        MusicModule { id: musicModR; targetRow: "right"; screen: modelData }
                        Separator { visible: Theme.showAudio    === "right" && barStrip._bR8  && Theme.design !== "pills" }
                        AudioModule { visible: Theme.showAudio === "right"; screen: modelData }
                        Separator { visible: Theme.showBluetooth === "right" && barStrip._bR9 && Theme.design !== "pills" }
                        BluetoothModule { visible: Theme.showBluetooth === "right"; screen: modelData }
                        Separator { visible: Theme.showNetwork  === "right" && barStrip._bR10 && Theme.design !== "pills" }
                        NetworkModule { visible: Theme.showNetwork === "right"; screen: modelData }
                        Separator { visible: Theme.showInhibit  === "right" && barStrip._bR11 && Theme.design !== "pills" }
                        InhibitModule { visible: Theme.showInhibit === "right"; screen: modelData }
                        Separator { visible: trayModR.visible   && barStrip._bR12 && Theme.design !== "pills" }
                        TrayModule { id: trayModR; targetRow: "right" }
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
