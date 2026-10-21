import QtQuick
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../"
import "../components"

// Workspace dots: the focused workspace stretches into a pill.
// Hovering shows the notification history.
Item {
    id: root

    property var screen: null
    property var monitor: null

    readonly property int dot: 6

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Repeater {
            model: Hyprland.workspaces

            delegate: Item {
                id: ws
                required property var modelData

                // Hide special workspaces and those that live on another monitor.
                visible: modelData.id > 0 && (!root.monitor || modelData.monitor === root.monitor)
                width: pill.width
                height: Theme.barHeight

                Rectangle {
                    id: pill
                    anchors.verticalCenter: parent.verticalCenter
                    width: ws.modelData.focused ? root.dot * 3 : root.dot
                    height: root.dot
                    radius: height / 2
                    color: ws.modelData.focused ? Theme.accent
                         : hover.hovered ? Theme.text
                         : Theme.alpha(Theme.text, 0.35)
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

                MouseArea {
                    anchors { fill: parent; leftMargin: -2; rightMargin: -2 }
                    onClicked: ws.modelData.activate()
                }
            }
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("workspaces", notifPopup, root.mapToItem(null, root.width / 2, 0).x, root.screen)
            else
                BarHover.startHide()
        }
    }

    Component {
        id: notifPopup

        Column {
            width: parent ? parent.width : 0
            spacing: 12

            PopupHeader {
                title: "Notifications"
                subtitle: Notifications.history.length === 0 ? "You're all caught up"
                        : Notifications.history.length + (Notifications.history.length === 1 ? " notification" : " notifications")

                Label {
                    visible: Notifications.history.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear"
                    color: clearHover.hovered ? Theme.text : Theme.subtext
                    font.pixelSize: Theme.textSm
                    font.weight: Font.Medium

                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            const count = popupNotifRep.count
                            for (let i = 0; i < count; i++) {
                                const item = popupNotifRep.itemAt(i)
                                if (item && item.visible) item.animateOut((count - 1 - i) * 50)
                            }
                            popupClearTimer.interval = count * 50 + 220
                            popupClearTimer.restart()
                        }
                    }
                }
            }

            Column {
                visible: Notifications.history.length > 0
                width: parent.width
                spacing: 6

                Repeater {
                    id: popupNotifRep
                    model: Notifications.history

                    delegate: Rectangle {
                        id: popupNotifItem
                        required property var modelData
                        required property int index

                        // Newest five, newest first is handled by the list order.
                        visible: index >= Notifications.history.length - 5
                        width: parent.width
                        height: notifItemCol.implicitHeight + 20
                        radius: Theme.radiusMd
                        color: Theme.hover

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

                        Column {
                            id: notifItemCol
                            anchors {
                                left: parent.left; leftMargin: 12
                                right: popupDismiss.left; rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 2

                            Row {
                                spacing: 6
                                Rectangle {
                                    visible: modelData.urgency === NotificationUrgency.Critical
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 6; height: 6; radius: 3
                                    color: Theme.red
                                }
                                Label {
                                    text: modelData.appName || "Notification"
                                    color: Theme.subtext
                                    font.pixelSize: Theme.textXs
                                    font.weight: Font.Medium
                                }
                            }

                            Label {
                                width: parent.width
                                visible: text !== ""
                                text: modelData.summary || ""
                                font.pixelSize: Theme.textSm
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Label {
                                width: parent.width
                                visible: text !== ""
                                text: modelData.body || ""
                                color: Theme.subtext
                                font.pixelSize: Theme.textSm
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                        }

                        Icon {
                            id: popupDismiss
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            name: "close"
                            size: 14
                            color: dismissHover.hovered ? Theme.text : Theme.subtext
                            HoverHandler { id: dismissHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: popupNotifItem.dismiss() }
                        }
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
