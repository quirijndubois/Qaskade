import QtQuick
import "../"

// Text whose characters roll like an odometer when they change: the old
// glyph slides up and out while the new one rises in from below. Changes
// ripple right-to-left, so "09:59" → "10:00" turns over minute digit first.
// Style it like a Label (color, font.*); font.letterSpacing becomes the gap
// between characters.
Row {
    id: root

    property string text: ""
    property color color: Theme.text
    property alias font: metrics.font
    property int duration: 520
    // Delay between neighbouring characters starting to roll
    property int stagger: 70

    spacing: font.letterSpacing

    Label { id: metrics; visible: false }

    Repeater {
        model: root.text.length

        Item {
            id: slot
            required property int index

            readonly property string ch: root.text.charAt(index)
            property string shown: ""
            property string previous: ""
            // 0 = previous fully visible, 1 = shown fully in place
            property real t: 1
            // ch settles while the delegate is being created; only roll after that
            property bool ready: false

            implicitWidth: Math.max(cur.implicitWidth, previous !== "" && t < 1 ? old.implicitWidth : 0)
            implicitHeight: cur.implicitHeight
            width: implicitWidth
            height: implicitHeight
            clip: t < 1

            Component.onCompleted: { shown = ch; ready = true }

            onChChanged: {
                if (!ready) { shown = ch; return }
                if (ch === shown) return
                previous = shown
                shown = ch
                roll.restart()
            }

            SequentialAnimation {
                id: roll
                PropertyAction { target: slot; property: "t"; value: 0 }
                PauseAnimation { duration: (root.text.length - 1 - slot.index) * root.stagger }
                NumberAnimation {
                    target: slot; property: "t"; to: 1
                    duration: root.duration
                    easing.type: Easing.OutBack; easing.overshoot: 0.9
                }
                PropertyAction { target: slot; property: "previous"; value: "" }
            }

            Label {
                id: old
                visible: slot.t < 1 && slot.previous !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                y: -slot.height * Math.min(slot.t, 1)
                opacity: 1 - Math.min(slot.t, 1)
                text: slot.previous
                color: root.color
                font.family: root.font.family
                font.pixelSize: root.font.pixelSize
                font.weight: root.font.weight
            }

            Label {
                id: cur
                anchors.horizontalCenter: parent.horizontalCenter
                y: slot.height * (1 - slot.t)
                opacity: Math.min(1, slot.t * 1.6)
                text: slot.shown
                color: root.color
                font.family: root.font.family
                font.pixelSize: root.font.pixelSize
                font.weight: root.font.weight
            }
        }
    }
}
