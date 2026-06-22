import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "../"

Item {
    id: root
    visible: false

    property string username: ""
    property string resolvedDesign: "default"
    signal lockReleased()

    function lock() {
        const all = ["default", "minimal", "clock", "terminal", "split"]
        resolvedDesign = Theme.lockDesign === "random"
            ? all[Math.floor(Math.random() * all.length)]
            : Theme.lockDesign
        wlLock.locked = true
    }

    Process {
        command: ["sh", "-c", "id -un"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.username = this.text.trim() }
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
                property string timeStr: Qt.formatTime(new Date(), "hh:mm")
                property string dateStr: Qt.formatDate(new Date(), "dddd, MMMM d")

                // Shared animation state — all designs' password boxes bind to these
                property real pwBoxScale:  1.0
                property real pwBoxShiftX: 0.0

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: {
                        surface.timeStr = Qt.formatTime(new Date(), "hh:mm")
                        surface.dateStr = Qt.formatDate(new Date(), "dddd, MMMM d")
                    }
                }

                Timer { id: failTimer; interval: 800; onTriggered: surface.authFailed = false }

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
                    NumberAnimation { target: surface; property: "pwBoxScale"; to: 1.045; duration: 60;  easing.type: Easing.OutCubic }
                    NumberAnimation { target: surface; property: "pwBoxScale"; to: 1.0;   duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
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
                        } else if (event.text && event.text.charCodeAt(0) >= 32) {
                            surface.passwordInput += event.text
                            surface.authFailed = false
                            pulseAnim.restart()
                        }
                        event.accepted = true
                    }

                    Rectangle { anchors.fill: parent; color: Theme.base }

                    // ── Content wrapper — enter/exit animations ────────────
                    Item {
                        id: contentWrapper
                        anchors.fill: parent
                        opacity: 0
                        transform: Translate { id: contentSlide; y: 50 }
                        Component.onCompleted: enterAnim.start()

                        SequentialAnimation {
                            id: enterAnim
                            ParallelAnimation {
                                NumberAnimation { target: contentSlide; property: "y"; from: 50; to: 0; duration: 420; easing.type: Easing.OutExpo }
                                NumberAnimation { target: contentWrapper; property: "opacity"; from: 0; to: 1; duration: 340; easing.type: Easing.OutCubic }
                            }
                        }

                        SequentialAnimation {
                            id: exitAnim
                            ParallelAnimation {
                                NumberAnimation { target: contentSlide; property: "y"; to: -60; duration: 260; easing.type: Easing.InCubic }
                                NumberAnimation { target: contentWrapper; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
                            }
                            ScriptAction { script: wlLock.locked = false }
                        }

                        // ── default ────────────────────────────────────────
                        Column {
                            visible: root.resolvedDesign === "default" || root.resolvedDesign === ""
                            anchors.centerIn: parent
                            spacing: 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: surface.timeStr; color: Theme.text
                                font.family: "JetBrains Mono"; font.pixelSize: 96; font.bold: true
                            }
                            Item { width: 1; height: 4 }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: surface.dateStr; color: Theme.subtext
                                font.family: "JetBrains Mono"; font.pixelSize: 18
                            }
                            Item { width: 1; height: 4 }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 280; height: 1; color: Theme.border; opacity: 0.5
                            }
                            Item { width: 1; height: 44 }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                                Text {
                                    text: ""; color: Theme.purple
                                    font.family: "Symbols Nerd Font Mono"; font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.username; color: Theme.purple
                                    font.family: "JetBrains Mono"; font.pixelSize: 14; font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Item { width: 1; height: 14 }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 280; height: 42; radius: 6
                                color: Theme.surface; border.width: 1
                                border.color: surface.authFailed ? Theme.red : Theme.border
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                scale: surface.pwBoxScale
                                transform: Translate { x: surface.pwBoxShiftX }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !surface.authFailed && surface.passwordInput.length === 0
                                    text: "enter password"; color: Theme.subtext
                                    font.family: "JetBrains Mono"; font.pixelSize: 12
                                }
                                Row {
                                    anchors.centerIn: parent; spacing: 8
                                    visible: !surface.authFailed && surface.passwordInput.length > 0
                                    Repeater {
                                        model: Math.min(surface.passwordInput.length, 28)
                                        delegate: Rectangle {
                                            width: 6; height: 6; radius: 3; color: Theme.blue
                                            anchors.verticalCenter: parent.verticalCenter
                                            property real slide: -14
                                            transform: Translate { x: slide }
                                            NumberAnimation on slide   { from: -14; to: 0; duration: 240; easing.type: Easing.OutCubic }
                                            NumberAnimation on opacity { from: 0;   to: 1; duration: 120; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent; visible: surface.authFailed
                                    text: "incorrect password"; color: Theme.red
                                    font.family: "JetBrains Mono"; font.pixelSize: 12
                                }
                            }
                        }

                        // ── minimal ────────────────────────────────────────
                        Column {
                            visible: root.resolvedDesign === "minimal"
                            anchors.centerIn: parent
                            spacing: 0

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 200; height: 36; radius: 18
                                color: Theme.surface; border.width: 1
                                border.color: surface.authFailed ? Theme.red : Theme.border
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                scale: surface.pwBoxScale
                                transform: Translate { x: surface.pwBoxShiftX }

                                Row {
                                    anchors.centerIn: parent; spacing: 10
                                    visible: surface.passwordInput.length > 0 && !surface.authFailed
                                    Repeater {
                                        model: Math.min(surface.passwordInput.length, 16)
                                        delegate: Rectangle {
                                            width: 5; height: 5; radius: 3; color: Theme.blue
                                            anchors.verticalCenter: parent.verticalCenter
                                            property real slide: -15
                                            transform: Translate { x: slide }
                                            NumberAnimation on slide   { from: -15; to: 0; duration: 240; easing.type: Easing.OutCubic }
                                            NumberAnimation on opacity { from: 0;   to: 1; duration: 120; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }

                                // Subtle red dash on failure
                                Rectangle {
                                    visible: surface.authFailed
                                    anchors.centerIn: parent
                                    width: 20; height: 2; radius: 1; color: Theme.red
                                }
                            }
                        }

                        // ── clock ──────────────────────────────────────────
                        Column {
                            visible: root.resolvedDesign === "clock"
                            anchors.centerIn: parent
                            spacing: 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: surface.timeStr; color: Theme.text
                                font.family: "JetBrains Mono"; font.pixelSize: 164; font.bold: true
                                opacity: 0.9
                            }
                            Item { width: 1; height: 36 }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 240; height: 36; radius: 18
                                color: Theme.surface; border.width: 1
                                border.color: surface.authFailed ? Theme.red : Theme.border
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                scale: surface.pwBoxScale
                                transform: Translate { x: surface.pwBoxShiftX }

                                Row {
                                    anchors.centerIn: parent; spacing: 8
                                    visible: !surface.authFailed && surface.passwordInput.length > 0
                                    Repeater {
                                        model: Math.min(surface.passwordInput.length, 22)
                                        delegate: Rectangle {
                                            width: 5; height: 5; radius: 3; color: Theme.blue
                                            anchors.verticalCenter: parent.verticalCenter
                                            property real slide: -13
                                            transform: Translate { x: slide }
                                            NumberAnimation on slide   { from: -13; to: 0; duration: 240; easing.type: Easing.OutCubic }
                                            NumberAnimation on opacity { from: 0;   to: 1; duration: 120; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent; visible: surface.authFailed
                                    text: "×"; color: Theme.red
                                    font.family: "JetBrains Mono"; font.pixelSize: 16; font.bold: true
                                }
                            }
                        }

                        // ── terminal ───────────────────────────────────────
                        Column {
                            visible: root.resolvedDesign === "terminal"
                            anchors.centerIn: parent
                            spacing: 0

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 360; height: 156; radius: 8
                                color: Theme.surface; border.width: 1
                                border.color: surface.authFailed ? Theme.red : Theme.border
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                scale: surface.pwBoxScale
                                transform: Translate { x: surface.pwBoxShiftX }

                                Column {
                                    anchors { left: parent.left; top: parent.top; margins: 20 }
                                    spacing: 0

                                    Row {
                                        spacing: 4
                                        Text {
                                            text: root.username + "@qaskade"; color: Theme.green
                                            font.family: "JetBrains Mono"; font.pixelSize: 13; font.bold: true
                                        }
                                        Text {
                                            text: " ~ %"; color: Theme.subtext
                                            font.family: "JetBrains Mono"; font.pixelSize: 13
                                        }
                                    }
                                    Item { width: 1; height: 10 }
                                    Rectangle { width: 320; height: 1; color: Theme.border; opacity: 0.5 }
                                    Item { width: 1; height: 16 }
                                    Text {
                                        text: "password:"; color: Theme.subtext
                                        font.family: "JetBrains Mono"; font.pixelSize: 12
                                    }
                                    Item { width: 1; height: 10 }
                                    Item {
                                        width: 320; height: 20
                                        Row {
                                            spacing: 8
                                            visible: !surface.authFailed && surface.passwordInput.length > 0
                                            Repeater {
                                                model: Math.min(surface.passwordInput.length, 22)
                                                delegate: Rectangle {
                                                    width: 6; height: 6; radius: 3; color: Theme.blue
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    property real slide: -14
                                                    transform: Translate { x: slide }
                                                    NumberAnimation on slide   { from: -14; to: 0; duration: 240; easing.type: Easing.OutCubic }
                                                    NumberAnimation on opacity { from: 0;   to: 1; duration: 120; easing.type: Easing.OutCubic }
                                                }
                                            }
                                        }
                                        Text {
                                            visible: !surface.authFailed && surface.passwordInput.length === 0
                                            text: "_"; color: Theme.text
                                            font.family: "JetBrains Mono"; font.pixelSize: 13
                                            SequentialAnimation on opacity {
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 0; duration: 500 }
                                                NumberAnimation { to: 1; duration: 100 }
                                            }
                                        }
                                        Text {
                                            visible: surface.authFailed
                                            text: "authentication failed"; color: Theme.red
                                            font.family: "JetBrains Mono"; font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }

                        // ── split ──────────────────────────────────────────
                        Item {
                            visible: root.resolvedDesign === "split"
                            anchors.centerIn: parent
                            width: 660; height: 130

                            Column {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                spacing: 0; width: 280

                                Text {
                                    text: surface.timeStr; color: Theme.text
                                    font.family: "JetBrains Mono"; font.pixelSize: 72; font.bold: true
                                }
                                Item { width: 1; height: 6 }
                                Text {
                                    text: surface.dateStr; color: Theme.subtext
                                    font.family: "JetBrains Mono"; font.pixelSize: 15
                                }
                            }

                            Rectangle {
                                anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                                width: 1; height: 100; color: Theme.border; opacity: 0.4
                            }

                            Column {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                spacing: 0

                                Row {
                                    spacing: 8
                                    Text {
                                        text: ""; color: Theme.purple
                                        font.family: "Symbols Nerd Font Mono"; font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.username; color: Theme.purple
                                        font.family: "JetBrains Mono"; font.pixelSize: 13; font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Item { width: 1; height: 12 }
                                Rectangle {
                                    width: 240; height: 42; radius: 6
                                    color: Theme.surface; border.width: 1
                                    border.color: surface.authFailed ? Theme.red : Theme.border
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    scale: surface.pwBoxScale
                                    transform: Translate { x: surface.pwBoxShiftX }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !surface.authFailed && surface.passwordInput.length === 0
                                        text: "enter password"; color: Theme.subtext
                                        font.family: "JetBrains Mono"; font.pixelSize: 12
                                    }
                                    Row {
                                        anchors.centerIn: parent; spacing: 8
                                        visible: !surface.authFailed && surface.passwordInput.length > 0
                                        Repeater {
                                            model: Math.min(surface.passwordInput.length, 22)
                                            delegate: Rectangle {
                                                width: 6; height: 6; radius: 3; color: Theme.blue
                                                anchors.verticalCenter: parent.verticalCenter
                                                property real slide: -14
                                                transform: Translate { x: slide }
                                                NumberAnimation on slide   { from: -14; to: 0; duration: 240; easing.type: Easing.OutCubic }
                                                NumberAnimation on opacity { from: 0;   to: 1; duration: 120; easing.type: Easing.OutCubic }
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.centerIn: parent; visible: surface.authFailed
                                        text: "incorrect password"; color: Theme.red
                                        font.family: "JetBrains Mono"; font.pixelSize: 12
                                    }
                                }
                            }
                        }

                        // ── power overlay ───────────────────────────────────────────
                        Item {
                            anchors { bottom: parent.bottom; right: parent.right; bottomMargin: 24; rightMargin: 24 }
                            width: 32; height: 32

                            Row {
                                anchors { right: parent.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                spacing: 8
                                opacity: surface.powerMenuOpen ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                Repeater {
                                    model: [
                                        { label: "suspend",   icon: "", col: Theme.teal,   cmd: ["systemctl", "suspend"]   },
                                        { label: "hibernate", icon: "󰤄", col: Theme.purple, cmd: ["systemctl", "hibernate"] },
                                        { label: "reboot",    icon: "", col: Theme.yellow, cmd: ["systemctl", "reboot"]    },
                                        { label: "shut down", icon: "⏻", col: Theme.red,    cmd: ["systemctl", "poweroff"]  },
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 32; height: 32; radius: 16
                                        color: Theme.surface; border.width: 1; border.color: Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            color: modelData.col
                                            font.family: "Symbols Nerd Font Mono"; font.pixelSize: 14
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                surface.powerMenuOpen = false
                                                lockPowerProc.command = modelData.cmd
                                                lockPowerProc.running = false
                                                Qt.callLater(() => { lockPowerProc.running = true })
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent; radius: 16
                                color: surface.powerMenuOpen ? Theme.red : Theme.surface
                                border.width: 1
                                border.color: surface.powerMenuOpen ? Theme.red : Theme.border
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "⏻"
                                    color: surface.powerMenuOpen ? Theme.base : Theme.subtext
                                    font.family: "Symbols Nerd Font Mono"; font.pixelSize: 14
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: surface.powerMenuOpen = !surface.powerMenuOpen
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
