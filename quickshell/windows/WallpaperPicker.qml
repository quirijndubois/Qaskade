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
    property bool   tagMode:    false
    property string tagInput:   ""
    property int    tagSelIdx:  -1   // index into _currentFileTags when browsing; -1 = input mode
    property bool   _autoTagging: false

    readonly property string _currentFile: {
        const c = _cat()
        if (!c?.files.length) return ""
        const n = c.files.length
        const fi = ((_offset() % n) + n) % n
        return c.files[fi]
    }
    readonly property var _currentFileTags: {
        if (!_tags || !_currentFile) return []
        return _tags[_currentFile] || []
    }

    function _saveWallpaperTags() {
        const safe = JSON.stringify(root._tags).replace(/'/g, "'\\''")
        saveTagsProc.command = ["sh", "-c",
            "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + safe + "' > \"$HOME/.config/quickshell/wallpaper-tags.json\""]
        saveTagsProc.running = false
        saveTagsProc.running = true
    }

    function _toggleTag(file, tag) {
        tag = tag.trim().toLowerCase()
        if (!tag || !file) return
        const prevCatName = categories[selCatIdx] ? categories[selCatIdx].name : "all"
        const tags = Array.from(root._tags[file] || [])
        const idx = tags.indexOf(tag)
        if (idx >= 0) tags.splice(idx, 1)
        else tags.push(tag)
        const updated = Object.assign({}, root._tags)
        if (tags.length === 0) delete updated[file]
        else updated[file] = tags
        root._tags = updated
        root._saveWallpaperTags()
        root._buildCategories(prevCatName, file)
    }

    function autoTag() {
        if (root._autoTagging || !root._currentFile || !homeDir) return
        root._autoTagging = true
        const path = wpDir + root._currentFile
        autoTagProc.command = ["python3",
            homeDir + "/.config/quickshell/scripts/auto-tag-wallpaper.py", path]
        autoTagProc.running = false
        autoTagProc.running = true
    }

    // ── Navigation ───────────────────────────────────────────────
    function _cat()    { return categories[selCatIdx] || null }
    function _offset() { return catOffsets[selCatIdx] || 0 }

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
        _applyTransition("right")
    }
    function navLeft() {
        const c = _cat(); if (!c?.files.length) return
        const o = Object.assign({}, catOffsets)
        o[selCatIdx] = _offset() - 1; catOffsets = o
        _applyTransition("left")
    }
    function navDown() {
        if (categories.length) {
            selCatIdx = (selCatIdx + 1) % categories.length
            _applyTransition("any")
        }
    }
    function navUp() {
        if (categories.length) {
            selCatIdx = (selCatIdx - 1 + categories.length) % categories.length
            _applyTransition("any")
        }
    }

    function applyWallpaper() {
        root.closeRequested()
    }

    // ── Reload data on open, preserving previous position ────────
    onShownChanged: {
        if (shown) {
            root._snapScroll = true
            root._resumeCatName = (categories.length > 0 && categories[selCatIdx])
                ? categories[selCatIdx].name : ""
            root._resumeFile = root._currentFile
            if (wpDir) {
                filesProc.running = false
                filesProc.running = true
            }
        } else {
            root.tagMode      = false
            root.tagInput     = ""
            root.tagSelIdx    = -1
            root._autoTagging = false
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
            "cat \"$HOME/.config/quickshell/wallpaper-tags.json\" 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root._tags = JSON.parse(this.text.trim()) } catch(e) { root._tags = {} }
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
        id: saveTagsProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: paletteProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: autoTagProc
        stdout: StdioCollector {
            onStreamFinished: {
                root._autoTagging = false
                const tagsStr = this.text.trim()
                if (!tagsStr) return
                const newTags = tagsStr.split(",").map(t => t.trim().toLowerCase()).filter(Boolean)
                const file = root._currentFile
                if (!file) return
                const updated = Object.assign({}, root._tags)
                const existing = updated[file] || []
                updated[file] = Array.from(new Set([...existing, ...newTags]))
                root._tags = updated
                root._saveWallpaperTags()
                const prevCatName = root.categories[root.selCatIdx]?.name || "all"
                root._buildCategories(prevCatName, file)
            }
        }
        stderr: StdioCollector {}
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
                            if (root.tagMode) {
                                const tags = root._currentFileTags
                                if (root.tagSelIdx >= 0) {
                                    // Browse existing tags to delete
                                    switch (event.key) {
                                        case Qt.Key_Left:
                                            if (tags.length) root.tagSelIdx = (root.tagSelIdx - 1 + tags.length) % tags.length
                                            break
                                        case Qt.Key_Right:
                                            if (tags.length) root.tagSelIdx = (root.tagSelIdx + 1) % tags.length
                                            break
                                        case Qt.Key_Delete:
                                        case Qt.Key_Backspace:
                                        case Qt.Key_Return:
                                        case Qt.Key_Enter:
                                            if (tags.length > 0) {
                                                root._toggleTag(root._currentFile, tags[root.tagSelIdx])
                                                const rem = root._currentFileTags
                                                root.tagSelIdx = rem.length > 0
                                                    ? Math.min(root.tagSelIdx, rem.length - 1) : -1
                                            }
                                            break
                                        case Qt.Key_Escape:
                                            root.tagMode = false; root.tagSelIdx = -1; break
                                        default:
                                            if (event.text.length > 0) {
                                                root.tagSelIdx = -1
                                                root.tagInput  = event.text
                                            }
                                    }
                                } else {
                                    // Type a new tag
                                    switch (event.key) {
                                        case Qt.Key_Escape:
                                            if (root._currentFileTags.length > 0) {
                                                root.tagSelIdx = 0; root.tagInput = ""
                                            } else {
                                                root.tagMode = false; root.tagInput = ""
                                            }
                                            break
                                        case Qt.Key_Backspace:
                                            if (root.tagInput.length > 0) {
                                                root.tagInput = root.tagInput.slice(0, -1)
                                            } else if (root._currentFileTags.length > 0) {
                                                root.tagSelIdx = 0
                                            } else {
                                                root.tagMode = false
                                            }
                                            break
                                        case Qt.Key_Return:
                                        case Qt.Key_Enter:
                                            if (root.tagInput.trim()) {
                                                root._toggleTag(root._currentFile, root.tagInput)
                                                root.tagInput  = ""
                                                root.tagSelIdx = 0
                                            } else {
                                                root.tagMode = false
                                            }
                                            break
                                        default:
                                            if (event.text.length > 0) root.tagInput += event.text
                                    }
                                }
                                event.accepted = true
                                return
                            }
                            switch (event.key) {
                                case Qt.Key_Left:   root.navLeft();    break
                                case Qt.Key_Right:  root.navRight();   break
                                case Qt.Key_Up:     root.navUp();      break
                                case Qt.Key_Down:   root.navDown();    break
                                case Qt.Key_T:
                                    root.tagInput  = ""
                                    root.tagSelIdx = root._currentFileTags.length > 0 ? 0 : -1
                                    root.tagMode   = true
                                    break
                                case Qt.Key_A:      root.autoTag();    break
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

                                // Auto-tagging spinner on current row
                                Text {
                                    visible: row.isCurrent && root._autoTagging
                                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 }
                                    text: "…"
                                    color: Theme.green
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
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
                                              + (root.catOffsets[row.index] || 0)

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
                                            source: hList.n > 0
                                                ? "file://" + root.wpDir + hList.cat.files[thumb.ri]
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

                                        // Existing tag chips — always visible on active thumb
                                        Flow {
                                            visible: thumb.active && root._currentFileTags.length > 0
                                            anchors {
                                                left: parent.left; right: parent.right
                                                bottom: parent.bottom
                                                leftMargin: 8; rightMargin: 8; bottomMargin: 7
                                            }
                                            spacing: 4
                                            layoutDirection: Qt.RightToLeft

                                            Repeater {
                                                model: root._currentFileTags
                                                Rectangle {
                                                    required property string modelData
                                                    required property int index
                                                    property bool sel: root.tagMode && root.tagSelIdx === index

                                                    height: 17
                                                    width: chipTxt.implicitWidth + 10
                                                    radius: 4
                                                    color: sel ? Qt.rgba(0.85, 0.15, 0.15, 0.88)
                                                               : Qt.rgba(0, 0, 0, 0.58)
                                                    border.color: sel ? "#ff5555" : Theme.purple
                                                    border.width: sel ? 1.5 : 0.8
                                                    Behavior on color       { ColorAnimation { duration: 120 } }
                                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                                    Text {
                                                        id: chipTxt
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        color: "white"
                                                        font.family: "JetBrains Mono"
                                                        font.pixelSize: 9
                                                    }
                                                }
                                            }
                                        }

                                        // Input mode bar (type new tag)
                                        Rectangle {
                                            visible: thumb.active && root.tagMode && root.tagSelIdx < 0
                                            anchors { left: parent.left; right: parent.right; top: parent.top }
                                            height: 24
                                            color: Qt.rgba(0, 0, 0, 0.72)
                                            Text {
                                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                                text: "+" + root.tagInput + "█"
                                                color: Theme.green
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 10
                                            }
                                        }

                                        // Browse mode bar (select tag to remove)
                                        Rectangle {
                                            visible: thumb.active && root.tagMode && root.tagSelIdx >= 0
                                            anchors { left: parent.left; right: parent.right; top: parent.top }
                                            height: 24
                                            color: Qt.rgba(0, 0, 0, 0.72)
                                            Text {
                                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                                text: "← → select  del: remove  type: add"
                                                color: Theme.subtext
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 9
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
}
