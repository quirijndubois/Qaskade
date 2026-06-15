import QtQuick
import Quickshell.Services.UPower
import "../"

BarText {
    id: root
    color: Theme.green

    property var screen: null
    property var device: UPower.displayDevice

    function getBatteryPct(dev) {
        if (!dev || !dev.isPresent) return -1
        const raw = dev.percentage
        // quickshell exposes percentage as 0.0–1.0
        if (raw > 0 && raw <= 1) return Math.round(raw * 100)
        if (raw > 1) return Math.round(raw)
        // fallback: calculate from energy properties
        if (dev.energyCapacity > 0) return Math.round((dev.energy / dev.energyCapacity) * 100)
        return 0
    }

    text: {
        const pct = getBatteryPct(device)
        if (pct < 0) return "bat --%"
        const state = device.state
        const prefix = state === UPowerDeviceState.Charging ? "+" :
                       (state === UPowerDeviceState.FullyCharged || state === UPowerDeviceState.PendingCharge) ? "=" : ""
        return "bat " + prefix + pct + "%"
    }

    property string timeText: {
        if (!device || !device.isPresent) return ""
        const s = device.state
        if (s === UPowerDeviceState.Charging) {
            const secs = device.timeToFull
            if (secs <= 0 || secs > 86400) return "charging"
            const h = Math.floor(secs / 3600)
            const m = Math.floor((secs % 3600) / 60)
            return h > 0 ? h + "h " + m + "m to full" : m + "m to full"
        }
        const secs = device.timeToEmpty
        if (secs <= 0 || secs > 86400) return ""
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        return h > 0 ? h + "h " + m + "m left" : m + "m left"
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("battery", popup, root.mapToItem(null, root.width / 2, 0).x, 0, root.screen)
            else
                BarHover.startHide()
        }
    }

    Component {
        id: popup
        Column {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8

            Row {
                spacing: 8
                Text {
                    text: {
                        const pct = root.getBatteryPct(root.device)
                        return pct < 0 ? "--%" : pct + "%"
                    }
                    color: Theme.green
                    font.family: Theme.barFontFamily
                    font.pixelSize: 20
                    font.bold: true
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    text: {
                        if (!root.device || !root.device.isPresent) return ""
                        const s = root.device.state
                        return s === UPowerDeviceState.Charging ? "charging" :
                               (s === UPowerDeviceState.FullyCharged || s === UPowerDeviceState.PendingCharge) ? "full" : "discharging"
                    }
                    color: Theme.subtext
                    font.family: Theme.barFontFamily
                    font.pixelSize: 11
                }
            }

            Rectangle {
                width: parent.width
                height: 5
                radius: 2
                color: Theme.border

                Rectangle {
                    property int pct: root.getBatteryPct(root.device)
                    width: pct < 0 ? 0 : parent.parent.width * Math.min(1, pct / 100)
                    height: parent.height
                    radius: parent.radius
                    color: pct < 20 ? Theme.red : pct < 40 ? Theme.yellow : Theme.green
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
            }

            Text {
                text: root.timeText
                color: Theme.subtext
                font.family: Theme.barFontFamily
                font.pixelSize: 11
                visible: root.timeText !== ""
            }
        }
    }
}
