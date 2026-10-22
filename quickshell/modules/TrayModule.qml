import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../"
import "../components"

// StatusNotifierItem tray. Left click activates the item (or opens its menu
// for menu-only items), middle click is the secondary action, right click
// opens the menu, and scrolling is forwarded to the item. Hover shows the
// item's tooltip.
Item {
    id: root
    property string targetRow: "right"
    property var screen: null

    // Ids of items without an Activate method (Steam's Ayatana indicator, …).
    // Quickshell can't tell, so ask D-Bus whenever the set of items changes.
    property var noActivate: []

    Process {
        id: noActivateProc
        command: ["sh", "-c", "$HOME/.config/quickshell/scripts/tray-no-activate.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.noActivate = this.text.split("\n").filter(s => s !== "")
        }
    }

    function refreshNoActivate() {
        if (!root.visible) return
        noActivateProc.running = false
        noActivateProc.running = true
    }

    // Items register their D-Bus interface a moment after appearing
    Timer { id: noActivateTimer; interval: 1500; onTriggered: root.refreshNoActivate() }
    onVisibleChanged: noActivateTimer.restart()
    visible: trayRepeater.count > 0 && Theme.showTray === targetRow

    implicitWidth: innerRow.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: innerRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            id: trayRepeater
            model: SystemTray.items
            onCountChanged: noActivateTimer.restart()

            delegate: Item {
                id: trayItem
                required property var modelData
                readonly property string tipTitle: modelData.tooltipTitle || modelData.title || modelData.id || ""
                readonly property string tipText: modelData.tooltipDescription || ""
                readonly property bool attention: modelData.status === Status.NeedsAttention

                width: 24
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSm
                    color: menuAnchor.visible ? Theme.selected : trayArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 90 } }
                }

                Image {
                    id: trayIcon
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    scale: trayArea.pressed ? 0.85 : 1
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    sourceSize: Qt.size(16, 16)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true

                    property int _fb: 0
                    // Tracks current icon value so we can reset _fb when it changes
                    property string iconTracker: modelData.icon

                    onIconTrackerChanged: {
                        _fb = 0
                        _trySource()
                    }

                    Component.onCompleted: _trySource()

                    function _trySource() {
                        const icon = modelData.icon || ""
                        if (!icon) { source = ""; return }
                        if (icon.startsWith("/"))       { source = "file://" + icon; return }
                        if (icon.startsWith("file://")) { source = icon; return }

                        if (!icon.startsWith("image://icon/")) { source = icon; return }

                        const bare = icon.substring("image://icon/".length)
                        const pathIdx = bare.indexOf("?path=")

                        if (pathIdx >= 0) {
                            // Tray item provided an explicit search directory
                            const name = bare.substring(0, pathIdx)
                            const rest = bare.substring(pathIdx + 6)
                            const dir  = rest.indexOf("?") >= 0 ? rest.substring(0, rest.indexOf("?")) : rest
                            if (_fb === 0) { source = "file://" + dir + "/" + name + ".png"; return }
                            if (_fb === 1) { source = "file://" + dir + "/" + name + ".svg"; return }
                            // fallback: strip ?path= and let icon provider try the name
                            source = "image://icon/" + name
                            return
                        }

                        // Named icon — probe theme dirs directly to bypass Qt's broken
                        // QIcon::fromTheme() lookup in the image://icon/ provider
                        const name = bare.indexOf("?") >= 0 ? bare.substring(0, bare.indexOf("?")) : bare
                        const candidates = [
                            // Papirus — all 16×16 contexts used for tray/status icons
                            "file:///usr/share/icons/Papirus/16x16/panel/"   + name + ".svg",
                            "file:///usr/share/icons/Papirus/16x16/status/"  + name + ".svg",
                            "file:///usr/share/icons/Papirus/16x16/apps/"    + name + ".svg",
                            "file:///usr/share/icons/Papirus/16x16/actions/" + name + ".svg",
                            "file:///usr/share/icons/Papirus/16x16/devices/" + name + ".svg",
                            "file:///usr/share/icons/Papirus/16x16/places/"  + name + ".svg",
                            // Breeze — context/size layout (covers anything Papirus misses)
                            "file:///usr/share/icons/breeze/status/16/"      + name + ".svg",
                            "file:///usr/share/icons/breeze/actions/16/"     + name + ".svg",
                            "file:///usr/share/icons/breeze/apps/16/"        + name + ".svg",
                            "file:///usr/share/icons/breeze/devices/16/"     + name + ".svg",
                            "file:///usr/share/icons/breeze/places/16/"      + name + ".svg",
                            "file:///usr/share/icons/breeze/preferences/32/" + name + ".svg",
                        ]
                        if (_fb < candidates.length) { source = candidates[_fb]; return }
                        if (_fb === candidates.length) { source = icon; return }  // image:// last resort
                        source = ""  // give up
                    }

                    onStatusChanged: {
                        if (status !== Image.Error) return
                        const icon = modelData.icon || ""
                        if (!icon.startsWith("image://icon/")) return
                        const hasPath = icon.substring("image://icon/".length).indexOf("?path=") >= 0
                        const maxFb = hasPath ? 2 : 13  // 2 explicit-path tries, or 12 dirs + 1 image:// provider
                        if (_fb < maxFb) { _fb++; _trySource() }
                    }
                }

                // Pulsing dot for items asking for attention
                Rectangle {
                    anchors { right: parent.right; top: parent.top; margins: 2 }
                    width: 6; height: 6; radius: 3
                    color: Theme.accent
                    visible: trayItem.attention
                    SequentialAnimation on opacity {
                        running: trayItem.attention
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutSine }
                    }
                }

                // The menu opens below the bar, centered on the icon
                QsMenuAnchor {
                    id: menuAnchor
                    menu: trayItem.modelData.menu
                    anchor.item: trayItem
                    anchor.rect.x: 0
                    anchor.rect.y: 0
                    anchor.rect.width: trayItem.width
                    anchor.rect.height: trayItem.height + (Theme.barHeight - trayItem.height) / 2 + 6
                    anchor.edges: Edges.Bottom
                    anchor.gravity: Edges.Bottom
                }

                function openMenu() {
                    BarHover.startHide()
                    if (menuAnchor.visible) menuAnchor.close()
                    else menuAnchor.open()
                }

                MouseArea {
                    id: trayArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onContainsMouseChanged: {
                        if (containsMouse && trayItem.tipTitle !== "" && !menuAnchor.visible)
                            BarHover.show("tray", tooltip, trayItem.mapToItem(null, trayItem.width / 2, 0).x, root.screen)
                        else if (!containsMouse)
                            BarHover.startHide()
                    }

                    onClicked: mouse => {
                        const item = trayItem.modelData
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate()
                        } else if (mouse.button === Qt.RightButton) {
                            if (item.hasMenu) trayItem.openMenu()
                            else item.activate()
                        } else if (item.hasMenu && (item.onlyMenu || root.noActivate.indexOf(item.id) >= 0)) {
                            trayItem.openMenu()
                        } else {
                            item.activate()
                        }
                    }

                    onWheel: wheel => {
                        const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                        trayItem.modelData.scroll(horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal)
                    }
                }

                Component {
                    id: tooltip

                    Column {
                        width: parent ? parent.width : 0
                        spacing: 4

                        Label {
                            width: parent.width
                            text: trayItem.tipTitle
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            visible: text !== ""
                            text: trayItem.tipText
                            textFormat: Text.StyledText
                            color: Theme.subtext
                            font.pixelSize: Theme.textSm
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
