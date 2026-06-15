import QtQuick
import Quickshell.Io
import "../"

BarText {
    id: root
    color: Theme.blue

    property var screen: null
    property int gpuUsage: 0
    property int vramUsed: 0
    property int vramTotal: 0
    property var topProcs: []

    text: "gpu " + gpuUsage + "%"

    Process {
        id: gpuProc
        command: ["sh", "-c",
            "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || echo '0, 0, 0'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(",").map(s => parseInt(s.trim()) || 0)
                root.gpuUsage  = Math.min(100, Math.max(0, parts[0]))
                root.vramUsed  = parts[1]
                root.vramTotal = parts[2]
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: gpuProc.running = true
    }

    Process {
        id: topGpuProc
        command: ["sh", "-c",
            "nvidia-smi --query-compute-apps=name,used_memory --format=csv,noheader 2>/dev/null | " +
            "awk -F', ' '{ n=$1; sub(/.*\\//, \"\", n); gsub(/ MiB$/, \"\", $2); printf \"%s\\t%s\\n\", n, $2 }' | " +
            "sort -t'\t' -k2 -rn | head -5"]
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
            if (BarHover.activeModule === "gpu") topGpuProc.running = true
        }
    }

    Timer {
        interval: 4000
        running: BarHover.activeModule === "gpu"
        repeat: true
        onTriggered: if (!topGpuProc.running) topGpuProc.running = true
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("gpu", popup, root.mapToItem(null, root.width / 2, 0).x, 210, root.screen)
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
                    text: root.gpuUsage + "%"
                    color: Theme.blue
                    font.family: Theme.barFontFamily
                    font.pixelSize: 20
                    font.bold: true
                }
                Text {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                    visible: root.vramTotal > 0
                    text: root.vramUsed + " / " + root.vramTotal + " MB"
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
                    width: parent.parent.width * (root.gpuUsage / 100)
                    height: parent.height; radius: parent.radius
                    color: root.gpuUsage > 80 ? Theme.red : root.gpuUsage > 50 ? Theme.yellow : Theme.blue
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.5 }

            Text {
                text: root.topProcs.length > 0 ? "gpu processes" : "no gpu processes"
                color: Theme.subtext
                font.family: Theme.barFontFamily
                font.pixelSize: 10
            }

            Column {
                width: parent.width
                spacing: 3
                visible: root.topProcs.length > 0
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
