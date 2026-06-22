import QtQuick
import "../"

Column {
    id: root

    property var processes: []
    property color accentColor: Theme.blue
    property string unit: "%"
    property string sectionLabel: "top processes"

    spacing: 3

    Rectangle { width: root.width; height: 1; color: Theme.border; opacity: 0.5 }

    Text {
        text: root.sectionLabel
        color: Theme.subtext
        font.family: Theme.barFontFamily
        font.pixelSize: 10
    }

    Repeater {
        model: root.processes
        Row {
            required property var modelData
            width: root.width
            Text {
                width: root.width - valText.width
                text: modelData.name
                color: Theme.text
                font.family: Theme.barFontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                id: valText
                text: modelData.value + root.unit
                color: root.accentColor
                font.family: Theme.barFontFamily
                font.pixelSize: 11
            }
        }
    }
}
