import QtQuick
import Quickshell.Services.Mpris
import "../"
import "../components"

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

    implicitWidth: bars.width
    implicitHeight: Theme.barHeight

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
        height: 14

        Repeater {
            model: 5
            Rectangle {
                required property int index

                width: 3
                x: index * 5
                radius: 1.5
                color: root.isPlaying ? Theme.text : Theme.subtext
                anchors.verticalCenter: parent.verticalCenter

                property real amp: root.amps[index]

                height: {
                    const maxH = bars.height
                    const minH = 2
                    if (root.isPlaying) return Math.max(minH, maxH * amp)
                    if (root.isPaused)  return 3
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
                BarHover.show("music", popup, root.mapToItem(null, root.width / 2, 0).x, root.screen)
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

        Column {
            width: parent ? parent.width : 0
            spacing: 14

            Row {
                width: parent.width
                spacing: 12

                Rectangle {
                    id: art
                    width: 56; height: 56
                    radius: Theme.radiusMd
                    color: Theme.hover
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player ? (root.player.trackArtUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        visible: status === Image.Ready
                    }
                }

                Column {
                    width: parent.width - art.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Label {
                        width: parent.width
                        text: root.player ? (root.player.trackTitle || "Unknown track") : ""
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Label {
                        width: parent.width
                        text: root.player ? (root.player.trackArtist || root.player.identity || "") : ""
                        color: Theme.subtext
                        font.pixelSize: Theme.textSm
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6

                property real progress: {
                    if (!root.player || root.player.length <= 0) return 0
                    return Math.min(1, root.displayPos / root.player.length)
                }

                Slider {
                    width: parent.width
                    value: parent.progress
                    onMoved: v => {
                        if (root.player && root.player.canSeek) {
                            const newPos = v * root.player.length
                            root.player.position = newPos
                            root.displayPos = newPos
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 14
                    visible: root.player && root.player.length > 0

                    Label {
                        anchors.left: parent.left
                        text: root.fmtTime(root.displayPos)
                        color: Theme.subtext
                        font.pixelSize: Theme.textXs
                    }
                    Label {
                        anchors.right: parent.right
                        text: root.player ? root.fmtTime(root.player.length) : ""
                        color: Theme.subtext
                        font.pixelSize: Theme.textXs
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "previous"
                    size: 22
                    color: root.player && root.player.canGoPrevious ? Theme.text : Theme.track
                    TapHandler {
                        enabled: root.player && root.player.canGoPrevious
                        onTapped: root.player.previous()
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: Theme.text

                    Icon {
                        anchors.centerIn: parent
                        name: root.isPlaying ? "pause" : "play"
                        size: 22
                        color: Theme.base
                    }
                    TapHandler {
                        enabled: root.player && root.player.canTogglePlaying
                        onTapped: root.player.togglePlaying()
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "next"
                    size: 22
                    color: root.player && root.player.canGoNext ? Theme.text : Theme.track
                    TapHandler {
                        enabled: root.player && root.player.canGoNext
                        onTapped: root.player.next()
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}
