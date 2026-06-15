import QtQuick
import QtQuick.Window
import Quickshell.Wayland._IdleInhibitor
import "../"

BarText {
    id: root

    property var screen: null

    text: "☾"
    color: InhibitState.inhibited ? Theme.yellow : Theme.subtext

    IdleInhibitor {
        enabled: InhibitState.inhibited
        window:  root.Window.window
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("inhibit", popup, root.mapToItem(null, root.width / 2, 0).x, 80, root.screen)
            else
                BarHover.startHide()
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: InhibitState.inhibited = !InhibitState.inhibited
    }

    Component {
        id: popup
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 8

            Text {
                text: InhibitState.inhibited ? "active" : "inactive"
                color: InhibitState.inhibited ? Theme.yellow : Theme.subtext
                font.family: Theme.barFontFamily
                font.pixelSize: 20
                font.bold: true
            }

            Text {
                text: InhibitState.inhibited ? "sleep inhibited" : "sleep allowed"
                color: Theme.subtext
                font.family: Theme.barFontFamily
                font.pixelSize: 11
            }
        }
    }
}
