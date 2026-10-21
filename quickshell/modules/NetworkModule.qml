import QtQuick
import Quickshell.Io
import "../"
import "../components"

// Wi-Fi shows as four signal bars, ethernet as a glyph.
Item {
    id: root

    property var screen: null

    property string kind: "none"     // "wifi" | "ethernet" | "none"
    property string ssid: ""
    property int signal: 0           // 0–100, Wi-Fi only
    property string ipText: ""

    readonly property int level: kind !== "wifi" ? 0
                               : signal >= 75 ? 4 : signal >= 50 ? 3 : signal >= 25 ? 2 : 1

    implicitWidth: kind === "wifi" ? bars.width : glyph.width
    implicitHeight: Theme.barHeight

    Process {
        id: netProc
        command: ["sh", "-c",
            "w=$(nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi list --rescan no 2>/dev/null | grep '^yes:' | head -1); " +
            "if [ -n \"$w\" ]; then echo \"wifi:$w\"; " +
            "elif nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^ethernet:connected'; then echo 'ethernet'; " +
            "else echo 'none'; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                if (out.startsWith("wifi:")) {
                    // wifi:yes:<signal>:<ssid>
                    const p = out.split(":")
                    root.kind = "wifi"
                    root.signal = parseInt(p[2]) || 0
                    root.ssid = p.slice(3).join(":")
                } else {
                    root.kind = out === "ethernet" ? "ethernet" : "none"
                    root.ssid = ""
                    root.signal = 0
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

    Row {
        id: bars
        visible: root.kind === "wifi"
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: 4
            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: 3
                height: 4 + index * 2.5
                radius: 1
                color: index < root.level ? Theme.text : Theme.alpha(Theme.text, 0.25)
            }
        }
    }

    Icon {
        id: glyph
        visible: root.kind !== "wifi"
        anchors.verticalCenter: parent.verticalCenter
        name: root.kind === "ethernet" ? "ethernet" : "wifiOff"
        size: Theme.barFontSize + 2
        color: root.kind === "none" ? Theme.subtext : Theme.text
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: nmEditor.running = true
    }

    Process {
        id: nmEditor
        command: ["nm-connection-editor"]
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("network", popup, root.mapToItem(null, root.width / 2, 0).x, root.screen)
            else
                BarHover.startHide()
        }
    }

    Component {
        id: popup
        Column {
            width: parent ? parent.width : 0
            spacing: 12

            PopupHeader {
                title: root.kind === "wifi" ? root.ssid
                     : root.kind === "ethernet" ? "Ethernet"
                     : "Not connected"
                subtitle: root.kind === "wifi" ? "Wi-Fi · " + root.signal + "% signal"
                        : root.kind === "ethernet" ? "Wired connection"
                        : "No network available"
            }

            Item {
                visible: root.ipText !== "" && root.kind !== "none"
                width: parent.width
                height: 18

                Label {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "IP address"
                    color: Theme.subtext
                    font.pixelSize: Theme.textSm
                }
                Label {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: root.ipText
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.textSm
                }
            }
        }
    }
}
