import QtQuick
import "../"

BarText {
    id: root

    property string timeStr: Qt.formatTime(new Date(), "hh:mm")
    property string dateStr: Qt.formatDate(new Date(), "dddd, MMMM d")

    text: timeStr
    moduleId: "clock"
    modulePopup: popup

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.timeStr = Qt.formatTime(new Date(), "hh:mm")
            root.dateStr = Qt.formatDate(new Date(), "dddd, MMMM d")
        }
    }

    Component {
        id: popup
        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.timeStr
                color: Theme.blue
                font.family: Theme.barFontFamily
                font.pixelSize: 22
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateStr
                color: Theme.subtext
                font.family: Theme.barFontFamily
                font.pixelSize: 12
            }
        }
    }
}
