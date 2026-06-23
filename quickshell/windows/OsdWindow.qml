import Quickshell
import QtQuick
import "../"

Item {
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: osdPanel
                required property var modelData
                screen: modelData

                anchors { bottom: true; left: true; right: true }
                exclusiveZone: 0
                implicitHeight: osdCard.height + 80

                color: "transparent"
                mask: Region {}

                property color accent: OsdState.type === "volume" ? Theme.yellow : Theme.blue

                Rectangle {
                    id: osdCard
                    width: 240
                    height: 64
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                    }

                    color: Theme.surface
                    radius: 8
                    border.color: Theme.border
                    border.width: 1

                    opacity: OsdState.active ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Item {
                        id: labelRow
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            topMargin: 14
                            leftMargin: 16
                            rightMargin: 16
                        }
                        height: typeText.implicitHeight

                        Text {
                            id: typeText
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: OsdState.type === "volume"
                                  ? (OsdState.muted ? "muted" : "volume")
                                  : "brightness"
                            color: OsdState.muted ? Theme.subtext : osdPanel.accent
                            font.family: Theme.barFontFamily
                            font.pixelSize: Theme.barFontSize
                        }

                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            visible: !OsdState.muted
                            text: Math.round(OsdState.value * 100) + "%"
                            color: osdPanel.accent
                            font.family: Theme.barFontFamily
                            font.pixelSize: Theme.barFontSize
                            font.bold: true
                        }
                    }

                    Rectangle {
                        anchors {
                            top: labelRow.bottom
                            left: parent.left
                            right: parent.right
                            topMargin: 10
                            leftMargin: 16
                            rightMargin: 16
                        }
                        height: 5
                        radius: 2
                        color: Theme.border

                        Rectangle {
                            width: {
                                if (OsdState.muted) return 0
                                if (OsdState.type === "volume")
                                    return parent.width * Math.min(1, OsdState.value / 1.5)
                                return parent.width * OsdState.value
                            }
                            height: parent.height
                            radius: parent.radius
                            color: OsdState.muted ? Theme.subtext
                                 : (OsdState.type === "volume" && OsdState.value > 1.0)
                                    ? Theme.red
                                    : osdPanel.accent
                            Behavior on width {
                                NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}
