import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../"

BarText {
    id: root
    color: Theme.yellow

    property var screen: null

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    property var sink: Pipewire.defaultAudioSink
    property var appStreams: []

    // Track PipeWire stream nodes
    property bool streamUpdatePending: false

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
        if (BarHover.activeModule === "audio")
            BarHover.popupH = computePopupH()
    }

    function computePopupH() {
        return appStreams.length > 0 ? 264 : 104
    }

    text: {
        if (!sink || !sink.audio) return "vol --%"
        const vol = Math.round(sink.audio.volume * 100)
        return sink.audio.muted ? "vol mute" : "vol " + vol + "%"
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: pavuProc.running = true
    }

    Process {
        id: pavuProc
        command: ["pavucontrol"]
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show("audio", popup, root.mapToItem(null, root.width / 2, 0).x, root.computePopupH(), root.screen)
            else
                BarHover.startHide()
        }
    }

    Component {
        id: popup
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 10

            Row {
                spacing: 8

                Text {
                    text: {
                        if (!root.sink || !root.sink.audio) return "--%"
                        return root.sink.audio.muted ? "muted" : Math.round(root.sink.audio.volume * 100) + "%"
                    }
                    color: (root.sink && root.sink.audio && root.sink.audio.muted) ? Theme.subtext : Theme.yellow
                    font.family: Theme.barFontFamily
                    font.pixelSize: 20
                    font.bold: true
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    text: (root.sink && root.sink.audio && root.sink.audio.muted) ? "click to unmute" : "click to mute"
                    color: Theme.subtext
                    font.family: Theme.barFontFamily
                    font.pixelSize: 10
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted }
                    }
                }
            }

            // Master volume slider
            Item {
                width: parent.width
                height: 16

                Rectangle {
                    id: sliderTrack
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    height: 5
                    radius: 2
                    color: Theme.border

                    Rectangle {
                        width: parent.width * Math.min(1, (root.sink && root.sink.audio ? root.sink.audio.volume / 1.5 : 0))
                        height: parent.height
                        radius: parent.radius
                        color: (root.sink && root.sink.audio && root.sink.audio.volume > 1.0) ? Theme.red : Theme.yellow
                    }
                }

                Rectangle {
                    x: sliderTrack.width * Math.min(1, (root.sink && root.sink.audio ? root.sink.audio.volume / 1.5 : 0)) - width / 2
                    anchors.verticalCenter: sliderTrack.verticalCenter
                    width: 12; height: 12; radius: 6
                    color: Theme.yellow
                    border.color: Theme.base; border.width: 2
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed:         mouse => setVol(mouse.x)
                    onPositionChanged: mouse => { if (pressed) setVol(mouse.x) }
                    function setVol(mx) {
                        const v = Math.max(0, Math.min(1.5, (mx / sliderTrack.width) * 1.5))
                        if (root.sink && root.sink.audio) root.sink.audio.volume = v
                    }
                }
            }

            Text {
                text: root.sink ? (root.sink.description || root.sink.name || "") : ""
                color: Theme.subtext
                font.family: Theme.barFontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
                width: parent.width
            }

            // ── Per-app streams ────────────────────────────────────
            Rectangle {
                visible: root.appStreams.length > 0
                width: parent.width; height: 1
                color: Theme.border; opacity: 0.5
            }

            Text {
                visible: root.appStreams.length > 0
                text: "app volumes"
                color: Theme.subtext
                font.family: Theme.barFontFamily
                font.pixelSize: 10
            }

            Flickable {
                visible: root.appStreams.length > 0
                width: parent.width
                height: Math.min(contentHeight, 130)
                contentWidth: width
                contentHeight: streamsCol.implicitHeight
                clip: true

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: streamsCol
                    width: parent.width
                    spacing: 6

                Repeater {
                    model: root.appStreams
                    delegate: Column {
                        required property var modelData

                        width: parent.width
                        spacing: 4

                        PwNodePeakMonitor {
                            id: peakMon
                            node: modelData
                            enabled: BarHover.activeModule === "audio"
                        }

                        property real peakLevel: {
                            const p = peakMon.peaks
                            if (!p || p.length === 0) return 0
                            let m = 0
                            for (let i = 0; i < p.length; i++) if (p[i] > m) m = p[i]
                            return Math.min(1.0, m)
                        }

                        // ── Name + vol% ──────────────────────────
                        Row {
                            width: parent.width

                            Text {
                                width: parent.width - volLabel.width
                                text: modelData.description || modelData.name || "?"
                                color: Theme.text
                                font.family: Theme.barFontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            Text {
                                id: volLabel
                                text: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : "--%"
                                color: Theme.yellow
                                font.family: Theme.barFontFamily
                                font.pixelSize: 10
                            }
                        }

                        // ── Peak level bar ───────────────────────
                        Rectangle {
                            width: parent.width; height: 3; radius: 1
                            color: Theme.border

                            Rectangle {
                                width: parent.width * peakLevel
                                height: parent.height; radius: parent.radius
                                color: peakLevel > 0.85 ? Theme.red : Theme.teal
                                Behavior on width { NumberAnimation { duration: 60 } }
                            }
                        }

                        // ── Volume slider ────────────────────────
                        Item {
                            width: parent.width; height: 14

                            Rectangle {
                                id: streamTrack
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                height: 4; radius: 2; color: Theme.border

                                Rectangle {
                                    width: parent.width * Math.min(1, modelData.audio ? modelData.audio.volume : 0)
                                    height: parent.height; radius: parent.radius
                                    color: Theme.yellow
                                }
                            }

                            Rectangle {
                                x: streamTrack.width * Math.min(1, modelData.audio ? modelData.audio.volume : 0) - width / 2
                                anchors.verticalCenter: streamTrack.verticalCenter
                                width: 10; height: 10; radius: 5
                                color: Theme.yellow
                                border.color: Theme.base; border.width: 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed:         mouse => setStreamVol(mouse.x)
                                onPositionChanged: mouse => { if (pressed) setStreamVol(mouse.x) }
                                function setStreamVol(mx) {
                                    const v = Math.max(0, Math.min(1.0, mx / streamTrack.width))
                                    if (modelData.audio) modelData.audio.volume = v
                                }
                            }
                        }
                    }
                    }
                }
            }
        }
    }
}
