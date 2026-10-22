import QtQuick
import QtQuick.Shapes
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
    // Hardware devices, for the output/input pickers in the popup
    property var sinks: []
    property var sources: []
    // Which picker is expanded: "", "output" or "input"
    property string openPicker: ""
    property bool streamUpdatePending: false

    readonly property bool isMuted: !!(sink && sink.audio && sink.audio.muted)
    readonly property real volLevel: sink && sink.audio ? sink.audio.volume : 0

    // Glyph for the popup's mute button; the bar draws its own speaker below
    readonly property string volumeGlyph: isMuted || volLevel === 0 ? "volumeMute"
        : volLevel < 0.33 ? "volumeLow"
        : volLevel < 0.66 ? "volumeMedium"
        : "volumeHigh"

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

    // A drawn speaker whose sound-wave arcs carry the live level. The
    // volume sets how many arcs are lit (1–3, like the usual glyph); the
    // output level brightens them from the inside out and pushes them
    // outward a little. Muted, the arcs fade and a cross takes their place.
    trailing: Item {
        id: speaker

        readonly property real h: Theme.barFontSize + 3
        readonly property real cx: h * 0.48          // where the cone opens
        readonly property real cy: h / 2
        readonly property int lit: root.isMuted || root.volLevel === 0 ? 0
                                 : root.volLevel < 0.33 ? 1 : root.volLevel < 0.66 ? 2 : 3
        readonly property real level: Math.min(1, root.peakLevel * Math.min(1, root.volLevel) * 1.15)
        readonly property color ink: root.isMuted ? Theme.subtext : Theme.text

        width: h * 1.3
        height: h

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: speaker.ink
                strokeColor: speaker.ink
                strokeWidth: 1
                joinStyle: ShapePath.RoundJoin
                startX: 0.5;                   startY: speaker.cy - speaker.h * 0.17
                PathLine { x: speaker.h * 0.20; y: speaker.cy - speaker.h * 0.17 }
                PathLine { x: speaker.cx;       y: speaker.cy - speaker.h * 0.40 }
                PathLine { x: speaker.cx;       y: speaker.cy + speaker.h * 0.40 }
                PathLine { x: speaker.h * 0.20; y: speaker.cy + speaker.h * 0.17 }
                PathLine { x: 0.5;              y: speaker.cy + speaker.h * 0.17 }
                PathLine { x: 0.5;              y: speaker.cy - speaker.h * 0.17 }
            }
        }

        Repeater {
            model: 3

            Shape {
                id: arc
                required property int index

                readonly property bool on: arc.index < speaker.lit
                // How far the level reaches into this arc (inner arcs fill first)
                readonly property real fill: Math.max(0, Math.min(1, speaker.level * 3 - arc.index))
                readonly property real r: speaker.h * (0.22 + arc.index * 0.2)

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: root.isMuted ? 0 : arc.on ? 0.35 + 0.65 * arc.fill : 0.12
                transform: Translate {
                    x: arc.on ? arc.fill * 1.5 : 0
                    Behavior on x { NumberAnimation { duration: 90 + arc.index * 70; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: 90 + arc.index * 70; easing.type: Easing.OutCubic } }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: arc.index === 2 && root.peakLevel > 0.9 && !root.isMuted ? Theme.red : speaker.ink
                    strokeWidth: 1.6
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: speaker.cx; centerY: speaker.cy
                        radiusX: arc.r; radiusY: arc.r
                        startAngle: -48; sweepAngle: 96
                        moveToStart: true
                    }
                }
            }
        }

        // Mute cross
        Shape {
            id: cross
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: root.isMuted ? 1 : 0
            scale: root.isMuted ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

            readonly property real x0: speaker.cx + speaker.h * 0.22
            readonly property real d: speaker.h * 0.28

            ShapePath {
                fillColor: "transparent"
                strokeColor: speaker.ink
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                startX: cross.x0;           startY: speaker.cy - cross.d / 2
                PathLine { x: cross.x0 + cross.d; y: speaker.cy + cross.d / 2 }
                PathMove { x: cross.x0 + cross.d; y: speaker.cy - cross.d / 2 }
                PathLine { x: cross.x0;            y: speaker.cy + cross.d / 2 }
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
        const streams = [], outs = [], ins = []
        for (let i = 0; i < nodeRep.count; i++) {
            const item = nodeRep.itemAt(i)
            if (!item) continue
            const node = item.modelData
            if (!node) continue
            if (node.type === PwNodeType.AudioOutStream)
                streams.push(node)
            else if (node.audio && !node.isStream)
                (node.isSink ? outs : ins).push(node)
        }
        appStreams = streams
        sinks = outs
        sources = ins
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

    Connections {
        target: BarHover
        function onActiveModuleChanged() { if (BarHover.activeModule !== "audio") root.openPicker = "" }
    }

    // A device row that expands into the list of devices to pick from.
    component DevicePicker: Column {
        id: picker

        property string caption: ""
        property string icon: ""
        property var devices: []
        property var current: null
        property bool open: false
        readonly property bool resizing: listAnim.running
        signal toggled()
        signal picked(var node)

        function nameOf(node) {
            return node ? (node.description || node.nickname || node.name || "Unknown") : "None"
        }

        width: parent ? parent.width : 0
        spacing: 4

        Rectangle {
            width: parent.width
            height: 42
            radius: Theme.radiusMd
            color: picker.open ? Theme.selected : headHover.hovered ? Theme.hover : Theme.alpha(Theme.text, 0.03)
            border.width: 1
            border.color: Theme.hairline
            Behavior on color { ColorAnimation { duration: 120 } }

            Icon {
                id: headIcon
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                name: picker.icon
                size: 16
                color: picker.open ? Theme.accent : Theme.subtext
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Column {
                anchors {
                    left: headIcon.right; leftMargin: 10
                    right: chevron.left; rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                spacing: 0

                Label {
                    text: picker.caption
                    color: Theme.subtext
                    font.pixelSize: Theme.textXs
                    font.weight: Font.DemiBold
                }
                Label {
                    width: parent.width
                    text: picker.nameOf(picker.current)
                    font.pixelSize: Theme.textSm
                    elide: Text.ElideRight
                }
            }

            Icon {
                id: chevron
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                name: "chevronRight"
                size: 16
                color: Theme.subtext
                rotation: picker.open ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            HoverHandler { id: headHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: picker.toggled() }
        }

        // The list grows open; its rows fade and slide down into place.
        Item {
            width: parent.width
            height: picker.open ? list.implicitHeight : 0
            visible: height > 0
            clip: true
            Behavior on height { NumberAnimation { id: listAnim; duration: 240; easing.type: Easing.OutCubic } }

            Column {
                id: list
                width: parent.width
                spacing: 2
                opacity: picker.open ? 1 : 0
                y: picker.open ? 0 : -10
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Repeater {
                    model: picker.devices

                    Rectangle {
                        id: dev
                        required property var modelData
                        readonly property bool active: picker.current !== null && modelData.id === picker.current.id

                        width: list.width
                        height: 34
                        radius: Theme.radiusSm
                        color: devHover.hovered ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 90 } }

                        // Accent tick marks the device in use
                        Rectangle {
                            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                            width: 3
                            height: dev.active ? 16 : 0
                            radius: 1.5
                            color: Theme.accent
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }

                        Label {
                            anchors {
                                left: parent.left; leftMargin: 38
                                right: check.left; rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            text: picker.nameOf(dev.modelData)
                            color: dev.active ? Theme.text : Theme.alpha(Theme.text, 0.75)
                            font.pixelSize: Theme.textSm
                            font.weight: dev.active ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Icon {
                            id: check
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            name: "check"
                            size: 14
                            color: Theme.accent
                            opacity: dev.active ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        HoverHandler { id: devHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: picker.picked(dev.modelData) }
                    }
                }
            }
        }
    }

    // ── Popup ─────────────────────────────────────────────────────
    Component {
        id: popup
        Column {
            width: parent ? parent.width : 0
            spacing: 12
            // Lets the hover card follow the picker animation exactly
            readonly property bool resizing: outputPicker.resizing || inputPicker.resizing

            PopupHeader {
                title: "Sound"
                detail: root.isMuted ? "Muted" : Math.round(root.volLevel * 100) + "%"
                detailColor: root.isMuted ? Theme.subtext : root.volLevel > 1.0 ? Theme.red : Theme.text
            }

            Row {
                width: parent.width
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.volumeGlyph
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

            // ── Devices ────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 6

                DevicePicker {
                    id: outputPicker
                    caption: "OUTPUT"
                    icon: "speaker"
                    devices: root.sinks
                    current: Pipewire.defaultAudioSink
                    open: root.openPicker === "output"
                    onToggled: root.openPicker = open ? "" : "output"
                    onPicked: node => { Pipewire.preferredDefaultAudioSink = node; root.openPicker = "" }
                }

                DevicePicker {
                    id: inputPicker
                    caption: "INPUT"
                    icon: "microphone"
                    devices: root.sources
                    current: Pipewire.defaultAudioSource
                    open: root.openPicker === "input"
                    onToggled: root.openPicker = open ? "" : "input"
                    onPicked: node => { Pipewire.preferredDefaultAudioSource = node; root.openPicker = "" }
                }
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
