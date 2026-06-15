import QtQuick
import Quickshell.Io
import "../"

BarText {
    id: root
    color: Theme.red

    property var screen: null
    property int memUsage: 0
    property real memUsedGB: 0
    property real memTotalGB: 0
    property var topProcs: []

    text: "mem " + memUsage + "%"

    Process {
        id: memProc
        command: ["sh", "-c", "awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2} END{print t,a}' /proc/meminfo"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(" ")
                const total = parseInt(parts[0]) || 0
                const avail = parseInt(parts[1]) || 0
                root.memTotalGB = parseFloat((total / 1048576).toFixed(1))
                root.memUsedGB  = parseFloat(((total - avail) / 1048576).toFixed(1))
                root.memUsage   = total > 0 ? Math.round((total - avail) / total * 100) : 0
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: memProc.running = true
    }

    Process {
        id: topMemProc
        command: ["sh", "-c",
            "ps --no-headers -eo comm,rss --sort=-rss 2>/dev/null | head -10 | " +
            "awk '$2+0>0 && $1!~/^\\[/ { n=$1; sub(/.*\\//, \"\", n); sub(/:.*/, \"\", n); printf \"%s\\t%d\\n\", n, $2/1024 }' | head -5"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.topProcs = this.text.trim().split("\n")
                    .filter(l => l.length > 0)
                    .map(l => { const p = l.split("\t"); return { name: p[0] || "", value: p[1] || "0" } })
            }
        }
    }

    Connections {
        target: BarHover
        function onActiveModuleChanged() {
            if (BarHover.activeModule === "memory") topMemProc.running = true
        }
    }

    Timer {
        interval: 4000
        running: BarHover.activeModule === "memory"
        repeat: true
        onTriggered: if (!topMemProc.running) topMemProc.running = true
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("memory", popup, root.mapToItem(null, root.width / 2, 0).x, 210, root.screen)
            else
                BarHover.startHide()
        }
    }

    Component {
        id: popup
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 6

            Row {
                spacing: 8
                Text {
                    text: root.memUsage + "%"
                    color: Theme.red
                    font.family: Theme.barFontFamily
                    font.pixelSize: 20
                    font.bold: true
                }
                Text {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                    text: root.memUsedGB + " / " + root.memTotalGB + " GB"
                    color: Theme.subtext
                    font.family: Theme.barFontFamily
                    font.pixelSize: 10
                }
            }

            Rectangle {
                width: parent.width
                height: 5
                radius: 2
                color: Theme.border
                Rectangle {
                    width: parent.parent.width * (root.memUsage / 100)
                    height: parent.height; radius: parent.radius
                    color: root.memUsage > 85 ? Theme.red : root.memUsage > 65 ? Theme.yellow : Theme.teal
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.5 }

            Text {
                text: "top processes"
                color: Theme.subtext
                font.family: Theme.barFontFamily
                font.pixelSize: 10
            }

            Column {
                width: parent.width
                spacing: 3
                Repeater {
                    model: root.topProcs
                    Row {
                        required property var modelData
                        width: parent.width
                        Text {
                            width: parent.width - valText.width
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.barFontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Text {
                            id: valText
                            text: modelData.value + " MB"
                            color: Theme.red
                            font.family: Theme.barFontFamily
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
