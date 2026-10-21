import QtQuick
import QtQuick.Window
import Quickshell.Wayland._IdleInhibitor
import "../"
import "../components"

// Coffee cup that keeps the screen awake while active.
BarText {
    id: root

    icon: "coffee"
    iconColor: InhibitState.inhibited ? Theme.accent : Theme.subtext

    moduleId: "inhibit"
    modulePopup: popup

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
            width: parent ? parent.width : 0

            PopupHeader {
                title: "Keep awake"
                subtitle: InhibitState.inhibited ? "Screen won't sleep" : "Normal sleep behaviour"

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: InhibitState.inhibited
                    onToggled: InhibitState.inhibited = !InhibitState.inhibited
                }
            }
        }
    }
}
