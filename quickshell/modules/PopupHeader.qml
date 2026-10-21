import QtQuick
import "../"
import "../components"

// Title row at the top of a bar popup: title + subtitle on the left,
// a detail value (or any declared children) on the right.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string detail: ""
    property color detailColor: Theme.text
    default property alias trailing: trailingRow.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(textCol.implicitHeight, trailingRow.implicitHeight)

    Column {
        id: textCol
        anchors { left: parent.left; right: trailingRow.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 2

        Label {
            width: parent.width
            text: root.title
            font.pixelSize: Theme.textMd
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Theme.subtext
            font.pixelSize: Theme.textSm
            elide: Text.ElideRight
        }
    }

    Row {
        id: trailingRow
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 8

        Label {
            visible: root.detail !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.detail
            color: root.detailColor
            font.pixelSize: Theme.textMd
            font.weight: Font.Medium
        }
    }
}
