import QtQuick
import "../"

// Thin horizontal level indicator. `value` is 0–100.
Rectangle {
    id: root

    property real value: 0
    property color fillColor: Theme.text
    property real warnAt: 101
    property real critAt: 101
    property bool invertThresholds: false

    readonly property bool _crit: invertThresholds ? value < critAt : value > critAt
    readonly property bool _warn: invertThresholds ? value < warnAt : value > warnAt

    implicitHeight: 4
    radius: height / 2
    color: Theme.track

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.value / 100))
        height: parent.height
        radius: parent.radius
        color: root._crit ? Theme.red : root._warn ? Theme.yellow : root.fillColor
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}
