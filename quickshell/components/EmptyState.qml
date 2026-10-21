import QtQuick
import "../"

// Centered placeholder shown when a list has nothing in it.
Column {
    property string icon: ""
    property string text: ""

    spacing: 10

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: parent.icon !== ""
        name: parent.icon
        size: 28
        color: Theme.alpha(Theme.subtext, 0.6)
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        text: parent.text
        color: Theme.subtext
        font.pixelSize: Theme.textSm
    }
}
