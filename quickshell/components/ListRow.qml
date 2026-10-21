import QtQuick
import "../"

// One row in a settings list. Selection is a soft inset highlight; anything
// declared inside the row lands in the trailing slot on the right.
Item {
    id: root

    property bool selected: false
    property string icon: ""
    property color iconColor: Theme.subtext
    property string label: ""
    property string sublabel: ""
    property color labelColor: Theme.text
    property bool chevron: false
    property bool mono: false
    // Replaces the icon with custom content (thumbnail, swatch, …).
    property Component leading: null
    default property alias trailing: trailingRow.data

    signal clicked()

    width: ListView.view ? ListView.view.width : (parent ? parent.width : 0)
    height: sublabel !== "" ? 56 : 44

    Rectangle {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 1; bottomMargin: 1 }
        radius: Theme.radiusMd
        color: root.selected ? Theme.selected : mouse.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    Loader {
        id: leadingSlot
        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
        sourceComponent: root.leading ? root.leading : root.icon !== "" ? iconComp : null
        width: item ? item.width : 0
    }

    Component {
        id: iconComp
        Icon {
            name: root.icon
            size: 18
            color: root.selected ? Theme.text : root.iconColor
        }
    }

    Column {
        anchors {
            left: leadingSlot.right; leftMargin: leadingSlot.width > 0 ? 14 : 0
            right: trailingRow.left; rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Label {
            width: parent.width
            text: root.label
            color: root.labelColor
            font.family: root.mono ? Theme.monoFamily : Theme.fontFamily
            font.pixelSize: root.mono ? Theme.textSm : Theme.textMd
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            visible: root.sublabel !== ""
            text: root.sublabel
            color: Theme.subtext
            font.pixelSize: Theme.textSm
            elide: Text.ElideRight
        }
    }

    Row {
        id: trailingRow
        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
        spacing: 10

        Icon {
            visible: root.chevron
            anchors.verticalCenter: parent.verticalCenter
            name: "chevronRight"
            size: 16
            color: Theme.subtext
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
