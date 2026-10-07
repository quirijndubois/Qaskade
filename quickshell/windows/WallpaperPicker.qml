import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../"

Item {
    id: root

    property bool shown: false
    signal closeRequested()

    // ── Dimensions ────────────────────────────────────────────────
    readonly property int bigRowH:    194
    readonly property int smallRowH:   68
    readonly property int pickerH:     bigRowH + smallRowH * 2
    readonly property int labelW:     110
    readonly property int bigThumbW:  268
    readonly property int catBase:    499

    // ── State ────────────────────────────────────────────────────
    property var  categories:  []
    property int  selCatIdx:   0
    property var  catOffsets:  {}
    property string wpDir:     ""
    property string homeDir:   ""

    // Thumbnail cache: ~/wallpapers/.thumbs/ — always generated before images are shown
    property bool   _hasThumbCache:    false
    property bool   _genThumbsRunning: false
    readonly property string thumbDir: _hasThumbCache ? wpDir + ".thumbs/" : ""

    // Snap scroll: disables highlight animation on open/rebuild
    property bool _snapScroll: true
    Timer { id: snapTimer; interval: 120; onTriggered: root._snapScroll = false }

    // Resume position across open/close cycles
    property string _resumeCatName: ""
    property string _resumeFile:    ""

    // ── Random-pick category ─────────────────────────────────────
    property string randomCat: ""   // category name pinned for Alt+R ("" = all)

    function _setRandomCat(name) {
        root.randomCat = name
        saveCatProc.command = ["sh", "-c",
            "printf '%s' " + JSON.stringify(name) +
            " > \"$HOME/.config/quickshell/wallpaper-category\""]
        saveCatProc.running = false
        saveCatProc.running = true
    }

    // ── Tagging ───────────────────────────────────────────────────
    property int    _minCatSize:  1

    readonly property string _currentFile: {
        const c = _cat()
        if (!c?.files.length) return ""
        const n = c.files.length
        const fi = ((_offset() % n) + n) % n
        return c.files[fi]
    }

    // ── Navigation ───────────────────────────────────────────────
    function _cat()    { return categories[selCatIdx] || null }
    function _offset() { return (catOffsets || {})[selCatIdx] || 0 }

    // Debounce: wallpaper only applied after 100 ms of no navigation
    property string _pendingTrans: "any"
    Timer {
        id: debounceTimer
        interval: 100
        onTriggered: root._applyTransition(root._pendingTrans)
    }

    function _applyTransition(trans) {
        const c = _cat(); if (!c?.files.length) return
        const n  = c.files.length
        const fi = ((_offset() % n) + n) % n
        const path = wpDir + c.files[fi]
        applyProc.command = ["awww", "img",
            "--transition-type", trans,
            "--transition-duration", "0.5",
            "--transition-fps", "60", path]
        applyProc.running = false
        applyProc.running = true
        if (homeDir) {
            paletteProc.command = ["sh", "-c",
                "colors=$(\"" + homeDir + "/.conda/envs/pywalfox/bin/python3\"" +
                " \"" + homeDir + "/.config/quickshell/scripts/extract-palette.py\"" +
                " \"" + path + "\") && " +
                "printf '%s' \"$colors\" > \"" + homeDir + "/.config/quickshell/custom-palette\" && " +
                "quickshell ipc -c default call theme setCustom"]
            paletteProc.running = false
            paletteProc.running = true
        }
    }

    function navRight() {
        const c = _cat(); if (!c?.files.length) return
        const o = Object.assign({}, catOffsets)
        o[selCatIdx] = _offset() + 1; catOffsets = o
        root._pendingTrans = "right"; debounceTimer.restart()
    }
    function navLeft() {
        const c = _cat(); if (!c?.files.length) return
        const o = Object.assign({}, catOffsets)
        o[selCatIdx] = _offset() - 1; catOffsets = o
        root._pendingTrans = "left"; debounceTimer.restart()
    }
    function navDown() {
        if (categories.length) {
            selCatIdx = (selCatIdx + 1) % categories.length
            root._pendingTrans = "any"; debounceTimer.restart()
        }
    }
    function navUp() {
        if (categories.length) {
            selCatIdx = (selCatIdx - 1 + categories.length) % categories.length
            root._pendingTrans = "any"; debounceTimer.restart()
        }
    }

    function applyWallpaper() {
        root.closeRequested()
    }

    // ── Reload data on open: generate thumbs first, then load files ─
    onShownChanged: {
        if (shown) {
            root._snapScroll = true
            root._resumeCatName = (categories.length > 0 && categories[selCatIdx])
                ? categories[selCatIdx].name : ""
            root._resumeFile = root._currentFile
            if (homeDir) {
                genThumbsProc.command = ["sh",
                    homeDir + "/.config/quickshell/scripts/gen-thumbs.sh"]
                genThumbsProc.running = false
                genThumbsProc.running = true
            }
        }
    }

    // ── Build categories ─────────────────────────────────────────
    property var _allFiles: []
    property var _tags: {}

    function _buildCategories(preserveCatName, preserveFile) {
        if (!_allFiles.length) return
        root._snapScroll = true
        const tagMap = {}
        for (const file of _allFiles) {
            for (const tag of (_tags[file] || [])) {
                if (!tagMap[tag]) tagMap[tag] = []
                tagMap[tag].push(file)
            }
        }
        const cats = [{ name: "all", files: _allFiles }]
        for (const tag of Object.keys(tagMap).sort())
            if (tagMap[tag].length >= root._minCatSize)
                cats.push({ name: tag, files: tagMap[tag] })
        categories = cats

        if (preserveCatName !== undefined && preserveFile !== undefined) {
            const ci = cats.findIndex(c => c.name === preserveCatName)
            selCatIdx = ci >= 0 ? ci : 0
            const cat = cats[selCatIdx]
            if (cat) {
                const fi = cat.files.indexOf(preserveFile)
                const o = {}
                o[selCatIdx] = fi >= 0 ? fi : 0
                catOffsets = o
            } else {
                catOffsets = {}
            }
        } else {
            selCatIdx  = 0
            catOffsets = {}
        }
        snapTimer.restart()
    }

    // ── Processes ────────────────────────────────────────────────
    Process {
        id: homeDirProc
        command: ["sh", "-c", "printf '%s' \"$HOME\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.homeDir = this.text.trim()
                root.wpDir   = root.homeDir + "/wallpapers/"
            }
        }
    }

    Process {
        id: filesProc
        command: ["sh", "-c",
            "ls -1 \"$HOME/wallpapers/\" 2>/dev/null | grep -iE '\\.(jpg|jpeg|png|webp|gif)$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._allFiles = this.text.trim().split('\n').filter(Boolean)
                tagsProc.running = false
                tagsProc.running = true
            }
        }
    }

    Process {
        id: tagsProc
        command: ["sh", "-c",
            "cat \"$HOME/wallpapers/.tags\" 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root._tags = JSON.parse(this.text.trim()) } catch(e) { root._tags = {} }
                reloadMinCatProc.running = false
                reloadMinCatProc.running = true
            }
        }
    }

    // Re-reads min-cat-size on every open so settings changes take effect immediately.
    Process {
        id: reloadMinCatProc
        command: ["sh", "-c", "cat \"$HOME/wallpapers/.min-cat-size\" 2>/dev/null || echo '1'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(this.text.trim())
                if (!isNaN(n) && n >= 1) root._minCatSize = n
                if (root._resumeCatName) {
                    root._buildCategories(root._resumeCatName, root._resumeFile)
                } else {
                    root._buildCategories()
                }
                loadCatProc.running = false
                loadCatProc.running = true
            }
        }
    }

    Process {
        id: loadCatProc
        command: ["sh", "-c",
            "cat \"$HOME/.config/quickshell/wallpaper-category\" 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: { root.randomCat = this.text.trim() }
        }
    }

    Process {
        id: saveCatProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: applyProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: paletteProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: minCatProc
        command: ["sh", "-c", "cat \"$HOME/wallpapers/.min-cat-size\" 2>/dev/null || echo '1'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(this.text.trim())
                if (!isNaN(n) && n >= 1) root._minCatSize = n
            }
        }
    }

    // Runs gen-thumbs.sh before loading the file list so delegates
    // are only created once every thumb exists — no full-res fallback needed.
    Process {
        id: genThumbsProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onRunningChanged: {
            root._genThumbsRunning = running
            if (!running) {
                root._hasThumbCache = true
                filesProc.running = false
                filesProc.running = true
            }
        }
    }

    // ── Per-screen panel ─────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: panel
                required property var modelData
                screen: modelData

                readonly property bool isFocused: {
                    const hm = Hyprland.monitorFor(modelData)
                    return hm !== null && hm === Hyprland.focusedMonitor
                }

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: (root.shown && isFocused)
                    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                anchors { bottom: true; left: true; right: true }
                exclusiveZone: 0
                color: "transparent"
                implicitHeight: root.pickerH
                mask: Region { item: card }

                property real slideY: root.shown ? 0 : root.pickerH
                Behavior on slideY {
                    NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    id: card
                    // 1px inset from right edge so the rounded corner isn't clipped
                    x: 0
                    width: parent.width - 1
                    height: root.pickerH
                    y: panel.slideY
                    color: Theme.base
                    border.color: Theme.border
                    border.width: 1
                    topLeftRadius: 14
                    topRightRadius: 14
                    clip: true

                    // ── Keyboard handler ──────────────────────────
                    Item {
                        id: keyItem
                        anchors.fill: parent
                        focus: root.shown && panel.isFocused

                        Keys.onPressed: event => {
                            switch (event.key) {
                                case Qt.Key_Left:   root.navLeft();    break
                                case Qt.Key_Right:  root.navRight();   break
                                case Qt.Key_Up:     root.navUp();      break
                                case Qt.Key_Down:   root.navDown();    break
                                case Qt.Key_R: {
                                    const c = root._cat()
                                    if (c) root._setRandomCat(c.name)
                                    break
                                }
                                case Qt.Key_Return:
                                case Qt.Key_Enter:  root.applyWallpaper(); break
                                case Qt.Key_Escape: root.closeRequested(); break
                            }
                            event.accepted = true
                        }
                    }

                    // ── Generating-thumbnails overlay ─────────────
                    Text {
                        visible: root._genThumbsRunning
                        anchors.centerIn: parent
                        text: "preparing…"
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12
                        opacity: 0.6
                    }

                    // ── Category ListView (vertical) ──────────────
                    ListView {
                        id: catList
                        anchors.fill: parent
                        clip: true
                        interactive: false

                        model: root.categories
                        currentIndex: root.selCatIdx

                        preferredHighlightBegin: root.smallRowH
                        preferredHighlightEnd:   root.smallRowH + root.bigRowH
                        highlightRangeMode:      ListView.StrictlyEnforceRange
                        highlightMoveDuration:   300

                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index

                            property bool isCurrent: index === root.selCatIdx

                            width:  catList.width
                            height: isCurrent ? root.bigRowH : root.smallRowH
                            Behavior on height {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }
                            opacity: isCurrent ? 1.0 : 0.48
                            Behavior on opacity { NumberAnimation { duration: 220 } }
                            clip: true

                            // ── Category label ────────────────────
                            Item {
                                width:  root.labelW
                                height: parent.height

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        width: root.labelW - 20
                                        text: row.modelData.name
                                        color: row.isCurrent ? Theme.purple : Theme.subtext
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: row.isCurrent ? 12 : 10
                                        font.bold: row.isCurrent
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }

                                    // Pin indicator: this category is the Alt+R source
                                    Text {
                                        visible: root.randomCat === row.modelData.name
                                                 || (root.randomCat === "" && row.modelData.name === "all")
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: ""
                                        color: Theme.green
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 12
                                        opacity: 0.85
                                    }
                                }

                            }

                            Rectangle {
                                x: root.labelW
                                width: 1; height: parent.height
                                color: Theme.border
                                opacity: 0.5
                            }

                            // ── Wallpaper strip ───────────────────
                            ListView {
                                id: hList
                                x: root.labelW + 1
                                width:  parent.width - root.labelW - 1
                                height: parent.height
                                clip: true
                                interactive: false
                                orientation: Qt.Horizontal

                                property var cat: row.modelData
                                property int n:   cat.files.length

                                model: Math.max(n, 1) * 999

                                currentIndex: root.catBase * Math.max(n, 1)
                                              + ((root.catOffsets || {})[row.index] || 0)

                                highlightMoveDuration:   root._snapScroll ? 0 : 220
                                highlightRangeMode:      ListView.StrictlyEnforceRange
                                preferredHighlightBegin: (width - root.bigThumbW) / 2
                                preferredHighlightEnd:   (width - root.bigThumbW) / 2 + root.bigThumbW

                                delegate: Item {
                                    id: thumb
                                    required property int index

                                    property int  ri:     hList.n > 0 ? index % hList.n : 0
                                    property bool active: ListView.isCurrentItem && row.isCurrent

                                    // Constant layout width — contentX never shifts on row change
                                    width:  root.bigThumbW
                                    height: hList.height

                                    property real visualW: root.bigThumbW - (row.isCurrent ? 18 : 6)
                                    property real inset:   row.isCurrent ? 9 : 3
                                    Behavior on visualW { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                    Behavior on inset   { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                                    Rectangle {
                                        x:      (parent.width - thumb.visualW) / 2
                                        y:      thumb.inset
                                        width:  thumb.visualW
                                        height: parent.height - thumb.inset * 2
                                        radius: 8
                                        color:  Theme.surface
                                        clip:   true

                                        scale: thumb.active  ? 1.0
                                             : row.isCurrent ? 0.88
                                             : 1.0
                                        Behavior on scale {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                        }

                                        Image {
                                            anchors.fill: parent
                                            source: (root.thumbDir && hList.n > 0)
                                                ? "file://" + root.thumbDir + hList.cat.files[thumb.ri]
                                                : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            smooth: true
                                        }

                                        // Selection ring
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "transparent"
                                            border.color: Theme.blue
                                            border.width: thumb.active ? 2 : 0
                                            Behavior on border.width {
                                                NumberAnimation { duration: 180 }
                                            }
                                        }

                                        // Tagged indicator — only in the "all" category
                                        Rectangle {
                                            visible: row.modelData.name === "all"
                                                && hList.n > 0
                                                && !!(root._tags[hList.cat.files[thumb.ri]])
                                            anchors { right: parent.right; bottom: parent.bottom; margins: 5 }
                                            width: 7; height: 7; radius: 4
                                            color: Theme.green
                                            opacity: 0.85
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
}
