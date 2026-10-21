import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import "../"
import "../components"

BarText {
    id: root

    property bool btEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    property int connectedCount: 0
    property var connectedNames: []

    icon: !btEnabled ? "bluetoothOff" : connectedCount > 0 ? "bluetoothConnected" : "bluetooth"
    iconColor: btEnabled ? Theme.text : Theme.subtext

    moduleId: "bluetooth"
    modulePopup: popup

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
        cursorShape: Qt.PointingHandCursor
        onClicked: bluemanProc.running = true
    }

    Process {
        id: bluemanProc
        command: ["blueman-manager"]
    }

    Component {
        id: popup
        Column {
            width: parent ? parent.width : 0
            spacing: 12

            PopupHeader {
                title: "Bluetooth"
                subtitle: !root.btEnabled ? "Off"
                        : root.connectedCount === 0 ? "No devices connected"
                        : root.connectedCount + (root.connectedCount === 1 ? " device connected" : " devices connected")

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.btEnabled
                    onToggled: {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.enabled = !root.btEnabled
                    }
                }
            }

            Column {
                visible: root.connectedNames.length > 0
                width: parent.width
                spacing: 8

                Repeater {
                    model: root.connectedNames.slice(0, 4)
                    Row {
                        required property var modelData
                        spacing: 10
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "bluetoothConnected"
                            size: 14
                            color: Theme.accent
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            font.pixelSize: Theme.textSm
                        }
                    }
                }
            }
        }
    }
}
