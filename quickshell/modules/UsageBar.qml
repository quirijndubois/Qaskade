import QtQuick
import "../"

Rectangle {
    id: root

    property real value: 0
    property color fillColor: Theme.blue
    property color warnColor: Theme.yellow
    property color critColor: Theme.red
    property real warnAt: 50
    property real critAt: 80
    property bool invertThresholds: false

    height: 5
    radius: 2
    color: Theme.border

    Rectangle {
        width: parent.width * Math.min(1, root.value / 100)
        height: parent.height
        radius: parent.radius
        color: root.invertThresholds
            ? (root.value < root.critAt ? root.critColor : root.value < root.warnAt ? root.warnColor : root.fillColor)
            : (root.value > root.critAt ? root.critColor : root.value > root.warnAt ? root.warnColor : root.fillColor)
        Behavior on width { NumberAnimation { duration: 300 } }
    }
}
