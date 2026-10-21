import QtQuick
import "../"

// Title bar for a settings page: optional back chevron, title, trailing detail.
Item {
    id: root

    property string title: ""
    property string detail: ""
    property color detailColor: Theme.subtext
    property bool showBack: true
    default property alias trailing: trailingRow.data

    signal backClicked()

    width: parent ? parent.width : 0
    height: 56

    Row {
        id: titleRow
        anchors { left: parent.left; leftMargin: root.showBack ? 14 : 20; verticalCenter: parent.verticalCenter }
        spacing: 4

        HoverHandler { id: backHover; enabled: root.showBack; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: root.showBack; onTapped: root.backClicked() }

        Icon {
            visible: root.showBack
            anchors.verticalCenter: parent.verticalCenter
            name: "chevronLeft"
            size: 20
            color: backHover.hovered ? Theme.text : Theme.subtext
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.pixelSize: Theme.textLg
            font.weight: Font.DemiBold
        }
    }

    Row {
        id: trailingRow
        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
        spacing: 12

        Label {
            visible: root.detail !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.detail
            color: root.detailColor
            font.pixelSize: Theme.textSm
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20 }
        height: 1
        color: Theme.hairline
    }
}
