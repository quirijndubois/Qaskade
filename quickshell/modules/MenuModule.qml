import QtQuick
import "../"

// 2×2 dot grid that opens the settings overlay.
Item {
    id: root

    property bool active: false
    signal clicked()

    implicitWidth: 14
    implicitHeight: Theme.barHeight

    Grid {
        anchors.centerIn: parent
        columns: 2
        spacing: 3

        Repeater {
            model: 4
            Rectangle {
                width: 5; height: 5; radius: 1.5
                color: root.active ? Theme.accent : Theme.text
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }

    MouseArea {
        anchors { fill: parent; margins: -4 }
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
