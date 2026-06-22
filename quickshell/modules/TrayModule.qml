import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../"

Item {
    id: root
    property string targetRow: "right"
    visible: trayRepeater.count > 0 && Theme.showTray === targetRow

    implicitWidth: innerRow.implicitWidth + (Theme.design === "pills" ? 20 : 0)
    implicitHeight: Theme.design === "pills" ? Theme.barHeight - 8 : innerRow.implicitHeight

    Rectangle {
        visible: Theme.design === "pills"
        anchors.centerIn: parent
        width: innerRow.implicitWidth + 20
        height: root.implicitHeight
        radius: height / 2
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
    }

    Row {
        id: innerRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            delegate: Item {
                required property var modelData
                width: 16
                height: 16

                Image {
                    id: trayIcon
                    anchors.fill: parent
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

                QsMenuAnchor {
                    id: menuAnchor
                    anchor.item: parent
                    menu: modelData.menu
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                            menuAnchor.open()
                        } else {
                            modelData.activate()
                        }
                    }
                }
            }
        }
    }
}
