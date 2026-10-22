import QtQuick
import "../"
import "../components"

BarText {
    id: root

    property date now: new Date()

    text: Qt.formatTime(now, "hh:mm")
    rolling: true
    moduleId: "clock"
    modulePopup: popup

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Component {
        id: popup

        Column {
            id: cal
            width: parent ? parent.width : 0
            spacing: 14

            readonly property int year: root.now.getFullYear()
            readonly property int month: root.now.getMonth()
            // Monday-first offset of the 1st of the month.
            readonly property int lead: (new Date(year, month, 1).getDay() + 6) % 7
            readonly property int days: new Date(year, month + 1, 0).getDate()

            PopupHeader {
                title: Qt.formatDate(root.now, "dddd")
                subtitle: Qt.formatDate(root.now, "d MMMM yyyy")

                RollingText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(root.now, "hh:mm")
                    font.pixelSize: Theme.textMd
                    font.weight: Font.Medium
                }
            }

            Grid {
                id: grid
                columns: 7
                width: parent.width
                readonly property real cell: width / 7

                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Label {
                        required property string modelData
                        width: grid.cell
                        height: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.subtext
                        font.pixelSize: Theme.textXs
                        font.weight: Font.DemiBold
                    }
                }

                Repeater {
                    model: cal.lead + cal.days
                    Item {
                        required property int index
                        readonly property int day: index - cal.lead + 1
                        readonly property bool today: day === root.now.getDate()
                        width: grid.cell
                        height: 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: 26; height: 26; radius: 13
                            visible: parent.today
                            color: Theme.accent
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: parent.day > 0
                            text: parent.day
                            color: parent.today ? Theme.base : Theme.text
                            font.pixelSize: Theme.textSm
                            font.weight: parent.today ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }
    }
}
