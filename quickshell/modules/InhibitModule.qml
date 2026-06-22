import QtQuick
import QtQuick.Window
import Quickshell.Wayland._IdleInhibitor
import "../"

BarText {
    id: root

    text: "☾"
    color: InhibitState.inhibited ? Theme.yellow : Theme.subtext

    moduleId: "inhibit"
    modulePopup: popup
    popupHeight: 80

    IdleInhibitor {
        enabled: InhibitState.inhibited
        window:  root.Window.window
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
