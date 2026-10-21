import QtQuick
import QtQuick.Shapes
import "../"

// A notch hanging from the top screen edge: flat top, rounded bottom corners
// and concave "shoulders" that blend it into the edge. It can morph between a
// compact bar-height pill and a large panel (settings, wallpapers, …) by
// changing contentWidth / contentHeight; size and corners animate together.
Item {
    id: root

    property real contentWidth: 0
    property real contentHeight: Theme.barHeight
    property int padding: 14
    readonly property int shoulder: 8
    // Hide without collapsing, e.g. while the center notch grows over this one.
    property bool suppressed: false
    readonly property real cornerRadius: Math.min(Math.round(height * 0.45), 28)

    default property alias content: inner.data

    // An empty notch collapses and fades out instead of setting `visible: false`.
    // Hiding it would also hide its modules, so the row would always measure 0
    // and the notch could never come back.
    readonly property bool empty: contentWidth <= 0

    readonly property real targetWidth: empty ? 0 : Math.ceil(contentWidth) + padding * 2
    readonly property real targetHeight: Math.ceil(contentHeight)

    width: animWidth
    height: animHeight
    opacity: empty || suppressed ? 0 : 1
    enabled: !suppressed
    Behavior on opacity { NumberAnimation { duration: 160 } }

    // Growing gets a light springy overshoot. Shrinking must never overshoot:
    // dipping below the compact size (or below zero) tears the corners and
    // shoulders, so it eases out and stops exactly on target.
    property real animWidth: 0
    property real animHeight: Theme.barHeight
    Component.onCompleted: {
        animWidth = targetWidth
        animHeight = targetHeight
    }

    function _animate(anim, from, to) {
        anim.stop()
        const grow = to > from
        anim.easing.type = grow ? Easing.OutBack : Easing.OutQuint
        anim.duration = grow ? 420 : 340
        anim.from = from
        anim.to = to
        anim.start()
    }

    onTargetWidthChanged: _animate(widthAnim, animWidth, targetWidth)
    onTargetHeightChanged: _animate(heightAnim, animHeight, targetHeight)

    NumberAnimation { id: widthAnim; target: root; property: "animWidth"; easing.overshoot: 0.7 }
    NumberAnimation { id: heightAnim; target: root; property: "animHeight"; easing.overshoot: 0.7 }

    // Left shoulder: fills the area between the top edge and a quarter circle.
    Shape {
        x: -root.shoulder
        width: root.shoulder
        height: root.shoulder
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Theme.base
            startX: 0; startY: 0
            PathLine { x: root.shoulder; y: 0 }
            PathLine { x: root.shoulder; y: root.shoulder }
            PathArc {
                x: 0; y: 0
                radiusX: root.shoulder; radiusY: root.shoulder
                direction: PathArc.Counterclockwise
            }
        }
    }

    Shape {
        x: root.width
        width: root.shoulder
        height: root.shoulder
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Theme.base
            startX: root.shoulder; startY: 0
            PathLine { x: 0; y: 0 }
            PathLine { x: 0; y: root.shoulder }
            PathArc {
                x: root.shoulder; y: 0
                radiusX: root.shoulder; radiusY: root.shoulder
                direction: PathArc.Clockwise
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.base
        bottomLeftRadius: root.cornerRadius
        bottomRightRadius: root.cornerRadius
    }

    Item {
        id: inner
        anchors { fill: parent; leftMargin: root.padding; rightMargin: root.padding }
        clip: true
    }
}
