import QtQuick
import Quickshell.Services.Mpris
import "../"

Item {
    id: root

    property var screen: null

    // ── Player selection ──────────────────────────────────────────
    property var player: null

    function updatePlayer() {
        let best = null
        for (let i = 0; i < playerRep.count; i++) {
            const item = playerRep.itemAt(i)
            if (!item) continue
            if (item.modelData.isPlaying) { best = item.modelData; break }
            if (!best) best = item.modelData
        }
        player = best
    }

    Item {
        width: 0; height: 0
        Repeater {
            id: playerRep
            model: Mpris.players
            onCountChanged: root.updatePlayer()
            delegate: Item {
                required property var modelData
                width: 0; height: 0
                property bool playing: modelData.isPlaying
                onPlayingChanged: root.updatePlayer()
                Component.onCompleted: root.updatePlayer()
            }
        }
    }

    property bool isPlaying: player !== null && player.isPlaying
    property bool isPaused:  player !== null && !player.isPlaying && player.playbackState !== MprisPlaybackState.Stopped

    property string targetRow: "right"
    visible: player !== null && Theme.showMusic === targetRow

    implicitWidth: bars.width + (Theme.design === "pills" ? 20 : 0)
    implicitHeight: Theme.design === "pills" ? Theme.barHeight - 8 : 18

    // Pills background
    Rectangle {
        visible: Theme.design === "pills"
        anchors.centerIn: parent
        width: bars.width + 20
        height: root.implicitHeight
        radius: height / 2
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
    }

    // ── Animated bars ─────────────────────────────────────────────
    property real phase: 0
    property var amps: [0.5, 0.7, 0.4, 0.8, 0.55]

    Timer {
        interval: 50
        running: root.isPlaying
        repeat: true
        onTriggered: {
            root.phase += 0.15
            const p = root.phase
            root.amps = [
                0.25 + 0.65 * Math.abs(Math.sin(p * 1.30 + 0.00)),
                0.15 + 0.75 * Math.abs(Math.sin(p * 0.90 + 1.00)),
                0.30 + 0.60 * Math.abs(Math.sin(p * 1.70 + 0.50)),
                0.10 + 0.80 * Math.abs(Math.sin(p * 1.10 + 2.00)),
                0.20 + 0.70 * Math.abs(Math.sin(p * 1.50 + 1.50)),
            ]
        }
    }

    Item {
        id: bars
        anchors.centerIn: parent
        width: 5 * 3 + 4 * 2   // 23px  (5 bars × 3px + 4 gaps × 2px)
        height: root.implicitHeight

        Repeater {
            model: 5
            Rectangle {
                required property int index

                width: 3
                x: index * 5
                radius: 1
                color: Theme.teal
                anchors.bottom: parent.bottom

                property real amp: root.amps[index]

                height: {
                    const maxH = bars.height
                    const minH = 2
                    if (root.isPlaying) return Math.max(minH, maxH * 0.75 * amp)
                    if (root.isPaused)  return maxH * 0.25
                    return minH
                }
                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            }
        }
    }

    // ── Hover ─────────────────────────────────────────────────────
    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("music", popup, root.mapToItem(null, root.width / 2, 0).x, 0, root.screen)
            else
                BarHover.startHide()
        }
    }

    // ── Position tracking for popup ───────────────────────────────
    property real displayPos: 0    // seconds

    Connections {
        target: BarHover
        function onActiveModuleChanged() {
            if (BarHover.activeModule === "music" && root.player)
                root.displayPos = root.player.position
        }
    }

    onPlayerChanged: { if (player) displayPos = player.position }

    Timer {
        interval: 500
        running: root.isPlaying && BarHover.activeModule === "music"
        repeat: true
        onTriggered: root.displayPos = Math.min(root.displayPos + 0.5, root.player ? root.player.length : 0)
    }

    function fmtTime(secs) {
        const s = Math.floor(secs)
        const m = Math.floor(s / 60)
        const rem = s % 60
        return m + ":" + (rem < 10 ? "0" + rem : rem)
    }

    // ── Popup ─────────────────────────────────────────────────────
    Component {
        id: popup

        Item {
            anchors.fill: parent

            Column {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                spacing: 4

                // Track title
                Text {
                    width: parent.width
                    text: root.player ? (root.player.trackTitle || "Unknown track") : ""
                    color: Theme.teal
                    font.family: Theme.barFontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }

                // Artist
                Text {
                    width: parent.width
                    text: root.player ? (root.player.trackArtist || "") : ""
                    color: Theme.subtext
                    font.family: Theme.barFontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }

            // Progress bar + time
            Item {
                anchors { left: parent.left; right: parent.right; bottom: controlRow.top; bottomMargin: 8 }
                height: 16

                property real progress: {
                    if (!root.player || root.player.length <= 0) return 0
                    return Math.min(1, root.displayPos / root.player.length)
                }

                Rectangle {
                    id: progressTrack
                    anchors { left: parent.left; right: timeLabel.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    height: 4
                    radius: 2
                    color: Theme.border

                    Rectangle {
                        width: parent.width * parent.parent.progress
                        height: parent.height
                        radius: parent.radius
                        color: Theme.teal
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (root.player && root.player.canSeek) {
                                const newPos = (mouse.x / width) * root.player.length
                                root.player.position = newPos
                                root.displayPos = newPos
                            }
                        }
                    }
                }

                Text {
                    id: timeLabel
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: root.player && root.player.length > 0
                          ? root.fmtTime(root.displayPos) + " / " + root.fmtTime(root.player.length)
                          : ""
                    color: Theme.subtext
                    font.family: Theme.barFontFamily
                    font.pixelSize: 9
                }
            }

            // Controls
            Row {
                id: controlRow
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                spacing: 16

                Text {
                    text: "<<"
                    color: root.player && root.player.canGoPrevious ? Theme.text : Theme.border
                    font.family: Theme.barFontFamily
                    font.pixelSize: 13
                    font.bold: true
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.player && root.player.canGoPrevious
                        onClicked: root.player.previous()
                    }
                }

                Text {
                    text: root.isPlaying ? "⏸" : "▶"
                    color: Theme.teal
                    font.family: Theme.barFontFamily
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.player && root.player.canTogglePlaying
                        onClicked: root.player.togglePlaying()
                    }
                }

                Text {
                    text: ">>"
                    color: root.player && root.player.canGoNext ? Theme.text : Theme.border
                    font.family: Theme.barFontFamily
                    font.pixelSize: 13
                    font.bold: true
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.player && root.player.canGoNext
                        onClicked: root.player.next()
                    }
                }
            }
        }
    }
}
