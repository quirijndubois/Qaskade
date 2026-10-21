import QtQuick
import Quickshell.Io
import "../"
import "../components"

BarText {
    id: root
    property int memUsage: 0
    property real memUsedGB: 0
    property real memTotalGB: 0
    property var topProcs: []

    caption: "MEM"
    text: memUsage + "%"
    color: memUsage > 85 ? Theme.red : Theme.text
    moduleId: "memory"
    modulePopup: popup

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

    Component {
        id: popup
        Column {
            width: parent ? parent.width : 0
            spacing: 12

            PopupHeader {
                title: "Memory"
                subtitle: root.memUsedGB + " of " + root.memTotalGB + " GB used"
                detail: root.memUsage + "%"
            }

            Meter {
                width: parent.width
                value: root.memUsage
                warnAt: 65
                critAt: 85
            }

            ProcessList {
                width: parent.width
                processes: root.topProcs
                unit: " MB"
            }
        }
    }
}
