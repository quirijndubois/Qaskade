import QtQuick
import Quickshell.Io
import "../"

BarText {
    id: root
    color: Theme.purple

    property string netText: "net --"
    property string ssidFull: ""
    property string ipText: ""

    text: netText
    moduleId: "network"
    modulePopup: popup

    Process {
        id: netProc
        command: ["sh", "-c",
            "SSID=$(iwgetid -r 2>/dev/null | head -c 9); " +
            "if [ -n \"$SSID\" ]; then echo \"wifi $SSID\"; " +
            "elif nmcli dev 2>/dev/null | grep -q 'ethernet.*connected'; then echo 'eth'; " +
            "else echo 'disc'; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                if (out.startsWith("wifi ")) {
                    root.ssidFull = out.slice(5)
                    root.netText = root.ssidFull.length > 9 ? root.ssidFull.slice(0, 9) : root.ssidFull
                } else if (out === "eth") {
                    root.ssidFull = "ethernet"
                    root.netText = "eth"
                } else {
                    root.ssidFull = ""
                    root.netText = "no net"
                }
            }
        }
    }

    Process {
        id: ipProc
        command: ["sh", "-c",
            "ip -4 addr show $(ip route 2>/dev/null | awk '/default/{print $5; exit}') 2>/dev/null " +
            "| awk '/inet/{gsub(/\\/.*/, \"\", $2); print $2; exit}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.ipText = this.text.trim()
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: { netProc.running = true; ipProc.running = true }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: nmEditor.running = true
    }

    Process {
        id: nmEditor
        command: ["nm-connection-editor"]
    }

    Component {
        id: popup
        Column {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6

            Text {
                text: root.ssidFull !== "" ? root.ssidFull : root.netText
                color: Theme.purple
                font.family: Theme.barFontFamily
                font.pixelSize: 18
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                visible: root.ipText !== ""
                text: root.ipText
                color: Theme.subtext
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }

            Text {
                text: root.netText === "no net" ? "disconnected" : root.ssidFull.length > 0 ? "wifi" : "ethernet"
                color: root.netText === "no net" ? Theme.red : Theme.teal
                font.family: Theme.barFontFamily
                font.pixelSize: 11
            }
        }
    }
}
