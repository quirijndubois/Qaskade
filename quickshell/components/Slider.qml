import QtQuick
import "../"

// Horizontal slider. `value` is 0–1; drag or click emits `moved(newValue)`.
Item {
    id: root

    property real value: 0
    property color fillColor: Theme.text
    signal moved(real newValue)

    implicitHeight: 18

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 6
        radius: 3
        color: Theme.track

        Rectangle {
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.value)))
            height: parent.height
            radius: parent.radius
            color: root.fillColor
        }
    }

    Rectangle {
        x: Math.max(0, Math.min(track.width - width, track.width * root.value - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14; radius: 7
        color: Theme.text
        border.width: 3
        border.color: Theme.base
        scale: area.pressed ? 1.15 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed:         mouse => root.moved(Math.max(0, Math.min(1, mouse.x / width)))
        onPositionChanged: mouse => { if (pressed) root.moved(Math.max(0, Math.min(1, mouse.x / width))) }
    }
}
