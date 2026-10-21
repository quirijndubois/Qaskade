import QtQuick
import "../"

// All bar modules assigned to one position ("left" | "center" | "right"),
// in a fixed order. Row skips hidden children, so spacing stays even.
// Modules that poll in the background are only created where they're shown.
Row {
    id: root

    required property string pos
    property var screen: null
    property var monitor: null
    property bool menuActive: false
    signal menuClicked()

    spacing: 14

    MenuModule {
        visible: Theme.showMenu === root.pos
        active: root.menuActive
        onClicked: root.menuClicked()
    }
    WorkspacesModule {
        visible: Theme.showWorkspaces === root.pos
        screen: root.screen
        monitor: root.monitor
    }
    ClockModule {
        visible: Theme.showClock === root.pos
        screen: root.screen
    }
    MusicModule {
        targetRow: root.pos
        screen: root.screen
    }
    Loader {
        active: Theme.showCpu === root.pos
        visible: active
        sourceComponent: CpuModule { screen: root.screen }
    }
    Loader {
        active: Theme.showMemory === root.pos
        visible: active
        sourceComponent: MemoryModule { screen: root.screen }
    }
    Loader {
        active: Theme.showGpu === root.pos
        visible: active
        sourceComponent: GpuModule { screen: root.screen }
    }
    InhibitModule {
        visible: Theme.showInhibit === root.pos
        screen: root.screen
    }
    TrayModule {
        targetRow: root.pos
    }
    Loader {
        active: Theme.showNetwork === root.pos
        visible: active
        sourceComponent: NetworkModule { screen: root.screen }
    }
    BluetoothModule {
        visible: Theme.showBluetooth === root.pos
        screen: root.screen
    }
    AudioModule {
        visible: Theme.showAudio === root.pos
        screen: root.screen
    }
    BatteryModule {
        id: battery
        visible: Theme.showBattery === root.pos && battery.present
        screen: root.screen
    }
}
