import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../"

Item {
    id: root

    // ── BarText-compatible interface ──────────────────────────────
    property string moduleId: "audio"
    property Component modulePopup: popup
    property real popupHeight: computePopupH()
    property var screen: null

    implicitWidth: innerRow.implicitWidth + (Theme.design === "pills" ? 20 : 0)
    implicitHeight: Theme.design === "pills" ? Theme.barHeight - 8 : innerRow.implicitHeight

    onPopupHeightChanged: {
        if (BarHover.activeModule === moduleId)
            BarHover.popupH = popupHeight
    }

    // ── Sink data ─────────────────────────────────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    property var sink: Pipewire.defaultAudioSink
    property var appStreams: []
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
    }

    function computePopupH() {
        return appStreams.length > 0 ? 277 : 117
    }

    // ── Live peak for bar widget ──────────────────────────────────
    PwNodePeakMonitor {
        id: barPeakMon
        node: root.sink
        enabled: root.sink !== null
    }

    property real barPeakLevel: {
        const p = barPeakMon.peaks
        if (!p || p.length === 0) return 0
        let m = 0
        for (let i = 0; i < p.length; i++) if (p[i] > m) m = p[i]
        if (m < 1e-5) return 0
        const db = 20 * Math.log10(Math.min(1.0, m))
        return Math.max(0, Math.min(1, (db + 6) / 6))
    }

    property bool   isMuted: sink && sink.audio && sink.audio.muted
    property real   volLevel: sink && sink.audio ? sink.audio.volume : 0
    property color  accent: Theme.yellow

    property string volIcon: {
        if (!sink || !sink.audio || sink.audio.muted) return String.fromCodePoint(0xF075F)
        const v = sink.audio.volume
        if (v < 0.33) return String.fromCodePoint(0xF057F)
        if (v < 0.66) return String.fromCodePoint(0xF0580)
        return String.fromCodePoint(0xF057E)
    }

    // ── Visual layers ─────────────────────────────────────────────
    Rectangle {
        id: pillsBg
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
        spacing: 6

        // Speaker icon + bars as one combined visual unit
        Item {
            id: speakerUnit
            height: Theme.barFontSize
            width: iconLabel.implicitWidth + 3 + eqBars.width
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: iconLabel
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: root.volIcon
                color: root.isMuted ? Theme.subtext : root.accent
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: Theme.barFontSize
            }

            // Bars grow from vertical center of icon — look like sound wave arcs
            Item {
                id: eqBars
                anchors { left: iconLabel.right; leftMargin: 3; verticalCenter: parent.verticalCenter }
                width: 10   // 3 bars × 2px + 2 gaps × 2px + last bar = 10
                height: Theme.barHeight - 6

                Repeater {
                    model: [
                        { frac: 0.38, dur: 80  },
                        { frac: 0.65, dur: 170 },
                        { frac: 1.00, dur: 300 }
                    ]
                    Item {
                        required property var modelData
                        required property int index

                        x: index * 4
                        width: 2
                        height: parent.height

                        Rectangle {
                            property real level: root.isMuted ? 0 : Math.min(1.0, root.barPeakLevel * root.volLevel) * modelData.frac
                            anchors { verticalCenter: parent.verticalCenter; horizontalCenter: parent.horizontalCenter }
                            width: 2
                            height: Math.max(2, parent.height * level)
                            radius: 1
                            color: root.barPeakLevel > 0.9 && !root.isMuted ? Theme.red : (root.isMuted ? Theme.subtext : root.accent)
                            Behavior on height { NumberAnimation { duration: modelData.dur; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (!root.sink || !root.sink.audio) return "--%"
                if (root.sink.audio.muted) return "mute"
                return Math.round(root.sink.audio.volume * 100) + "%"
            }
            color: root.isMuted ? Theme.subtext : root.accent
            font.family: Theme.barFontFamily
            font.pixelSize: Theme.barFontSize
            font.bold: Theme.barFontBold
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: pavuProc.running = true
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                BarHover.show(root.moduleId, root.modulePopup,
                              root.mapToItem(null, root.width / 2, 0).x,
                              root.popupHeight, root.screen)
            else
                BarHover.startHide()
        }
    }

    Process {
        id: pavuProc
        command: ["pavucontrol"]
    }

    // ── Popup ─────────────────────────────────────────────────────
    Component {
        id: popup
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 10

            PwNodePeakMonitor {
                id: sinkPeakMon
                node: root.sink
                enabled: BarHover.activeModule === "audio"
            }

            property real sinkPeakLevel: {
                const p = sinkPeakMon.peaks
                if (!p || p.length === 0) return 0
                let m = 0
                for (let i = 0; i < p.length; i++) if (p[i] > m) m = p[i]
                if (m < 1e-5) return 0
                const db = 20 * Math.log10(Math.min(1.0, m))
                return Math.max(0, Math.min(1, (db + 6) / 6))
            }

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

            Rectangle {
                width: parent.width; height: 3; radius: 1
                color: Theme.border

                Rectangle {
                    width: parent.width * parent.parent.sinkPeakLevel
                    height: parent.height; radius: parent.radius
                    color: parent.parent.sinkPeakLevel > 0.85 ? Theme.red : Theme.yellow
                    Behavior on width { NumberAnimation { duration: 60 } }
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
                                const vol = modelData.audio ? modelData.audio.volume : 1.0
                                const v = Math.min(1.0, m * vol)
                                if (v < 1e-5) return 0
                                const db = 20 * Math.log10(v)
                                return Math.max(0, Math.min(1, (db + 6) / 6))
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
