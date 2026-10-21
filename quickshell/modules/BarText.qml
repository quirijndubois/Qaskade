import QtQuick
import "../"
import "../components"

// Basic bar item: optional glyph, optional dim caption, optional value text.
// Shows its `modulePopup` under the bar while hovered.
Item {
    id: root

    property string icon: ""
    property string caption: ""
    property string text: ""
    property color color: Theme.text
    property color iconColor: color

    property string moduleId: ""
    property Component modulePopup: null
    property var screen: null

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: Theme.barFontSize + 2
            color: root.iconColor
        }

        Label {
            visible: root.caption !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.caption
            color: Theme.subtext
            font.pixelSize: Theme.barFontSize - 2
            font.weight: Font.DemiBold
        }

        Label {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.color
            font.pixelSize: Theme.barFontSize
            font.weight: Font.Medium
        }
    }

    HoverHandler {
        enabled: root.moduleId !== ""
        onHoveredChanged: {
            if (hovered)
                BarHover.show(root.moduleId, root.modulePopup, root.mapToItem(null, root.width / 2, 0).x, root.screen)
            else
                BarHover.startHide()
        }
    }
}
