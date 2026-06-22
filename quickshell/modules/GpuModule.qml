import QtQuick
import Quickshell.Io
import "../"

BarText {
    id: root
    color: Theme.blue

    property int gpuUsage: 0
    property int vramUsed: 0
    property int vramTotal: 0
    property var topProcs: []

    text: "gpu " + gpuUsage + "%"
    moduleId: "gpu"
    modulePopup: popup
    popupHeight: 210

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

            UsageBar {
                width: parent.width
                value: root.gpuUsage
                fillColor: Theme.blue
            }

            ProcessList {
                width: parent.width
                processes: root.topProcs
                accentColor: Theme.blue
                unit: " MB"
                sectionLabel: root.topProcs.length > 0 ? "gpu processes" : "no gpu processes"
            }
        }
    }
}
