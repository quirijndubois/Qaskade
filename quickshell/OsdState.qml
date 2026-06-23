pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    property string type:  ""     // "volume" | "brightness"
    property real   value: 0      // volume: raw 0–1.5 pipewire units; brightness: 0–1
    property bool   muted: false
    property bool   active: false

    function showVolume(vol, isMuted) {
        root.type   = "volume"
        root.value  = vol
        root.muted  = isMuted
        root.active = true
        hideTimer.restart()
    }

    function showBrightness(pct) {
        root.type   = "brightness"
        root.value  = Math.max(0, Math.min(100, pct)) / 100
        root.muted  = false
        root.active = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.active = false
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    property var  sink:         Pipewire.defaultAudioSink
    property real trackedVol:   sink && sink.audio ? sink.audio.volume : -1
    property bool trackedMuted: sink && sink.audio ? sink.audio.muted  : false
    property bool volumeReady:  false

    onTrackedVolChanged: {
        if (!volumeReady) { volumeReady = (trackedVol >= 0); return }
        if (trackedVol >= 0 && sink && sink.audio)
            showVolume(sink.audio.volume, sink.audio.muted)
    }

    onTrackedMutedChanged: {
        if (!volumeReady) return
        if (sink && sink.audio)
            showVolume(sink.audio.volume, sink.audio.muted)
    }
}
