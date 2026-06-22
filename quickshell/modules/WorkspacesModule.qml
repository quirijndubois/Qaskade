import QtQuick
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../"

Item {
    id: root
    implicitWidth: row.implicitWidth + 8
    implicitHeight: row.implicitHeight
    property var screen: null
    property var monitor: null
    property int highlightX: -24

    Row {
        id: row
        x: 4
        spacing: 4
        leftPadding: 0
        rightPadding: 0

        Repeater {
            id: rep
            model: Hyprland.workspaces

            delegate: Item {
                required property var modelData
                required property int index
                width: 24
                height: Theme.barFontSize + 8

                visible: !root.monitor || modelData.monitor === root.monitor

                property bool isFocused: modelData.focused

                function updateHighlightPosition() {
                    if (!visible) return
                    root.highlightX = row.x + x
                }

                onIsFocusedChanged: {
                    if (isFocused && visible) {
                        Qt.callLater(() => updateHighlightPosition())
                    }
                }

                Component.onCompleted: {
                    if (modelData.focused && visible) {
                        Qt.callLater(() => updateHighlightPosition())
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.name
                    color: modelData.focused ? Theme.text : Theme.subtext
                    font.family: Theme.barFontFamily
                    font.bold: modelData.focused || Theme.barFontBold
                    font.pixelSize: Theme.barFontSize
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: modelData.activate()
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    Rectangle {
        id: highlight
        width: 24
        height: Theme.barFontSize + 8
        y: 0
        radius: 3
        color: Theme.blue
        opacity: 0.35
        x: root.highlightX

        Behavior on x {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                const count = Math.min(Notifications.history.length, 5)
                const h = count === 0 ? 64 : 44 + count * 50 + 22
                BarHover.show("workspaces", notifPopup, root.mapToItem(null, root.width / 2, 0).x, h, root.screen)
            } else {
                BarHover.startHide()
            }
        }
    }

    Component {
        id: notifPopup
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 6

            Item {
                width: parent.width
                height: 16

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "notifications"
                    color: Theme.purple
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: Notifications.history.length > 0
                        ? Notifications.history.length + " total" : ""
                    color: Theme.subtext
                    font.family: Theme.barFontFamily
                    font.pixelSize: 10
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.5 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Notifications.history.length === 0
                text: "no notifications"
                color: Theme.subtext
                font.family: Theme.barFontFamily
                font.pixelSize: 11
            }

            Column {
                visible: Notifications.history.length > 0
                width: parent.width
                spacing: 4

                Repeater {
                    id: popupNotifRep
                    model: Notifications.history

                    delegate: Rectangle {
                        id: popupNotifItem
                        required property var modelData
                        required property int index

                        visible: index >= Notifications.history.length - 5
                        width: parent.width
                        height: notifItemCol.implicitHeight + 12
                        radius: 4
                        color: Theme.base

                        property bool _isClearAll: false

                        function dismiss() {
                            if (!popupExitAnim.running) {
                                _isClearAll = false
                                popupExitAnim.start()
                            }
                        }

                        function animateOut(delay) {
                            _isClearAll = true
                            popupExitDelayTimer.interval = Math.max(1, delay)
                            popupExitDelayTimer.restart()
                        }

                        Timer {
                            id: popupExitDelayTimer
                            onTriggered: popupExitAnim.start()
                        }

                        SequentialAnimation {
                            id: popupExitAnim
                            ParallelAnimation {
                                NumberAnimation { target: popupNotifItem; property: "x"; to: 160; duration: 180; easing.type: Easing.InCubic }
                                NumberAnimation { target: popupNotifItem; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
                            }
                            ScriptAction { script: { if (!popupNotifItem._isClearAll) Notifications.dismiss(popupNotifItem.modelData.id) } }
                        }

                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 2; radius: 1
                            color: modelData.urgency === NotificationUrgency.Critical ? Theme.red
                                 : modelData.urgency === NotificationUrgency.Low      ? Theme.subtext
                                 : Theme.blue
                        }

                        Column {
                            id: notifItemCol
                            anchors {
                                left: parent.left; leftMargin: 8
                                right: popupDismiss.left; rightMargin: 4
                                top: parent.top; topMargin: 6
                            }
                            spacing: 2

                            Text {
                                width: parent.width
                                text: modelData.appName || ""
                                color: modelData.urgency === NotificationUrgency.Critical ? Theme.red
                                     : modelData.urgency === NotificationUrgency.Low      ? Theme.subtext
                                     : Theme.blue
                                font.family: Theme.barFontFamily
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: modelData.summary || ""
                                color: Theme.text
                                font.family: Theme.barFontFamily
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            id: popupDismiss
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: "×"
                            color: Theme.subtext
                            font.family: Theme.barFontFamily
                            font.pixelSize: 12
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popupNotifItem.dismiss()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Notifications.history.length > 0
                text: "clear all"
                color: Theme.red
                font.family: Theme.barFontFamily
                font.pixelSize: 10
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const count = popupNotifRep.count
                        for (let i = 0; i < count; i++) {
                            const item = popupNotifRep.itemAt(i)
                            if (item && item.visible) item.animateOut((count - 1 - i) * 50)
                        }
                        Qt.callLater(() => {
                            popupClearTimer.interval = count * 50 + 220
                            popupClearTimer.restart()
                        })
                    }
                }
            }

            Timer {
                id: popupClearTimer
                onTriggered: Notifications.clearAll()
            }
        }
    }
}
