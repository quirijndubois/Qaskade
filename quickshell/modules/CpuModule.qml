import QtQuick
import Quickshell.Io
import "../"

BarText {
    id: root
    color: Theme.blue

    property var screen: null
    property int cpuUsage: 0
    property var prevStat: null
    property var coreStat: []
    property var coreUsage: []
    property var topProcs: []

    text: "cpu " + cpuUsage + "%"

    Process {
        id: statProc
        command: ["sh", "-c", "grep '^cpu' /proc/stat"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")

                // First line is aggregate
                const aggParts = lines[0].trim().split(/\s+/)
                const aggVals = aggParts.slice(1).map(v => parseInt(v) || 0)
                const aggIdle = aggVals[3] + (aggVals[4] || 0)
                const aggTotal = aggVals.reduce((a, b) => a + b, 0)
                if (root.prevStat) {
                    const dTotal = aggTotal - root.prevStat.total
                    const dIdle  = aggIdle  - root.prevStat.idle
                    root.cpuUsage = dTotal > 0 ? Math.round((dTotal - dIdle) / dTotal * 100) : 0
                }
                root.prevStat = { idle: aggIdle, total: aggTotal }

                // Remaining lines are per-core
                const coreLines = lines.slice(1)
                const newStat = []
                const usage = []
                for (let i = 0; i < coreLines.length; i++) {
                    const parts = coreLines[i].trim().split(/\s+/)
                    const vals = parts.slice(1).map(v => parseInt(v) || 0)
                    const idle = vals[3] + (vals[4] || 0)
                    const total = vals.reduce((a, b) => a + b, 0)
                    const prev = root.coreStat[i]
                    if (prev) {
                        const dTotal = total - prev.total
                        const dIdle  = idle  - prev.idle
                        usage.push(dTotal > 0 ? Math.round((dTotal - dIdle) / dTotal * 100) : 0)
                    } else {
                        usage.push(0)
                    }
                    newStat.push({ idle, total })
                }
                root.coreStat = newStat
                root.coreUsage = usage
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: statProc.running = true
    }

    Process {
        id: topProc
        command: ["sh", "-c",
            "ps --no-headers -eo comm,pcpu --sort=-pcpu 2>/dev/null | head -10 | " +
            "awk '$2+0>0 && $1!~/^\\[/ { n=$1; sub(/.*\\//, \"\", n); sub(/:.*/, \"\", n); printf \"%s\\t%.1f\\n\", n, $2 }' | head -5"]
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
            if (BarHover.activeModule === "cpu") topProc.running = true
        }
    }

    Timer {
        interval: 3000
        running: BarHover.activeModule === "cpu"
        repeat: true
        onTriggered: if (!topProc.running) topProc.running = true
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("cpu", popup, root.mapToItem(null, root.width / 2, 0).x, 220, root.screen)
            else
                BarHover.startHide()
        }
    }

    Component {
        id: popup
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 6

            Text {
                text: root.cpuUsage + "%"
                color: Theme.blue
                font.family: Theme.barFontFamily
                font.pixelSize: 20
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: 5
                radius: 2
                color: Theme.border
                Rectangle {
                    width: parent.parent.width * (root.cpuUsage / 100)
                    height: parent.height; radius: parent.radius
                    color: root.cpuUsage > 80 ? Theme.red : root.cpuUsage > 50 ? Theme.yellow : Theme.blue
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }

            Item {
                id: coreRow
                width: parent.width
                height: 14
                property real barW: coreUsage.length > 0
                    ? Math.floor((width - coreUsage.length + 1) / coreUsage.length)
                    : width

                Repeater {
                    model: root.coreUsage
                    Rectangle {
                        required property var modelData
                        required property int index
                        x: index * (coreRow.barW + 1)
                        width: coreRow.barW
                        height: coreRow.height
                        color: Theme.border
                        radius: 1
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: Math.max(2, parent.height * modelData / 100)
                            color: modelData > 80 ? Theme.red : modelData > 50 ? Theme.yellow : Theme.blue
                            radius: 1
                            Behavior on height { NumberAnimation { duration: 300 } }
                        }
                    }
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
                            text: modelData.value + "%"
                            color: Theme.blue
                            font.family: Theme.barFontFamily
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
