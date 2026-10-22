import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../"
import "../components"

Item {
    id: root
    visible: false

    property string username: ""
    property string wallpaper: ""
    // Screen name → { rect, radius } of the center notch at lock time. The lock
    // grows out of it; null (or a screen without an entry) locks without the reveal.
    property var notches: null
    property bool _capturing: false
    readonly property string snapshotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/qaskade-lock"
    signal lockReleased()

    function lock(notchMap) {
        if (wlLock.locked || _capturing) return
        wallpaperProc.running = false
        wallpaperProc.running = true
        root.notches = notchMap
        if (!notchMap) {
            wlLock.locked = true
            return
        }
        _capturing = true
        snapshotProc.command = ["sh", "-c",
            "d=\"$1\"; shift; mkdir -p \"$d\" && rm -f \"$d\"/*.png; " +
            "for o in \"$@\"; do timeout 1 grim -l 0 -o \"$o\" \"$d/$o.png\" & done; wait",
            "sh", root.snapshotDir].concat(Quickshell.screens.map(s => s.name))
        snapshotProc.running = true
    }

    // A session lock surface can't be transparent (the compositor stops drawing
    // the desktop), so each screen is captured first and shown behind the reveal.
    // Locking goes ahead even if grim fails; those screens just skip the reveal.
    Process {
        id: snapshotProc
        onExited: {
            root._capturing = false
            wlLock.locked = true
        }
    }

    Process {
        id: snapshotCleanupProc
        command: ["sh", "-c", "rm -f \"$1\"/*.png", "sh", root.snapshotDir]
    }

    Process {
        command: ["sh", "-c", "id -un"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.username = this.text.trim() }
    }

    // Current wallpaper, used as the blurred backdrop.
    Process {
        id: wallpaperProc
        command: ["sh", "-c", "awww query 2>/dev/null | sed -n 's/.*image: //p' | head -1"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.wallpaper = this.text.trim() }
    }

    WlSessionLock {
        id: wlLock
        onLockedChanged: {
            if (locked) return
            snapshotCleanupProc.running = true
            root.lockReleased()
        }

        surface: Component {
            WlSessionLockSurface {
                id: surface
                color: Theme.base

                property string passwordInput: ""
                property bool   authFailed:    false
                property bool   authRunning:   false
                property bool   powerMenuOpen: false
                property date   now: new Date()

                property real pwBoxShiftX: 0.0

                // ── Reveal from the notch ──────────────────────────────────
                readonly property var notch: root.notches && surface.screen ? root.notches[surface.screen.name] : undefined
                readonly property bool animated: !!notch && snapshot.status === Image.Ready
                // 0 = sheet covers just the notch, 1 = sheet covers the screen
                property real reveal: 0
                // Background dimming: 0 = none, 1 = background at 20% brightness
                property real dim: 0
                readonly property real sheetW: notch ? notch.rect.width  + (width  - notch.rect.width)  * reveal : width
                readonly property real sheetH: notch ? notch.rect.height + (height - notch.rect.height) * reveal : height
                readonly property real sheetX: notch ? notch.rect.x * (1 - reveal) : 0
                readonly property real sheetY: notch ? notch.rect.y * (1 - reveal) : 0
                readonly property real sheetRadius: notch ? notch.radius * (1 - reveal) : 0

                function start() {
                    dimAnim.start()
                    if (surface.animated) {
                        revealAnim.start()
                    } else {
                        surface.reveal = 1
                        enterAnim.start()
                    }
                }

                NumberAnimation {
                    id: dimAnim
                    target: surface; property: "dim"; from: 0; to: 1
                    duration: 10000
                    easing.type: Easing.InOutSine
                }

                ParallelAnimation {
                    id: revealAnim
                    NumberAnimation {
                        target: surface; property: "reveal"; from: 0; to: 1; duration: 700
                        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.32, 0.72, 0.00, 1.00, 1.0, 1.0]
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 280 }
                        ScriptAction { script: enterAnim.start() }
                    }
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: surface.now = new Date()
                }

                Timer { id: failTimer; interval: 1600; onTriggered: surface.authFailed = false }

                onAuthFailedChanged: if (authFailed) shakeAnim.restart()

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: surface; property: "pwBoxShiftX"; to:  13; duration: 50; easing.type: Easing.OutCubic }
                    NumberAnimation { target: surface; property: "pwBoxShiftX"; to: -11; duration: 80; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: surface; property: "pwBoxShiftX"; to:   9; duration: 70; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: surface; property: "pwBoxShiftX"; to:  -6; duration: 60; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: surface; property: "pwBoxShiftX"; to:   3; duration: 50; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: surface; property: "pwBoxShiftX"; to:   0; duration: 40; easing.type: Easing.OutCubic }
                }


                Process {
                    id: lockPowerProc
                    stdout: StdioCollector {}
                    stderr: StdioCollector {}
                }

                Process {
                    id: authProc
                    stdinEnabled: true
                    stdout: StdioCollector {}
                    stderr: StdioCollector {}
                    onStarted: write(surface.passwordInput + "\n")
                    onExited: function(exitCode, exitStatus) {
                        if (exitCode === 0) {
                            exitAnim.start()
                        } else {
                            surface.authFailed = true
                            surface.passwordInput = ""
                            failTimer.restart()
                        }
                        surface.authRunning = false
                    }
                }

                function authenticate() {
                    if (surface.authRunning || surface.passwordInput.length === 0) return
                    surface.authRunning = true
                    authProc.command = [
                        "sh", "-c",
                        "IFS= read -r pw && printf '%s\\000' \"$pw\" | /usr/bin/unix_chkpwd \"$1\" nullok",
                        "--", root.username
                    ]
                    authProc.running = false
                    authProc.running = true
                }

                Item {
                    id: lockRoot
                    anchors.fill: parent
                    focus: true
                    Component.onCompleted: forceActiveFocus()

                    Keys.onPressed: event => {
                        if (surface.authRunning) { event.accepted = true; return }
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            surface.authenticate()
                        } else if (event.key === Qt.Key_Backspace) {
                            if (event.modifiers & Qt.ControlModifier)
                                surface.passwordInput = ""
                            else
                                surface.passwordInput = surface.passwordInput.slice(0, -1)
                        } else if (event.key === Qt.Key_Escape) {
                            surface.passwordInput = ""
                            surface.powerMenuOpen = false
                        } else if (event.text && event.text.charCodeAt(0) >= 32) {
                            surface.passwordInput += event.text
                            surface.authFailed = false
                        }
                        event.accepted = true
                    }

                    // ── Backdrop ───────────────────────────────────────────
                    // The desktop as it looked when locking; the sheet grows over it.
                    // Loaded synchronously so `animated` is settled before start().
                    Image {
                        id: snapshot
                        anchors.fill: parent
                        source: surface.notch ? "file://" + root.snapshotDir + "/" + surface.screen.name + ".png" : ""
                        asynchronous: false
                        cache: false
                    }

                    // Fallback backdrop when there is no snapshot (lockInstant, grim failed)
                    Image {
                        id: wallpaperImage
                        anchors.fill: parent
                        source: snapshot.status !== Image.Ready && root.wallpaper !== "" ? "file://" + root.wallpaper : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    readonly property Item backdropSource: snapshot.status === Image.Ready ? snapshot
                                                         : wallpaperImage.status === Image.Ready ? wallpaperImage
                                                         : null

                    // Static layers; only the mask and opacities change while animating.
                    Item {
                        id: blurLayer
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Rectangle { anchors.fill: parent; color: Theme.base }

                        MultiEffect {
                            anchors.fill: parent
                            // Slightly oversized so the blur doesn't fade out at the screen edges
                            scale: 1.06
                            source: lockRoot.backdropSource
                            visible: source !== null
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 64
                            saturation: -0.1
                        }
                    }

                    Item {
                        id: tintLayer
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle { anchors.fill: parent; color: Theme.base }
                    }

                    // Shape of the sheet: the notch at reveal 0, the whole screen at 1
                    Item {
                        id: sheetMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Rectangle {
                            x: surface.sheetX; y: surface.sheetY
                            width: surface.sheetW; height: surface.sheetH
                            bottomLeftRadius: surface.sheetRadius
                            bottomRightRadius: surface.sheetRadius
                        }
                    }

                    // Inside the sheet the desktop is blurred right away, and darkens
                    // toward the palette base as it grows so text stays legible.
                    MultiEffect {
                        anchors.fill: parent
                        source: blurLayer
                        maskEnabled: true
                        maskSource: sheetMask
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: tintLayer
                        maskEnabled: true
                        maskSource: sheetMask
                        opacity: (lockRoot.backdropSource ? 0.45 : 1.0) * surface.reveal
                    }

                    Item {
                        id: dimLayer
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle { anchors.fill: parent; color: "black" }
                    }

                    // Slowly darkens the background (not the clock or sign-in) to 20%
                    MultiEffect {
                        anchors.fill: parent
                        source: dimLayer
                        maskEnabled: true
                        maskSource: sheetMask
                        opacity: 0.8 * surface.dim
                    }

                    // ── Content wrapper — enter/exit animations ────────────
                    Item {
                        id: contentWrapper
                        anchors.fill: parent
                        opacity: 0
                        transform: Translate { id: contentSlide; y: 40 }
                        Component.onCompleted: Qt.callLater(surface.start)

                        SequentialAnimation {
                            id: enterAnim
                            ParallelAnimation {
                                NumberAnimation { target: contentSlide; property: "y"; from: 40; to: 0; duration: 420; easing.type: Easing.OutExpo }
                                NumberAnimation { target: contentWrapper; property: "opacity"; from: 0; to: 1; duration: 340; easing.type: Easing.OutCubic }
                            }
                        }

                        SequentialAnimation {
                            id: exitAnim
                            ParallelAnimation {
                                NumberAnimation { target: contentSlide; property: "y"; to: -50; duration: 260; easing.type: Easing.InCubic }
                                NumberAnimation { target: contentWrapper; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
                                ScriptAction { script: dimAnim.stop() }
                                NumberAnimation { target: surface; property: "dim"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                            }
                            // Shrink back into the notch over the snapshot
                            NumberAnimation {
                                target: surface; property: "reveal"; to: 0
                                duration: surface.animated ? 460 : 0
                                easing.type: Easing.BezierSpline; easing.bezierCurve: [0.40, 0.00, 0.20, 1.00, 1.0, 1.0]
                            }
                            ScriptAction { script: wlLock.locked = false }
                        }

                        // ── Clock ──────────────────────────────────────────
                        Column {
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.16 }
                            spacing: 4

                            Label {
                                id: dateLabel
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDate(surface.now, "dddd d MMMM")
                                color: Theme.alpha(Theme.text, 0.85)
                                font.pixelSize: 20
                                font.weight: Font.Medium
                            }

                            // Room for bigClock, which lives outside this wrapper
                            Item { width: bigClock.width; height: bigClock.height }
                        }

                        // ── Sign-in ────────────────────────────────────────
                        Column {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.14 }
                            spacing: 14

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 64; height: 64; radius: 32
                                color: Theme.alpha(Theme.text, 0.12)
                                border.width: 1
                                border.color: Theme.alpha(Theme.text, 0.15)

                                Label {
                                    anchors.centerIn: parent
                                    text: root.username.charAt(0).toUpperCase()
                                    font.pixelSize: 26
                                    font.weight: Font.DemiBold
                                }
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.username
                                font.pixelSize: Theme.textLg
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 280; height: 44
                                radius: height / 2
                                color: Theme.alpha(Theme.text, 0.10)
                                border.width: 1
                                border.color: surface.authFailed ? Theme.red : Theme.alpha(Theme.text, 0.15)
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                transform: Translate { x: surface.pwBoxShiftX }

                                Label {
                                    anchors.centerIn: parent
                                    opacity: surface.passwordInput.length === 0 ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    text: surface.authFailed ? "Incorrect password"
                                        : surface.authRunning ? "Checking…"
                                        : "Enter password"
                                    color: surface.authFailed ? Theme.red : Theme.alpha(Theme.text, 0.55)
                                    font.pixelSize: Theme.textMd
                                }

                                // A fixed set of dots that each grow in or shrink out on
                                // their own, so typing never rebuilds the others. Hidden
                                // dots take no width, so the row glides to stay centered.
                                Row {
                                    id: dotRow
                                    anchors.centerIn: parent
                                    readonly property int maxDots: 16

                                    // Gentle pulse while the password is being checked
                                    SequentialAnimation on opacity {
                                        running: surface.authRunning
                                        loops: Animation.Infinite
                                        alwaysRunToEnd: true
                                        NumberAnimation { to: 0.35; duration: 420; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0;  duration: 420; easing.type: Easing.InOutSine }
                                    }

                                    Repeater {
                                        model: dotRow.maxDots
                                        delegate: Item {
                                            required property int index
                                            readonly property bool shown: index < Math.min(surface.passwordInput.length, dotRow.maxDots)
                                            width: shown ? 15 : 0
                                            height: 15
                                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 7; height: 7; radius: 3.5
                                                color: surface.authFailed ? Theme.red : Theme.text
                                                scale: parent.shown ? 1 : 0
                                                opacity: parent.shown ? 1 : 0
                                                Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Power menu ─────────────────────────────────────
                        Row {
                            anchors { bottom: parent.bottom; right: parent.right; bottomMargin: 28; rightMargin: 28 }
                            spacing: 10
                            layoutDirection: Qt.RightToLeft

                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: surface.powerMenuOpen ? Theme.text : Theme.alpha(Theme.text, powerHover.hovered ? 0.18 : 0.10)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Icon {
                                    anchors.centerIn: parent
                                    name: surface.powerMenuOpen ? "close" : "power"
                                    size: 18
                                    color: surface.powerMenuOpen ? Theme.base : Theme.text
                                }

                                HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: surface.powerMenuOpen = !surface.powerMenuOpen }
                            }

                            Repeater {
                                model: [
                                    { icon: "power",     cmd: ["systemctl", "poweroff"]  },
                                    { icon: "restart",   cmd: ["systemctl", "reboot"]    },
                                    { icon: "hibernate", cmd: ["systemctl", "hibernate"] },
                                    { icon: "sleep",     cmd: ["systemctl", "suspend"]   },
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 40; height: 40; radius: 20
                                    color: Theme.alpha(Theme.text, itemHover.hovered ? 0.18 : 0.10)
                                    opacity: surface.powerMenuOpen ? 1 : 0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                    Icon {
                                        anchors.centerIn: parent
                                        name: modelData.icon
                                        size: 18
                                    }

                                    HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            surface.powerMenuOpen = false
                                            lockPowerProc.command = modelData.cmd
                                            lockPowerProc.running = false
                                            Qt.callLater(() => { lockPowerProc.running = true })
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // The bar clock grows into the big clock as the sheet expands,
                    // and shrinks back into it on unlock.
                    RollingText {
                        id: bigClock
                        readonly property var fromRect: surface.animated && surface.notch.clock ? surface.notch.clock : null
                        readonly property real startScale: Theme.barFontSize / font.pixelSize
                        readonly property real finalX: (parent.width - width) / 2
                        readonly property real finalY: parent.height * 0.16 + dateLabel.height + 4
                        readonly property real m: surface.reveal
                        readonly property real s: fromRect ? startScale + (1 - startScale) * m : 1
                        // Top-left that centers the scaled-down clock on the bar clock
                        readonly property real startX: fromRect ? fromRect.x + (fromRect.width  - width  * startScale) / 2 : finalX
                        readonly property real startY: fromRect ? fromRect.y + (fromRect.height - height * startScale) / 2 : finalY

                        text: Qt.formatTime(surface.now, "hh:mm")
                        font.pixelSize: 112
                        font.weight: Font.DemiBold
                        font.letterSpacing: -3
                        opacity: fromRect ? 1 : contentWrapper.opacity
                        transform: [
                            Scale { xScale: bigClock.s; yScale: bigClock.s },
                            Translate {
                                x: bigClock.fromRect ? bigClock.startX + (bigClock.finalX - bigClock.startX) * bigClock.m : bigClock.finalX
                                y: bigClock.fromRect ? bigClock.startY + (bigClock.finalY - bigClock.startY) * bigClock.m
                                                 : bigClock.finalY + contentSlide.y
                            }
                        ]
                    }
                }
            }
        }
    }
}
