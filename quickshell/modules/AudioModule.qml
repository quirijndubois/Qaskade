import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../"
import "../components"

// Volume glyph. Scroll to change volume, right-click for pavucontrol.
BarText {
    id: root

    moduleId: "audio"
    modulePopup: popup

    // ── Sink data ─────────────────────────────────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    property var sink: Pipewire.defaultAudioSink
    property var appStreams: []
    property bool streamUpdatePending: false

    readonly property bool isMuted: !!(sink && sink.audio && sink.audio.muted)
    readonly property real volLevel: sink && sink.audio ? sink.audio.volume : 0

    icon: isMuted || volLevel === 0 ? "volumeMute"
        : volLevel < 0.33 ? "volumeLow"
        : volLevel < 0.66 ? "volumeMedium"
        : "volumeHigh"
    iconColor: isMuted ? Theme.subtext : Theme.text

    // ── Live output level ─────────────────────────────────────────
    // Max channel peak mapped from -6..0 dBFS onto 0..1.
    function peakToLevel(peaks, gain) {
        if (!peaks || peaks.length === 0) return 0
        let m = 0
        for (let i = 0; i < peaks.length; i++) if (peaks[i] > m) m = peaks[i]
        const v = Math.min(1.0, m * gain)
        if (v < 1e-5) return 0
        return Math.max(0, Math.min(1, (20 * Math.log10(v) + 6) / 6))
    }

    PwNodePeakMonitor {
        id: sinkPeakMon
        node: root.sink
        enabled: root.sink !== null && !root.isMuted
    }

    readonly property real peakLevel: isMuted ? 0 : peakToLevel(sinkPeakMon.peaks, 1.0)

    // Three bars of increasing height and decay, like sound-wave arcs.
    trailing: Item {
        width: 10
        height: Theme.barFontSize + 2

        Repeater {
            model: [
                { frac: 0.38, dur: 80  },
                { frac: 0.65, dur: 170 },
                { frac: 1.00, dur: 300 }
            ]
            Rectangle {
                required property var modelData
                required property int index

                x: index * 4
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: Math.max(2, parent.height * Math.min(1, root.peakLevel * root.volLevel) * modelData.frac)
                radius: 1
                color: root.isMuted ? Theme.subtext : root.peakLevel > 0.9 ? Theme.red : Theme.text
                Behavior on height { NumberAnimation { duration: modelData.dur; easing.type: Easing.OutCubic } }
            }
        }
    }

    Item {
        width: 0; height: 0
        Repeater {
            id: nodeRep
            model: Pipewire.nodes
            delegate: Item {
                required property var modelData
                width: 0; height: 0
                Component.onCompleted:  root.scheduleUpdateStreams()
                Component.onDestruction: root.scheduleUpdateStreams()
            }
        }
    }

    PwObjectTracker { objects: root.appStreams }

    function scheduleUpdateStreams() {
        if (root.streamUpdatePending) return
        root.streamUpdatePending = true
        Qt.callLater(function() {
            root.streamUpdatePending = false
            root.updateStreams()
        })
    }

    function updateStreams() {
        const streams = []
        for (let i = 0; i < nodeRep.count; i++) {
            const item = nodeRep.itemAt(i)
            if (!item) continue
            const node = item.modelData
            if (node && node.type === PwNodeType.AudioOutStream)
                streams.push(node)
        }
        appStreams = streams
    }

    function setVolume(v) {
        if (sink && sink.audio) sink.audio.volume = Math.max(0, Math.min(1.5, v))
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) pavuProc.running = true
            else if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
        }
        onWheel: wheel => root.setVolume(root.volLevel + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }

    Process {
        id: pavuProc
        command: ["pavucontrol"]
    }

    // ── Popup ─────────────────────────────────────────────────────
    Component {
        id: popup
        Column {
            width: parent ? parent.width : 0
            spacing: 12

            PopupHeader {
                title: "Sound"
                subtitle: root.sink ? (root.sink.description || root.sink.name || "") : "No output"
                detail: root.isMuted ? "Muted" : Math.round(root.volLevel * 100) + "%"
                detailColor: root.isMuted ? Theme.subtext : root.volLevel > 1.0 ? Theme.red : Theme.text
            }

            Row {
                width: parent.width
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.icon
                    size: 16
                    color: muteHover.hovered ? Theme.text : Theme.subtext
                    HoverHandler { id: muteHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted } }
                }

                // 0–150 % mapped onto the full track width.
                Slider {
                    width: parent.width - 26
                    anchors.verticalCenter: parent.verticalCenter
                    value: root.volLevel / 1.5
                    fillColor: root.volLevel > 1.0 ? Theme.red : Theme.text
                    onMoved: v => root.setVolume(v * 1.5)
                }
            }

            Meter {
                width: parent.width
                height: 3
                value: root.peakLevel * 100
                critAt: 85
                duration: 60
            }

            // ── Per-app streams ────────────────────────────────────
            Rectangle {
                visible: root.appStreams.length > 0
                width: parent.width; height: 1
                color: Theme.hairline
            }

            SectionLabel {
                visible: root.appStreams.length > 0
                text: "Applications"
            }

            Flickable {
                visible: root.appStreams.length > 0
                width: parent.width
                height: Math.min(contentHeight, 150)
                contentWidth: width
                contentHeight: streamsCol.implicitHeight
                clip: true

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: streamsCol
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: root.appStreams
                        delegate: Column {
                            required property var modelData

                            width: parent.width
                            spacing: 4

                            PwNodePeakMonitor {
                                id: streamPeakMon
                                node: modelData
                                enabled: BarHover.activeModule === "audio"
                            }

                            Item {
                                width: parent.width
                                height: 16

                                Label {
                                    anchors { left: parent.left; right: volLabel.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    text: (modelData.properties && modelData.properties["application.name"]) || modelData.description || modelData.name || "Unknown"
                                    font.pixelSize: Theme.textSm
                                    elide: Text.ElideRight
                                }

                                Label {
                                    id: volLabel
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    text: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : "—"
                                    color: Theme.subtext
                                    font.pixelSize: Theme.textSm
                                }
                            }

                            Slider {
                                width: parent.width
                                value: modelData.audio ? Math.min(1, modelData.audio.volume) : 0
                                onMoved: v => { if (modelData.audio) modelData.audio.volume = v }
                            }

                            Meter {
                                width: parent.width
                                height: 3
                                value: root.peakToLevel(streamPeakMon.peaks, modelData.audio ? modelData.audio.volume : 1.0) * 100
                                fillColor: Theme.subtext
                                critAt: 85
                                duration: 60
                            }
                        }
                    }
                }
            }
        }
    }
}
