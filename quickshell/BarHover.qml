pragma Singleton
import Quickshell
import QtQuick

// Shared state for the hover popup that hangs below the bar.
Singleton {
    id: root

    property string activeModule: ""
    property Component popupComponent: null
    property real anchorX: 0
    property var activeScreen: null

    function show(moduleId, comp, x, screen) {
        hideTimer.stop()
        activeModule = moduleId
        popupComponent = comp
        anchorX = x
        activeScreen = screen
    }

    function startHide() { hideTimer.restart() }
    function keepAlive() { hideTimer.stop() }

    Timer {
        id: hideTimer
        interval: 180
        onTriggered: {
            root.activeModule = ""
            root.popupComponent = null
        }
    }
}
