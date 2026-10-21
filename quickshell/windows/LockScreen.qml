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
    signal lockReleased()

    function lock() {
        wallpaperProc.running = false
        wallpaperProc.running = true
        wlLock.locked = true
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
        onLockedChanged: if (!locked) root.lockReleased()

        surface: Component {
            WlSessionLockSurface {
                id: surface
                color: Theme.base

                property string passwordInput: ""
                property bool   authFailed:    false
                property bool   authRunning:   false
                property bool   powerMenuOpen: false
                property date   now: new Date()

                property real pwBoxScale:  1.0
                property real pwBoxShiftX: 0.0

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

                SequentialAnimation {
                    id: pulseAnim
                    NumberAnimation { target: surface; property: "pwBoxScale"; to: 1.03; duration: 60;  easing.type: Easing.OutCubic }
                    NumberAnimation { target: surface; property: "pwBoxScale"; to: 1.0;  duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
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
                            pulseAnim.restart()
                        }
                        event.accepted = true
                    }

                    // ── Backdrop ───────────────────────────────────────────
                    Rectangle { anchors.fill: parent; color: Theme.base }

                    Image {
                        id: wallpaperImage
                        anchors.fill: parent
                        source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: wallpaperImage
                        visible: wallpaperImage.status === Image.Ready
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 64
                        saturation: -0.1
                    }

                    // Darken toward the palette base so text stays legible on any image.
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.alpha(Theme.base, wallpaperImage.status === Image.Ready ? 0.45 : 1.0)
                    }

                    // ── Content wrapper — enter/exit animations ────────────
                    Item {
                        id: contentWrapper
                        anchors.fill: parent
                        opacity: 0
                        transform: Translate { id: contentSlide; y: 40 }
                        Component.onCompleted: enterAnim.start()

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
                            }
                            ScriptAction { script: wlLock.locked = false }
                        }

                        // ── Clock ──────────────────────────────────────────
                        Column {
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.16 }
                            spacing: 4

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDate(surface.now, "dddd d MMMM")
                                color: Theme.alpha(Theme.text, 0.85)
                                font.pixelSize: 20
                                font.weight: Font.Medium
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatTime(surface.now, "hh:mm")
                                font.pixelSize: 112
                                font.weight: Font.DemiBold
                                font.letterSpacing: -3
                            }
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
                                scale: surface.pwBoxScale
                                transform: Translate { x: surface.pwBoxShiftX }

                                Label {
                                    anchors.centerIn: parent
                                    visible: surface.passwordInput.length === 0
                                    text: surface.authFailed ? "Incorrect password"
                                        : surface.authRunning ? "Checking…"
                                        : "Enter password"
                                    color: surface.authFailed ? Theme.red : Theme.alpha(Theme.text, 0.55)
                                    font.pixelSize: Theme.textMd
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    visible: surface.passwordInput.length > 0
                                    Repeater {
                                        model: Math.min(surface.passwordInput.length, 22)
                                        delegate: Rectangle {
                                            width: 7; height: 7; radius: 3.5
                                            color: Theme.text
                                            anchors.verticalCenter: parent.verticalCenter
                                            NumberAnimation on scale   { from: 0.4; to: 1; duration: 160; easing.type: Easing.OutBack }
                                            NumberAnimation on opacity { from: 0;   to: 1; duration: 120; easing.type: Easing.OutCubic }
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
                }
            }
        }
    }
}
