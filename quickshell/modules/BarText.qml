import QtQuick
import "../"

Item {
    id: root

    property alias text: label.text
    property alias color: label.color

    implicitWidth: label.implicitWidth + (Theme.design === "pills" ? 20 : 0)
    implicitHeight: Theme.design === "pills" ? Theme.barHeight - 8 : label.implicitHeight

    Rectangle {
        visible: Theme.design === "pills"
        anchors.centerIn: parent
        width: label.implicitWidth + 20
        height: root.implicitHeight
        radius: height / 2
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.text
        font.family: Theme.barFontFamily
        font.pixelSize: Theme.barFontSize
        font.bold: Theme.barFontBold
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
    }
}
