import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import "../"

BarText {
    id: root
    color: Theme.teal

    property var screen: null
    property bool btEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    property int connectedCount: 0
    property var connectedNames: []

    text: {
        if (!btEnabled) return "bt off"
        if (connectedCount > 0) return "bt " + connectedCount
        return "bt on"
    }

    Item {
        width: 0; height: 0

        Repeater {
            id: btRep
            model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : null
            onCountChanged: root.refreshCount()

            delegate: Item {
                required property var modelData
                width: 0; height: 0
                property bool conn: modelData.connected
                onConnChanged: root.refreshCount()
                Component.onCompleted: root.refreshCount()
            }
        }
    }

    function refreshCount() {
        let c = 0
        const names = []
        for (let i = 0; i < btRep.count; i++) {
            const item = btRep.itemAt(i)
            if (item && item.conn) {
                c++
                if (item.modelData && item.modelData.name) names.push(item.modelData.name)
            }
        }
        connectedCount = c
        connectedNames = names
    }

    MouseArea {
        anchors.fill: parent
        onClicked: bluemanProc.running = true
    }

    Process {
        id: bluemanProc
        command: ["blueman-manager"]
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("bluetooth", popup, root.mapToItem(null, root.width / 2, 0).x, 0, root.screen)
            else
                BarHover.startHide()
        }
    }

    Component {
        id: popup
        Column {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8

            Row {
                spacing: 10

                Text {
                    text: root.btEnabled ? "on" : "off"
                    color: root.btEnabled ? Theme.teal : Theme.subtext
                    font.family: Theme.barFontFamily
                    font.pixelSize: 20
                    font.bold: true
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    text: root.btEnabled ? "turn off" : "turn on"
                    color: Theme.subtext
                    font.family: Theme.barFontFamily
                    font.pixelSize: 10
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Bluetooth.defaultAdapter)
                                Bluetooth.defaultAdapter.enabled = !root.btEnabled
                        }
                    }
                }
            }

            Column {
                spacing: 3
                width: parent.width

                Repeater {
                    model: root.connectedNames.slice(0, 3)
                    Text {
                        required property var modelData
                        text: "· " + modelData
                        color: Theme.subtext
                        font.family: Theme.barFontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                Text {
                    visible: root.connectedCount === 0 && root.btEnabled
                    text: "no devices connected"
                    color: Theme.subtext
                    font.family: Theme.barFontFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}
