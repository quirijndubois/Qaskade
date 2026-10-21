import QtQuick
import Quickshell.Services.UPower
import "../"
import "../components"

// Drawn battery glyph whose fill tracks the charge level.
Item {
    id: root

    property var screen: null
    property var device: UPower.displayDevice

    readonly property int pct: {
        const dev = device
        if (!dev || !dev.isPresent) return -1
        const raw = dev.percentage
        // quickshell exposes percentage as 0.0–1.0
        if (raw > 0 && raw <= 1) return Math.round(raw * 100)
        if (raw > 1) return Math.round(raw)
        if (dev.energyCapacity > 0) return Math.round((dev.energy / dev.energyCapacity) * 100)
        return 0
    }
    readonly property bool present: pct >= 0
    readonly property bool charging: device && device.state === UPowerDeviceState.Charging
    readonly property bool full: device && (device.state === UPowerDeviceState.FullyCharged
                                         || device.state === UPowerDeviceState.PendingCharge)

    readonly property color fillColor: charging ? Theme.green
                                     : pct >= 0 && pct <= 15 ? Theme.red
                                     : Theme.text

    readonly property string stateText: {
        if (pct < 0) return "No battery"
        if (charging) return "Charging"
        if (full) return "Fully charged"
        return "On battery"
    }

    readonly property string timeText: {
        if (!device || !device.isPresent) return ""
        const secs = charging ? device.timeToFull : device.timeToEmpty
        if (secs <= 0 || secs > 86400) return ""
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        const t = h > 0 ? h + " h " + m + " min" : m + " min"
        return charging ? t + " until full" : t + " remaining"
    }

    implicitWidth: body.width + 3
    implicitHeight: Theme.barHeight

    Rectangle {
        id: body
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 12
        radius: 3.5
        color: "transparent"
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.4)

        Rectangle {
            x: 2; y: 2
            height: parent.height - 4
            width: Math.max(2, (parent.width - 4) * Math.max(0, root.pct) / 100)
            radius: 2
            color: root.fillColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    // Terminal nub
    Rectangle {
        anchors { left: body.right; leftMargin: 1; verticalCenter: body.verticalCenter }
        width: 2; height: 4
        radius: 1
        color: Theme.alpha(Theme.text, 0.4)
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("battery", popup, root.mapToItem(null, root.width / 2, 0).x, root.screen)
            else
                BarHover.startHide()
        }
    }

    Component {
        id: popup
        Column {
            width: parent ? parent.width : 0
            spacing: 12

            PopupHeader {
                title: "Battery"
                subtitle: root.timeText !== "" ? root.timeText : root.stateText
                detail: root.pct < 0 ? "—" : root.pct + "%"
            }

            Meter {
                width: parent.width
                value: Math.max(0, root.pct)
                fillColor: root.charging ? Theme.green : Theme.text
                critAt: 15
                invertThresholds: true
            }
        }
    }
}
