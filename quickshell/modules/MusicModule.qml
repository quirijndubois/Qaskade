import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Widgets
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
    // Cover art on the left; title, artist, album and player, a thin
    // progress line and the transport controls on the right. The card is
    // washed with a blurred copy of the cover.
    Component {
        id: popup

        Item {
            id: card
            readonly property int popupWidth: 372
            readonly property string artUrl: root.player ? (root.player.trackArtUrl || "") : ""
            readonly property real progress: root.player && root.player.length > 0
                                             ? Math.min(1, root.displayPos / root.player.length) : 0

            width: parent ? parent.width : 0
            implicitHeight: info.implicitHeight

            // ── Cover wash ─────────────────────────────────────────
            // Extends under the card's padding, inset 1px inside its border,
            // and is clipped to the card's rounded shape. The blurred image is
            // oversized so its soft, fading edges fall outside the clip.
            ClippingRectangle {
                id: wash
                x: -16 + 1; y: -16 + 1
                width: card.width + 32 - 2
                height: card.height + 32 - 2
                radius: Theme.radiusLg - 1
                color: "transparent"
                visible: coverSrc.status === Image.Ready

                Image {
                    id: coverSrc
                    anchors { fill: parent; margins: -48 }
                    source: card.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: coverSrc
                    source: coverSrc
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    saturation: 0.2
                    opacity: 0.35
                }
            }

            // ── Cover ──────────────────────────────────────────────
            ClippingRectangle {
                id: art
                width: info.implicitHeight
                height: width
                radius: Theme.radiusMd
                color: Theme.selected

                Icon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    name: "music"
                    size: 32
                    color: Theme.subtext
                }

                Image {
                    id: cover
                    anchors.fill: parent
                    source: card.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready
                }
            }

            // ── Info + controls ────────────────────────────────────
            Column {
                id: info
                anchors { left: art.right; leftMargin: 14; right: parent.right }
                spacing: 10

                Column {
                    width: parent.width
                    spacing: 1

                    Label {
                        width: parent.width
                        text: root.player ? (root.player.trackTitle || "Unknown track") : ""
                        font.pixelSize: Theme.textLg
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: root.player ? (root.player.trackArtist || "") : ""
                        color: Theme.alpha(Theme.text, 0.75)
                        font.pixelSize: Theme.textSm
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: root.player ? (root.player.trackAlbum || "") : ""
                        color: Theme.subtext
                        font.pixelSize: Theme.textXs
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: root.player ? (root.player.identity || "") : ""
                        color: Theme.alpha(Theme.subtext, 0.7)
                        font.pixelSize: Theme.textXs
                        elide: Text.ElideRight
                    }
                }

                // Progress: a thin line that thickens while hovered or dragged
                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.player && root.player.length > 0

                    Item {
                        width: parent.width
                        height: 10

                        Rectangle {
                            id: progTrack
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            height: seek.containsMouse || seek.pressed ? 6 : 3
                            radius: height / 2
                            color: Theme.alpha(Theme.text, 0.18)
                            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                            Rectangle {
                                width: Math.max(parent.height, parent.width * card.progress)
                                height: parent.height
                                radius: parent.radius
                                color: Theme.text
                            }
                        }

                        MouseArea {
                            id: seek
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            enabled: root.player && root.player.canSeek
                            cursorShape: Qt.PointingHandCursor
                            function seekTo(x) {
                                const pos = Math.max(0, Math.min(1, x / width)) * root.player.length
                                root.player.position = pos
                                root.displayPos = pos
                            }
                            onPressed: mouse => seekTo(mouse.x)
                            onPositionChanged: mouse => { if (pressed) seekTo(mouse.x) }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 12

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
                    spacing: 18

                    Repeater {
                        model: [
                            { icon: "previous", big: false },
                            { icon: "play",     big: true  },
                            { icon: "next",     big: false },
                        ]

                        Rectangle {
                            id: btn
                            required property var modelData
                            readonly property bool enabledNow: !root.player ? false
                                : modelData.icon === "previous" ? root.player.canGoPrevious
                                : modelData.icon === "next"     ? root.player.canGoNext
                                : root.player.canTogglePlaying

                            anchors.verticalCenter: parent.verticalCenter
                            width: modelData.big ? 38 : 30
                            height: width
                            radius: width / 2
                            color: modelData.big ? Theme.alpha(Theme.text, btnHover.hovered ? 0.2 : 0.12)
                                                 : (btnHover.hovered ? Theme.selected : "transparent")
                            scale: btnTap.pressed ? 0.9 : 1
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Icon {
                                anchors.centerIn: parent
                                name: btn.modelData.big ? (root.isPlaying ? "pause" : "play") : btn.modelData.icon
                                size: btn.modelData.big ? 20 : 18
                                color: btn.enabledNow ? Theme.text : Theme.track
                            }

                            HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                id: btnTap
                                enabled: btn.enabledNow
                                onTapped: {
                                    if (btn.modelData.icon === "previous") root.player.previous()
                                    else if (btn.modelData.icon === "next") root.player.next()
                                    else root.player.togglePlaying()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
