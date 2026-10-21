import QtQuick
import "../"
import "../components"

// Compact "name … value" list of the heaviest processes.
Column {
    id: root

    property var processes: []
    property string unit: "%"
    property string sectionLabel: "Top processes"

    spacing: 6

    SectionLabel {
        text: root.sectionLabel
        bottomPadding: 2
    }

    Repeater {
        model: root.processes
        Item {
            required property var modelData
            width: root.width
            height: 18

            Label {
                anchors { left: parent.left; right: valText.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: modelData.name
                font.pixelSize: Theme.textSm
                elide: Text.ElideRight
            }
            Label {
                id: valText
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: modelData.value + root.unit
                color: Theme.subtext
                font.pixelSize: Theme.textSm
            }
        }
    }
}
