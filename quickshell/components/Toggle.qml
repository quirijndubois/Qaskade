import QtQuick
import "../"

// On/off switch. Emits `toggled` on click; the owner flips `checked`.
Rectangle {
    id: root

    property bool checked: false
    property bool interactive: true
    signal toggled()

    width: 36
    height: 20
    radius: height / 2
    color: checked ? Theme.accent : Theme.track
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 2 : 2
        color: root.checked ? Theme.base : Theme.text
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
