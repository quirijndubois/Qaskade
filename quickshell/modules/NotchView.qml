import QtQuick

// One of the views the center notch can show. Fades in slowly once the notch
// has started growing, and out quickly so it never spills while it shrinks.
// `instant` views (e.g. the volume indicator) appear right away instead, so
// feedback for quick, repeated input is never hidden behind the animation.
Item {
    property bool current: false
    property bool instant: false

    opacity: current ? 1 : 0
    enabled: current
    Behavior on opacity {
        NumberAnimation {
            duration: current ? (instant ? 90 : 260) : 120
            easing.type: current && !instant ? Easing.InCubic : Easing.OutCubic
        }
    }
}
