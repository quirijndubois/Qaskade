import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import "../"
import "../components"

// The settings overlay. Not a window of its own: shell.qml moves this item
// into the center notch of the focused monitor, which expands to fit it.
Item {
    id: root
    implicitWidth: 560
    implicitHeight: 480

    // Driven by shell.qml; replaces window visibility.
    property bool open: false
    signal closeRequested()

    property string page: "main"
    property string activeSubPage: "appearance"
    property var navStack: []
    property string _pendingPage: "main"
    property int selectedIndex: 0
    property string searchQuery: ""
    property int selectedSearchIndex: 0
    property var wallpaperFiles: []
    property string homeDir: ""
    property bool isPathMode: searchQuery.length > 0 && (searchQuery[0] === "/" || searchQuery.startsWith("~/"))
    property string pathExpanded: (searchQuery.startsWith("~/") && homeDir) ? homeDir + searchQuery.substring(1) : searchQuery
    property string pathDir: {
        if (!isPathMode) return ""
        const i = pathExpanded.lastIndexOf("/")
        return pathExpanded.substring(0, i + 1)
    }
    property string pathFilter: {
        if (!isPathMode) return ""
        const i = pathExpanded.lastIndexOf("/")
        return pathExpanded.substring(i + 1).toLowerCase()
    }
    property var fileEntries: []
    onPathDirChanged: {
        root.fileEntries = []
        if (root.pathDir) {
            lsProc.command = ["ls", "-1p", "--color=never", "--", root.pathDir]
            lsProc.running = false
            lsProc.running = true
        }
    }
    property var appsList: []
    property var bluetoothDevices: []
    property var wifiNetworks: []
    property bool wifiScanning: false
    property bool wifiPasswordMode: false
    property string wifiPasswordInput: ""
    property var wifiPendingNetwork: null
    property string wifiError: ""
    property string currentLayout: "dwindle"
    property string monitorName: ""
    property string wallpapersDir: homeDir ? homeDir + "/wallpapers/" : ""
    property var systemMonitors: []
    property real mouseSensitivity: 0.0
    property bool naturalScroll: true
    property real scrollFactor: 0.4
    property bool blurEnabled: true
    property int selectedMonitorIdx: 0
    property var workspaceRules: []
    property bool vimSearchMode: false
    property bool immediateSearch: false
    property var wallpaperTags: {}
    property string wpTagHints:      ""
    property int    wpMinCat:        1
    property bool   wpTagging:       false
    property bool   wpHintsEditMode: false
    property string wpHintsInput:    ""
    property int    wpTagged:        0
    property int    wpTotal:         0
    property bool   wpGenThumb:      false
    property bool   wpOllamaOk:      false
    property var    wpOllamaModels:  []
    property string wpVisionModel:   "moondream"
    property int    wpVisionModelIdx: 0
    property string wpTextModel:     "qwen2.5-coder:7b"
    property int    wpTextModelIdx:  0


    property var systemSettingItems: {
        const items = []
        items.push({ type: "section", label: "Displays" })
        for (const m of root.systemMonitors) {
            items.push({ type: "scale", label: m.name, sub: m.width + " × " + m.height, monitor: m })
            items.push({ type: "monitor_toggle", label: "Enabled", sub: m.name, monitor: m })
        }
        items.push({ type: "nav", label: "Arrangement", page: "monitor_layout" })
        items.push({ type: "font_size", label: "Bar text size" })
        items.push({ type: "section", label: "Input" })
        items.push({ type: "sensitivity",    label: "Pointer speed" })
        items.push({ type: "natural_scroll", label: "Natural scrolling" })
        items.push({ type: "scroll_factor",  label: "Scroll speed" })
        items.push({ type: "section", label: "Windows" })
        items.push({ type: "nav", label: "Tiling layout", page: "layout" })
        items.push({ type: "blur_toggle", label: "Blur" })
        items.push({ type: "section", label: "Keyboard" })
        items.push({ type: "vim_binds", label: "Vim keys" })
        return items
    }

    property string _pendingSystemLabel: ""

    onSystemSettingItemsChanged: {
        if (root.page === "system" && root._pendingSystemLabel !== "") {
            const idx = root.systemSettingItems.findIndex(s => s.label === _pendingSystemLabel)
            if (idx >= 0) {
                root.selectedIndex = idx
                Qt.callLater(() => sysListView.positionViewAtIndex(idx, ListView.Contain))
            }
            root._pendingSystemLabel = ""
        }
    }

    onPageChanged: {
        if (page !== "system") root._pendingSystemLabel = ""
        if (page !== "main") activeSubPage = page
        if (page === "bluetooth") btListProc.running = true
        if (page === "wifi") { root.wifiScanning = true; wifiListProc.running = true }
        if (page !== "wifi") { root.wifiPasswordMode = false; root.wifiPasswordInput = ""; root.wifiPendingNetwork = null; root.wifiError = "" }
        if (page === "layout") layoutQueryProc.running = true
        if (page === "clipboard") { clipDaemonProc.running = true; clipListProc.running = true }
        if (page === "wallpapers") { loadWpConfigProc.running = false; loadWpConfigProc.running = true }
        if (page !== "wallpapers") { root.wpHintsEditMode = false; root.wpHintsInput = "" }
        if (page === "monitor_layout") {
            root.selectedMonitorIdx = 0
            wsRulesProc.running = false
            wsRulesProc.running = true
        }
        if (page === "system") {
            sysMonitorsProc.running = false
            sysMonitorsProc.running = true
            sysSensProc.running = false
            sysSensProc.running = true
        }
    }

    onSearchQueryChanged: {
        selectedSearchIndex = 0
    }

    function fuzzyScore(query, str) {
        query = query.toLowerCase()
        str = str.toLowerCase()
        if (str === query) return 100
        if (str.startsWith(query)) return 50
        let qi = 0
        for (let i = 0; i < str.length && qi < query.length; i++) {
            if (str[i] === query[qi]) qi++
        }
        return qi === query.length ? 10 : 0
    }

    function cleanExec(exec) {
        return exec.replace(/\s*%[a-zA-Z]/g, "").replace(/\s+/g, " ").trim()
    }

    function resolveIcon(icon) {
        if (!icon) return ""
        if (icon.startsWith("/")) return "file://" + icon
        return Quickshell.iconPath(icon, true)
    }

    property var searchResults: {
        if (!searchQuery) return []
        if (isPathMode) {
            const entries = fileEntries
            const f = pathFilter
            if (!f) return entries.map(e => ({ type: "file", label: e.name + (e.isDir ? "/" : ""), name: e.name, isDir: e.isDir, path: e.path }))
            return entries
                .filter(e => e.name.toLowerCase().includes(f))
                .map(e => ({ type: "file", label: e.name + (e.isDir ? "/" : ""), name: e.name, isDir: e.isDir, path: e.path,
                              score: e.name.toLowerCase().startsWith(f) ? 50 : 10 }))
                .sort((a, b) => (b.score || 0) - (a.score || 0))
        }
        const results = []
        for (const m of mainItems) {
            const s = Math.max(root.fuzzyScore(searchQuery, m.label), root.fuzzyScore(searchQuery, m.id))
            if (s > 0) results.push({ score: s, type: "menu", label: m.label, id: m.id })
        }
        for (const m of appearanceItems) {
            const s = Math.max(root.fuzzyScore(searchQuery, m.label), root.fuzzyScore(searchQuery, m.id))
            if (s > 0) results.push({ score: s, type: "menu", label: m.label, id: m.id })
        }
        for (const f of wallpaperFiles) {
            const name = f.replace(/\.[^.]+$/, "")
            let s = root.fuzzyScore(searchQuery, name)
            for (const tag of (root.wallpaperTags[f] || []))
                s = Math.max(s, root.fuzzyScore(searchQuery, tag))
            if (s > 0) results.push({ score: s, type: "wallpaper", label: name, file: f })
        }
        for (const p of paletteOptions) {
            if (p.type === "section") continue
            const s = Math.max(root.fuzzyScore(searchQuery, p.label), root.fuzzyScore(searchQuery, p.id))
            if (s > 0) results.push({ score: s, type: "palette", label: p.label, id: p.id, swatches: p.swatches })
        }
        for (const a of appsList) {
            const s = root.fuzzyScore(searchQuery, a.name)
            if (s > 0) results.push({ score: s, type: "app", label: a.name, exec: a.exec, icon: a.icon, terminal: a.terminal })
        }
        for (const d of bluetoothDevices) {
            const s = root.fuzzyScore(searchQuery, d.name)
            if (s > 0) results.push({ score: s, type: "bluetooth", label: d.name, mac: d.mac, connected: d.connected, paired: d.paired })
        }
        for (const n of wifiNetworks) {
            const s = root.fuzzyScore(searchQuery, n.ssid)
            if (s > 0) results.push({ score: s, type: "wifi", label: n.ssid, signal: n.signal, security: n.security, inUse: n.inUse })
        }
        for (const l of layoutOptions) {
            const s = Math.max(root.fuzzyScore(searchQuery, l.label), root.fuzzyScore(searchQuery, l.desc))
            if (s > 0) results.push({ score: s, type: "layout", label: l.label, id: l.id, desc: l.desc })
        }
        for (const c of clipboardItems) {
            const s = root.fuzzyScore(searchQuery, c.preview)
            if (s > 0) results.push({ score: s, type: "clipboard", label: c.preview, line: c.line })
        }
        for (const s of root.systemSettingItems) {
            if (s.type === "section") continue
            const s2 = Math.max(root.fuzzyScore(searchQuery, s.label), s.type === "scale" ? root.fuzzyScore(searchQuery, s.monitor.name) : 0)
            if (s2 > 0) results.push({ score: s2, type: "system_item", label: s.label, sub: s.sub || "", page: "system", index: root.systemSettingItems.indexOf(s) })
        }
        for (const b of root.barModules) {
            const s2 = Math.max(root.fuzzyScore(searchQuery, b.label), root.fuzzyScore(searchQuery, b.id))
            if (s2 > 0) results.push({ score: s2, type: "bar_module", label: b.label, id: b.id, page: "bar", index: root.barModules.indexOf(b) })
        }
        for (const em of root.emojiList) {
            const s2 = root.fuzzyScore(searchQuery, em.n)
            if (s2 > 0) results.push({ score: s2, type: "emoji", label: em.n, e: em.e })
        }
        results.sort((a, b) => b.score - a.score)
        if (results.length === 0 && !mathResult) results.push({ type: "web", label: searchQuery })
        if (mathResult) results.unshift({ type: "math", label: mathResult.result, expr: mathResult.expr })
        return results
    }

    property var mathResult: {
        const q = searchQuery.trim()
        if (!q || isPathMode) return null
        if (!/^[\d\s\+\-\*\/\%\.\(\)\^]+$/.test(q)) return null
        if (!/[\+\-\*\/\%\^]/.test(q)) return null
        try {
            const val = eval(q.replace(/\^/g, "**"))
            if (typeof val !== "number" || !isFinite(val)) return null
            const formatted = Number.isInteger(val) ? String(val) : parseFloat(val.toPrecision(10)).toString()
            return { expr: q, result: formatted }
        } catch(e) { return null }
    }

    readonly property var paletteOptions: [
        { type: "section", label: "Dark" },
        { id: "mocha",       label: "Catppuccin Mocha",      swatches: ["#89b4fa","#a6e3a1","#f38ba8","#f9e2af","#94e2d5","#cba6f7"] },
        { id: "macchiato",   label: "Catppuccin Macchiato",  swatches: ["#8aadf4","#a6da95","#ed8796","#eed49f","#8bd5ca","#c6a0f6"] },
        { id: "frappe",      label: "Catppuccin Frappé",     swatches: ["#8caaee","#a6d189","#e78284","#e5c890","#81c8be","#ca9ee6"] },
        { id: "tokyo-night", label: "Tokyo Night",           swatches: ["#7aa2f7","#9ece6a","#f7768e","#e0af68","#73daca","#bb9af7"] },
        { id: "gruvbox",     label: "Gruvbox",               swatches: ["#83a598","#b8bb26","#fb4934","#fabd2f","#8ec07c","#d3869b"] },
        { id: "nord",        label: "Nord",                  swatches: ["#81a1c1","#a3be8c","#bf616a","#ebcb8b","#88c0d0","#b48ead"] },
        { id: "dracula",     label: "Dracula",               swatches: ["#6272a4","#50fa7b","#ff5555","#f1fa8c","#8be9fd","#bd93f9"] },
        { id: "rosepine",    label: "Rosé Pine",             swatches: ["#9ccfd8","#31748f","#eb6f92","#f6c177","#ebbcba","#c4a7e7"] },
        { id: "onedark",     label: "One Dark",              swatches: ["#61afef","#98c379","#e06c75","#e5c07b","#56b6c2","#c678dd"] },
        { id: "everforest",  label: "Everforest",            swatches: ["#7fbbb3","#a7c080","#e67e80","#dbbc7f","#83c092","#d699b6"] },
        { id: "solarized",   label: "Solarized Dark",        swatches: ["#268bd2","#859900","#dc322f","#b58900","#2aa198","#6c71c4"] },
        { type: "section", label: "Light" },
        { id: "latte",       label: "Catppuccin Latte",      swatches: ["#1e66f5","#40a02b","#d20f39","#df8e1d","#179299","#8839ef"] },
        { id: "solarized-light", label: "Solarized Light",   swatches: ["#268bd2","#859900","#dc322f","#b58900","#2aa198","#6c71c4"] },
        { id: "gruvbox-light", label: "Gruvbox Light",       swatches: ["#458588","#689d6a","#cc241d","#d79921","#689d6a","#b16286"] },
        { id: "nord-light",  label: "Nord Light",            swatches: ["#5e81ac","#a3be8c","#bf616a","#ebcb8b","#88c0d0","#b48ead"] },
        { id: "rosepine-dawn", label: "Rosé Pine Dawn",      swatches: ["#286983","#d7827e","#b4637a","#ea9d34","#56949f","#907aa9"] },
        { id: "onelight",    label: "One Light",             swatches: ["#4078f2","#50a14f","#e45649","#c18401","#0184bc","#a626a4"] },
    ]

    readonly property var layoutOptions: [
        { id: "dwindle",   label: "Dwindle",   desc: "Binary spiral tiling" },
        { id: "master",    label: "Master",    desc: "One main window, a stack beside it" },
        { id: "scrolling", label: "Scrolling", desc: "Columns on an endless horizontal strip" },
        { id: "monocle",   label: "Monocle",   desc: "One window fills the screen" },
    ]

    readonly property var barModules: [
        { id: "showMenu",       label: "Menu button" },
        { id: "showWorkspaces", label: "Workspaces" },
        { id: "showClock",      label: "Clock" },
        { id: "showMusic",      label: "Now playing" },
        { id: "showCpu",        label: "CPU" },
        { id: "showMemory",     label: "Memory" },
        { id: "showGpu",        label: "GPU" },
        { id: "showInhibit",    label: "Keep awake" },
        { id: "showTray",       label: "System tray" },
        { id: "showNetwork",    label: "Network" },
        { id: "showBluetooth",  label: "Bluetooth" },
        { id: "showAudio",      label: "Sound" },
        { id: "showBattery",    label: "Battery" },
    ]

    property var mainItems: [
        { id: "appearance",    label: "Appearance",    icon: "palette" },
        { id: "apps",          label: "Applications",  icon: "apps" },
        { id: "bluetooth",     label: "Bluetooth",     icon: "bluetooth" },
        { id: "wifi",          label: "Wi-Fi",         icon: "wifi" },
        { id: "clipboard",     label: "Clipboard",     icon: "clipboard" },
        { id: "notifications", label: "Notifications", icon: "bell" },
        { id: "emoji",         label: "Emoji",         icon: "emoji" },
        { id: "system",        label: "System",        icon: "cog" },
        { id: "power",         label: "Power",         icon: "power" },
    ]

    readonly property var powerItems: [
        { id: "lock",      label: "Lock",      icon: "lock",      cmd: ["quickshell", "ipc", "-c", "default", "call", "lock", "lock"] },
        { id: "suspend",   label: "Suspend",   icon: "sleep",     cmd: ["systemctl", "suspend"] },
        { id: "hibernate", label: "Hibernate", icon: "hibernate", cmd: ["systemctl", "hibernate"] },
        { id: "logout",    label: "Log out",   icon: "logout",    cmd: ["sh", "-c", "hyprctl dispatch 'hl.dsp.exit()'"] },
        { id: "reboot",    label: "Restart",   icon: "restart",   cmd: ["systemctl", "reboot"] },
        { id: "shutdown",  label: "Shut down", icon: "power",     cmd: ["systemctl", "poweroff"], destructive: true },
    ]

    readonly property var appearanceItems: [
        { id: "palette",    label: "Color palette",  icon: "palette" },
        { id: "bar",        label: "Bar layout",     icon: "viewDashboard" },
        { id: "wallpapers", label: "Wallpaper tags", icon: "tag" },
    ]


    readonly property var emojiList: [
        // smileys
        { e: "😀", n: "grinning face" },
        { e: "😃", n: "grinning face with big eyes" },
        { e: "😄", n: "grinning face with smiling eyes" },
        { e: "😁", n: "beaming face" },
        { e: "😆", n: "grinning squinting face" },
        { e: "😅", n: "grinning face with sweat" },
        { e: "🤣", n: "rolling on floor laughing" },
        { e: "😂", n: "face with tears of joy" },
        { e: "🙂", n: "slightly smiling face" },
        { e: "😉", n: "winking face" },
        { e: "😊", n: "smiling face with smiling eyes" },
        { e: "😇", n: "smiling face with halo" },
        { e: "🥰", n: "smiling face with hearts" },
        { e: "😍", n: "heart eyes" },
        { e: "🤩", n: "star struck" },
        { e: "😘", n: "face blowing a kiss" },
        { e: "😋", n: "face savoring food" },
        { e: "😎", n: "cool face with sunglasses" },
        { e: "😏", n: "smirking face" },
        { e: "😒", n: "unamused face" },
        { e: "😔", n: "pensive face" },
        { e: "😟", n: "worried face" },
        { e: "🙁", n: "slightly frowning face" },
        { e: "😢", n: "crying face" },
        { e: "😭", n: "loudly crying face" },
        { e: "😤", n: "face with steam from nose" },
        { e: "😠", n: "angry face" },
        { e: "😡", n: "enraged face" },
        { e: "🤬", n: "face with symbols on mouth" },
        { e: "🤯", n: "exploding head" },
        { e: "😱", n: "face screaming in fear" },
        { e: "😨", n: "fearful face" },
        { e: "😰", n: "anxious face with sweat" },
        { e: "🤔", n: "thinking face" },
        { e: "😬", n: "grimacing face" },
        { e: "😶", n: "face without mouth" },
        { e: "🥱", n: "yawning face" },
        { e: "😴", n: "sleeping face" },
        { e: "😷", n: "face with medical mask" },
        { e: "🤒", n: "face with thermometer" },
        { e: "🤕", n: "face with head bandage" },
        { e: "🤢", n: "nauseated face" },
        { e: "🤧", n: "sneezing face" },
        { e: "😵", n: "dizzy face" },
        { e: "🤑", n: "money mouth face" },
        { e: "😈", n: "smiling face with horns" },
        { e: "💀", n: "skull" },
        { e: "👻", n: "ghost" },
        { e: "👽", n: "alien" },
        { e: "🤖", n: "robot" },
        { e: "💩", n: "pile of poo" },
        // gestures
        { e: "👋", n: "waving hand" },
        { e: "✋", n: "raised hand" },
        { e: "👌", n: "ok hand" },
        { e: "✌️", n: "victory hand" },
        { e: "🤞", n: "crossed fingers" },
        { e: "👍", n: "thumbs up" },
        { e: "👎", n: "thumbs down" },
        { e: "✊", n: "raised fist" },
        { e: "👊", n: "oncoming fist" },
        { e: "👏", n: "clapping hands" },
        { e: "🙌", n: "raising hands" },
        { e: "🙏", n: "folded hands" },
        { e: "💪", n: "flexed biceps" },
        { e: "🤝", n: "handshake" },
        { e: "🖐️", n: "hand with fingers splayed" },
        { e: "🤙", n: "call me hand" },
        { e: "👈", n: "pointing left" },
        { e: "👉", n: "pointing right" },
        { e: "👆", n: "pointing up" },
        { e: "👇", n: "pointing down" },
        // animals
        { e: "🐶", n: "dog face" },
        { e: "🐱", n: "cat face" },
        { e: "🐭", n: "mouse face" },
        { e: "🐹", n: "hamster" },
        { e: "🐰", n: "rabbit face" },
        { e: "🦊", n: "fox" },
        { e: "🐻", n: "bear" },
        { e: "🐼", n: "panda" },
        { e: "🐨", n: "koala" },
        { e: "🐯", n: "tiger face" },
        { e: "🦁", n: "lion" },
        { e: "🐮", n: "cow face" },
        { e: "🐷", n: "pig face" },
        { e: "🐸", n: "frog" },
        { e: "🙈", n: "see no evil monkey" },
        { e: "🙉", n: "hear no evil monkey" },
        { e: "🙊", n: "speak no evil monkey" },
        { e: "🐔", n: "chicken" },
        { e: "🦆", n: "duck" },
        { e: "🦅", n: "eagle" },
        { e: "🦉", n: "owl" },
        { e: "🦋", n: "butterfly" },
        { e: "🐝", n: "honeybee" },
        { e: "🐛", n: "caterpillar" },
        { e: "🐌", n: "snail" },
        { e: "🐞", n: "lady beetle" },
        { e: "🦈", n: "shark" },
        { e: "🐬", n: "dolphin" },
        { e: "🐋", n: "whale" },
        // nature
        { e: "🌸", n: "cherry blossom" },
        { e: "🌺", n: "hibiscus" },
        { e: "🌻", n: "sunflower" },
        { e: "🌹", n: "rose" },
        { e: "🌷", n: "tulip" },
        { e: "🍀", n: "four leaf clover" },
        { e: "🌿", n: "herb" },
        { e: "🍃", n: "leaf fluttering in wind" },
        { e: "🍂", n: "fallen leaf" },
        { e: "🍁", n: "maple leaf" },
        { e: "🌱", n: "seedling" },
        { e: "🌵", n: "cactus" },
        { e: "🌴", n: "palm tree" },
        { e: "🌳", n: "deciduous tree" },
        { e: "🌲", n: "evergreen tree" },
        { e: "🌊", n: "water wave" },
        { e: "🔥", n: "fire" },
        { e: "⭐", n: "star" },
        { e: "🌟", n: "glowing star" },
        { e: "✨", n: "sparkles" },
        { e: "💫", n: "dizzy" },
        { e: "⚡", n: "lightning" },
        { e: "🌈", n: "rainbow" },
        { e: "🌙", n: "crescent moon" },
        { e: "☀️", n: "sun" },
        { e: "⛄", n: "snowman" },
        { e: "❄️", n: "snowflake" },
        // food & drink
        { e: "🍎", n: "red apple" },
        { e: "🍊", n: "tangerine" },
        { e: "🍋", n: "lemon" },
        { e: "🍇", n: "grapes" },
        { e: "🍓", n: "strawberry" },
        { e: "🍒", n: "cherries" },
        { e: "🍌", n: "banana" },
        { e: "🍉", n: "watermelon" },
        { e: "🥝", n: "kiwi fruit" },
        { e: "🍅", n: "tomato" },
        { e: "🥑", n: "avocado" },
        { e: "🌽", n: "ear of corn" },
        { e: "🥦", n: "broccoli" },
        { e: "🥕", n: "carrot" },
        { e: "🥔", n: "potato" },
        { e: "🍕", n: "pizza" },
        { e: "🍔", n: "hamburger" },
        { e: "🌮", n: "taco" },
        { e: "🌯", n: "burrito" },
        { e: "🍜", n: "steaming bowl" },
        { e: "🍣", n: "sushi" },
        { e: "🍦", n: "soft ice cream" },
        { e: "🎂", n: "birthday cake" },
        { e: "🍰", n: "shortcake" },
        { e: "🧁", n: "cupcake" },
        { e: "🍫", n: "chocolate bar" },
        { e: "🍭", n: "lollipop" },
        { e: "☕", n: "hot beverage" },
        { e: "🍵", n: "teacup" },
        { e: "🍺", n: "beer mug" },
        { e: "🍻", n: "clinking beer mugs" },
        { e: "🥂", n: "clinking glasses" },
        { e: "🍷", n: "wine glass" },
        { e: "🥃", n: "tumbler glass" },
        // travel & places
        { e: "🚗", n: "automobile" },
        { e: "🚕", n: "taxi" },
        { e: "🚌", n: "bus" },
        { e: "✈️", n: "airplane" },
        { e: "🚀", n: "rocket" },
        { e: "🛸", n: "flying saucer" },
        { e: "🚢", n: "ship" },
        { e: "⛵", n: "sailboat" },
        { e: "🏠", n: "house" },
        { e: "🏢", n: "office building" },
        { e: "🏥", n: "hospital" },
        { e: "🏦", n: "bank" },
        { e: "🏨", n: "hotel" },
        { e: "🌆", n: "cityscape at dusk" },
        { e: "🌉", n: "bridge at night" },
        { e: "⛺", n: "tent" },
        { e: "🏔️", n: "snow capped mountain" },
        { e: "🏖️", n: "beach with umbrella" },
        { e: "🏝️", n: "desert island" },
        { e: "🗺️", n: "world map" },
        // activities & sports
        { e: "⚽", n: "soccer ball" },
        { e: "🏀", n: "basketball" },
        { e: "🏈", n: "american football" },
        { e: "⚾", n: "baseball" },
        { e: "🎾", n: "tennis" },
        { e: "🏐", n: "volleyball" },
        { e: "🎱", n: "billiards" },
        { e: "🎮", n: "video game" },
        { e: "🎲", n: "game die" },
        { e: "🎭", n: "performing arts" },
        { e: "🎨", n: "artist palette" },
        { e: "🎬", n: "clapper board" },
        { e: "🎤", n: "microphone" },
        { e: "🎧", n: "headphones" },
        { e: "🎼", n: "musical score" },
        { e: "🎹", n: "musical keyboard" },
        { e: "🥁", n: "drum" },
        { e: "🎸", n: "guitar" },
        { e: "🎺", n: "trumpet" },
        { e: "🎻", n: "violin" },
        { e: "🎪", n: "circus tent" },
        { e: "🏆", n: "trophy" },
        { e: "🥇", n: "first place medal" },
        { e: "🥈", n: "second place medal" },
        { e: "🥉", n: "third place medal" },
        { e: "🎯", n: "bullseye" },
        // objects
        { e: "💻", n: "laptop" },
        { e: "🖥️", n: "desktop computer" },
        { e: "📱", n: "mobile phone" },
        { e: "📷", n: "camera" },
        { e: "📺", n: "television" },
        { e: "📻", n: "radio" },
        { e: "🔋", n: "battery" },
        { e: "💡", n: "light bulb" },
        { e: "🔦", n: "flashlight" },
        { e: "📝", n: "memo" },
        { e: "📄", n: "page" },
        { e: "📊", n: "bar chart" },
        { e: "📌", n: "pushpin" },
        { e: "📍", n: "round pushpin" },
        { e: "✂️", n: "scissors" },
        { e: "🔒", n: "locked" },
        { e: "🔓", n: "unlocked" },
        { e: "🔑", n: "key" },
        { e: "🔨", n: "hammer" },
        { e: "🔧", n: "wrench" },
        { e: "⚙️", n: "gear" },
        { e: "🔬", n: "microscope" },
        { e: "🔭", n: "telescope" },
        { e: "📡", n: "satellite antenna" },
        { e: "💉", n: "syringe" },
        { e: "💊", n: "pill" },
        { e: "🚪", n: "door" },
        { e: "🎁", n: "wrapped gift" },
        { e: "🎀", n: "ribbon" },
        { e: "🎉", n: "party popper" },
        { e: "🎊", n: "confetti ball" },
        { e: "💰", n: "money bag" },
        { e: "💳", n: "credit card" },
        { e: "📦", n: "package" },
        { e: "🗑️", n: "wastebasket" },
        // symbols & hearts
        { e: "❤️", n: "red heart" },
        { e: "🧡", n: "orange heart" },
        { e: "💛", n: "yellow heart" },
        { e: "💚", n: "green heart" },
        { e: "💙", n: "blue heart" },
        { e: "💜", n: "purple heart" },
        { e: "🖤", n: "black heart" },
        { e: "🤍", n: "white heart" },
        { e: "💔", n: "broken heart" },
        { e: "❣️", n: "heart exclamation" },
        { e: "💕", n: "two hearts" },
        { e: "💖", n: "sparkling heart" },
        { e: "💘", n: "heart with arrow" },
        { e: "♻️", n: "recycling symbol" },
        { e: "✅", n: "check mark button" },
        { e: "❌", n: "cross mark" },
        { e: "⭕", n: "hollow red circle" },
        { e: "⚠️", n: "warning" },
        { e: "💯", n: "hundred points" },
        { e: "❓", n: "question mark" },
        { e: "❗", n: "exclamation mark" },
        { e: "‼️", n: "double exclamation mark" },
        { e: "🌐", n: "globe with meridians" },
        { e: "🚩", n: "triangular flag" },
    ]

    function copyEmoji(e) {
        clipProc.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "--", e]
        clipProc.running = false
        clipProc.running = true
        root.notifyClipboardCopy()
    }

    function navigate(pg) {
        _pendingPage = pg
        if (open) {
            var _isSearch = (pg === "search")
            immediateSearch = _isSearch
            page = _isSearch ? "main" : pg
            navStack = []
            selectedIndex = 0
            searchQuery = ""
            vimSearchMode = false
        }
    }

    onOpenChanged: {
        if (open) {
            monitorName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            var _isSearch = _pendingPage === "search"
            immediateSearch = _isSearch
            page = _isSearch ? "main" : _pendingPage
            navStack = []
            selectedIndex = 0
            searchQuery = ""
            vimSearchMode = false
            wifiPasswordMode = false
            wifiPasswordInput = ""
            wifiPendingNetwork = null
            wifiError = ""
            Qt.callLater(() => keyNav.forceActiveFocus())
        } else {
            _pendingPage = "main"
        }
    }

    // ── Discovery processes ────────────────────────────────────
    Process {
        id: listProc
        command: ["sh", "-c", "ls \"$HOME/wallpapers/\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpaperFiles = this.text.trim().split("\n").filter(f => f.length > 0)
            }
        }
    }

    Process {
        id: appsProc
        command: ["sh", "-c", "python3 \"$HOME/.config/quickshell/scripts/list_apps.py\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                    root.appsList = lines.map(line => {
                        const parts = line.split("\t")
                        return { name: parts[0] || "", exec: parts[1] || "", icon: parts[2] || "", terminal: parts[3] === "true" }
                    }).filter(a => a.name && a.exec)
            }
        }
    }

    Timer {
        id: appsAutoRefreshTimer
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            if (!appsProc.running) {
                appsProc.running = true
            }
        }
    }

    Process {
        id: awwwProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: extractPaletteProc
        stderr: StdioCollector {}
        stdout: StdioCollector {
            onStreamFinished: {
                root.extractingPalette = false
                const parts = this.text.trim().split(' ')
                if (parts.length !== 11) return
                Theme._target = { base: parts[0], surface: parts[1], border: parts[2], text: parts[3], subtext: parts[4], blue: parts[5], green: parts[6], red: parts[7], yellow: parts[8], teal: parts[9], purple: parts[10] }
                Theme.base    = parts[0]
                Theme.surface = parts[1]
                Theme.border  = parts[2]
                Theme.text    = parts[3]
                Theme.subtext = parts[4]
                Theme.blue    = parts[5]
                Theme.green   = parts[6]
                Theme.red     = parts[7]
                Theme.yellow  = parts[8]
                Theme.teal    = parts[9]
                Theme.purple  = parts[10]
                Theme.saveCustomPaletteColors(parts)
                Theme.updateKittyTheme()
                Theme.updateFirefoxTheme()
                Theme.updateSystemColorScheme()
                Theme.updateHyprlandBorder()
            }
        }
        onRunningChanged: { if (!running) root.extractingPalette = false }
    }

    Process {
        id: btListProc
        command: ["sh", "-c",
            "conn=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}'); " +
            "pair=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}'); " +
            "bluetoothctl devices 2>/dev/null | while IFS= read -r line; do " +
            "  mac=$(printf '%s' \"$line\" | awk '{print $2}'); " +
            "  name=$(printf '%s' \"$line\" | cut -d' ' -f3-); " +
            "  [ -z \"$mac\" ] && continue; " +
            "  c=no; printf '%s\\n' \"$conn\" | grep -qF \"$mac\" && c=yes; " +
            "  p=no; printf '%s\\n' \"$pair\" | grep -qF \"$mac\" && p=yes; " +
            "  printf '%s\\t%s\\t%s\\t%s\\n' \"$mac\" \"$name\" \"$c\" \"$p\"; " +
            "done"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                root.bluetoothDevices = lines.map(line => {
                    const parts = line.split("\t")
                    return { mac: parts[0] || "", name: parts[1] || "", connected: parts[2] === "yes", paired: parts[3] === "yes" }
                }).filter(d => d.mac && d.name)
            }
        }
    }

    Process {
        id: btActionProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onRunningChanged: {
            if (!running) btListProc.running = true
        }
    }

    function toggleBluetooth(device) {
        if (btActionProc.running) return
        btActionProc.command = ["bluetoothctl", device.connected ? "disconnect" : "connect", device.mac]
        btActionProc.running = true
    }

    Process {
        id: wifiListProc
        command: ["python3", "-c",
            "import subprocess\n" +
            "def run(*c): return subprocess.run(list(c), capture_output=True, text=True).stdout\n" +
            "al = run('nmcli','-e','no','-t','-f','ACTIVE,SSID','dev','wifi').split('\\n')\n" +
            "active = next((':'.join(l.split(':')[1:]) for l in al if l.startswith('yes:')), '')\n" +
            "known = set(run('nmcli','-e','no','-t','-f','NAME','connection','show').strip().split('\\n'))\n" +
            "seen = set()\n" +
            "for l in run('nmcli','-e','no','-t','-f','SSID,SIGNAL,SECURITY','dev','wifi','list').strip().split('\\n'):\n" +
            " if not l: continue\n" +
            " p = l.split(':')\n" +
            " if len(p) < 3: continue\n" +
            " sec = p[-1]; sig = p[-2]; ssid = ':'.join(p[:-2])\n" +
            " if not ssid or not sig.isdigit() or ssid in seen: continue\n" +
            " seen.add(ssid)\n" +
            " iu = 'yes' if ssid == active else 'no'\n" +
            " kn = 'yes' if ssid in known else 'no'\n" +
            " print(iu + '\\t' + ssid + '\\t' + sig + '\\t' + sec + '\\t' + kn)\n"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const nets = []
                for (const line of this.text.trim().split("\n")) {
                    if (!line) continue
                    const p = line.split("\t")
                    if (p.length < 5) continue
                    const inUse = p[0] === "yes"
                    const ssid = p[1]
                    const signal = parseInt(p[2])
                    const security = p[3]
                    const known = p[4] === "yes"
                    if (!ssid || isNaN(signal)) continue
                    nets.push({ ssid, signal, security, inUse, known })
                }
                nets.sort((a, b) => (a.inUse !== b.inUse) ? (a.inUse ? -1 : 1) : b.signal - a.signal)
                root.wifiNetworks = nets
                root.wifiScanning = false
            }
        }
    }

    Process {
        id: wifiActionProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg) { root.wifiError = msg; wifiErrorTimer.restart() }
            }
        }
        onRunningChanged: {
            if (!running) { root.wifiScanning = true; wifiListProc.running = true }
        }
    }

    function connectWifi(network) {
        if (wifiActionProc.running) return
        if (network.inUse) {
            wifiActionProc.command = ["sh", "-c",
                "iface=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2==\"wifi\"{print $1; exit}'); " +
                "nmcli dev disconnect \"$iface\" 2>/dev/null"
            ]
        } else {
            wifiActionProc.command = ["nmcli", "--wait", "15", "dev", "wifi", "connect", network.ssid]
        }
        root.wifiScanning = true
        wifiActionProc.running = true
    }

    function connectWifiPassword(network, password) {
        if (wifiActionProc.running) return
        wifiActionProc.command = password === ""
            ? ["nmcli", "--wait", "15", "dev", "wifi", "connect", network.ssid]
            : ["nmcli", "--wait", "15", "dev", "wifi", "connect", network.ssid, "password", password]
        root.wifiScanning = true
        wifiActionProc.running = true
    }

    function forgetWifi(network) {
        if (wifiActionProc.running) return
        wifiActionProc.command = ["nmcli", "connection", "delete", network.ssid]
        root.wifiScanning = true
        wifiActionProc.running = true
    }

    Process {
        id: wifiRescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onRunningChanged: {
            if (!running) { root.wifiScanning = true; wifiListProc.running = true }
        }
    }

    Timer {
        id: wifiErrorTimer
        interval: 3500
        onTriggered: root.wifiError = ""
    }

    Process {
        id: layoutProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: layoutQueryProc
        command: ["sh", "-c", "hyprctl -j getoption general:layout 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const obj = JSON.parse(this.text.trim())
                    if (obj.str) root.currentLayout = obj.str
                } catch(e) {}
            }
        }
    }

    Process { id: saveItemsProc }
    Process { id: saveTagsProc }
    Process { id: clipProc; stdout: StdioCollector {} }

    Process {
        id: loadTagsProc
        command: ["sh", "-c",
            "cat \"$HOME/wallpapers/.tags\" 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.wallpaperTags = JSON.parse(this.text.trim()) } catch(e) {}
            }
        }
    }

    Process {
        id: loadWpConfigProc
        command: ["sh", "-c",
            "printf '%s' \"$(cat \"$HOME/wallpapers/.tag-hints\" 2>/dev/null)\"; echo '---'; " +
            "cat \"$HOME/wallpapers/.min-cat-size\" 2>/dev/null || echo '1'; echo '---'; " +
            "ls \"$HOME/wallpapers/\" 2>/dev/null | grep -icE '\\.(jpg|jpeg|png|webp|gif)$'; echo '---'; " +
            "python3 -c \"import sys,json; d=json.load(open(sys.argv[1])); print(len(d))\" \"$HOME/wallpapers/.tags\" 2>/dev/null || echo '0'; echo '---'; " +
            "cat \"$HOME/wallpapers/.vision-model\" 2>/dev/null || echo 'moondream'; echo '---'; " +
            "cat \"$HOME/wallpapers/.text-model\" 2>/dev/null || echo 'qwen2.5-coder:7b'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("---")
                root.wpTagHints = (parts[0] || "").trim()
                const n = parseInt((parts[1] || "1").trim())
                root.wpMinCat = isNaN(n) ? 1 : Math.max(1, n)
                const total = parseInt((parts[2] || "0").trim())
                root.wpTotal = isNaN(total) ? 0 : total
                const tagged = parseInt((parts[3] || "0").trim())
                root.wpTagged = isNaN(tagged) ? 0 : tagged
                root.wpVisionModel = (parts[4] || "moondream").trim()
                root.wpTextModel   = (parts[5] || "qwen2.5-coder:7b").trim()
                ollamaCheckProc.running = false
                ollamaCheckProc.running = true
            }
        }
    }

    Process {
        id: saveWpHintsProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: saveWpMinCatProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: wpAutoTagProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onRunningChanged: {
            root.wpTagging = running
            if (!running) {
                loadWpConfigProc.running = false
                loadWpConfigProc.running = true
            }
        }
    }

    Process {
        id: wpGenThumbProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onRunningChanged: { root.wpGenThumb = running }
    }

    Process {
        id: ollamaCheckProc
        command: ["sh", "-c", "curl -sf http://localhost:11434/api/tags 2>/dev/null || echo 'ERR'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text.trim()
                if (txt === "ERR") {
                    root.wpOllamaOk = false
                    root.wpOllamaModels = []
                    return
                }
                try {
                    const data = JSON.parse(txt)
                    const names = data.models.map(m => m.name)
                    root.wpOllamaModels = names
                    root.wpOllamaOk = names.length > 0
                    const vi = names.indexOf(root.wpVisionModel)
                    root.wpVisionModelIdx = vi >= 0 ? vi : 0
                    if (vi < 0 && names.length) root.wpVisionModel = names[0]
                    const ti = names.indexOf(root.wpTextModel)
                    root.wpTextModelIdx = ti >= 0 ? ti : 0
                    if (ti < 0 && names.length) root.wpTextModel = names[0]
                } catch(e) {
                    root.wpOllamaOk = false
                    root.wpOllamaModels = []
                }
            }
        }
    }

    Process {
        id: saveVisionModelProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: saveTextModelProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    signal clipboardCopyTriggered()

    function notifyClipboardCopy() {
        root.clipboardCopyTriggered()
    }

    Process {
        id: sysMonitorsProc
        command: ["sh", "-c", "hyprctl -j monitors 2>/dev/null; echo '---SEP---'; cat $HOME/.config/hypr/user-settings.lua 2>/dev/null || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = this.text.trim().split('---SEP---')
                    const monitors = JSON.parse(parts[0])
                    const userSettings = parts.length > 1 ? parts[1].trim() : ''

                    const disabledMonitors = new Set()
                    const monitorConfigs = {}

                    const lines = userSettings.split('\n')
                    for (const line of lines) {
                        if (!line.includes('hl.monitor')) continue

                        const outputMatch = line.match(/output\s*=\s*"([^"]+)"/)
                        if (!outputMatch) continue

                        const name = outputMatch[1]
                        const isDisabled = line.includes('disabled') && line.includes('true')
                        const modeMatch = line.match(/mode\s*=\s*"([^"]+)"/)
                        const posMatch = line.match(/position\s*=\s*"([^"]+)"/)
                        const scaleMatch = line.match(/scale\s*=\s*([\d.]+)/)

                        if (isDisabled) {
                            disabledMonitors.add(name)
                        }

                        monitorConfigs[name] = {
                            mode: modeMatch ? modeMatch[1] : null,
                            position: posMatch ? posMatch[1] : null,
                            scale: scaleMatch ? parseFloat(scaleMatch[1]) : 1.0
                        }
                    }

                    const activeMonitors = monitors.map(m => ({
                        name: m.name,
                        desc: (m.description || m.name).split(" ")[0],
                        width: m.width, height: m.height,
                        refreshRate: m.refreshRate || 60,
                        x: m.x, y: m.y,
                        scale: m.scale || 1.0,
                        enabled: !disabledMonitors.has(m.name)
                    }))

                    const disabledMonList = Array.from(disabledMonitors).map(name => {
                        const config = monitorConfigs[name]
                        const mode = config && config.mode ? config.mode.split('x') : ['1920', '1080']
                        return {
                            name: name,
                            desc: name.split(" ")[0],
                            width: parseInt(mode[0]) || 1920,
                            height: parseInt(mode[1]) || 1080,
                            refreshRate: 60,
                            x: config && config.position ? parseInt(config.position.split('x')[0]) : 0,
                            y: config && config.position ? parseInt(config.position.split('x')[1]) : 0,
                            scale: config && config.scale ? config.scale : 1.0,
                            enabled: false
                        }
                    }).filter(m => !activeMonitors.find(a => a.name === m.name))

                    root.systemMonitors = activeMonitors.concat(disabledMonList)
                } catch(e) {}
            }
        }
    }

    Process {
        id: sysSensProc
        command: ["sh", "-c",
            "hyprctl -j getoption input:sensitivity 2>/dev/null; " +
            "hyprctl -j getoption input:touchpad:natural_scroll 2>/dev/null; " +
            "hyprctl -j getoption input:touchpad:scroll_factor 2>/dev/null; " +
            "hyprctl -j getoption decoration:blur:enabled 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                let depth = 0, start = 0
                const objects = []
                for (let i = 0; i < text.length; i++) {
                    if (text[i] === '{') { if (depth === 0) start = i; depth++ }
                    else if (text[i] === '}') { depth--; if (depth === 0) objects.push(text.slice(start, i + 1)) }
                }
                try { const o = JSON.parse(objects[0]); if (o.float !== undefined) root.mouseSensitivity = Math.round(o.float * 10) / 10 } catch(e) {}
                try { const o = JSON.parse(objects[1]); if (o.int !== undefined) root.naturalScroll = o.int === 1 } catch(e) {}
                try { const o = JSON.parse(objects[2]); if (o.float !== undefined) root.scrollFactor = Math.round(o.float * 20) / 20 } catch(e) {}
                try { const o = JSON.parse(objects[3]); if (o.int !== undefined) root.blurEnabled = o.int === 1 } catch(e) {}
            }
        }
    }

    Process {
        id: sysApplyProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: wsRulesProc
        command: ["sh", "-c",
            "hyprctl -j workspacerules 2>/dev/null; echo '---SEP---';" +
            "cat \"$HOME/.config/hypr/user-settings.lua\" 2>/dev/null; echo '---SEP---';" +
            "cat \"$HOME/.config/hypr/hyprland.lua\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = this.text.split('---SEP---')

                    // Try hyprctl first
                    let rules = []
                    try {
                        const raw = JSON.parse(parts[0].trim())
                        rules = raw
                            .map(r => ({ workspace: String(r.workspaceString || r.workspace || ""), monitor: r.monitor || "" }))
                            .filter(r => r.workspace && r.monitor && /^\d+$/.test(r.workspace))
                    } catch(e) {}

                    // Fall back to parsing config files (user-settings overrides hyprland.lua)
                    if (rules.length === 0) {
                        const fileRules = {}
                        for (const src of [parts[2] || "", parts[1] || ""]) {
                            for (const line of src.split('\n')) {
                                if (!line.includes('workspace_rule')) continue
                                const ws = (line.match(/workspace\s*=\s*"([^"]+)"/) || [])[1]
                                const mon = (line.match(/monitor\s*=\s*"([^"]+)"/) || [])[1]
                                if (ws && mon && /^\d+$/.test(ws)) fileRules[ws] = mon
                            }
                        }
                        rules = Object.entries(fileRules).map(([ws, mon]) => ({ workspace: ws, monitor: mon }))
                    }

                    root.workspaceRules = rules.sort((a, b) => parseInt(a.workspace) - parseInt(b.workspace))
                } catch(e) {}
            }
        }
    }

    function _writeUserSettings() {
        const lines = []
        for (const m of root.systemMonitors) {
            const disableStr = !m.enabled ? ', disabled = true' : ''
            lines.push('hl.monitor({ output = "' + m.name + '", mode = "' + m.width + 'x' + m.height + '", position = "' + m.x + 'x' + m.y + '", scale = ' + m.scale + disableStr + ' })')
        }
        for (const r of root.workspaceRules)
            lines.push('hl.workspace_rule({ workspace = "' + r.workspace + '", monitor = "' + r.monitor + '" })')
        const ns = root.naturalScroll ? 'true' : 'false'
        lines.push('hl.config({ input = { sensitivity = ' + root.mouseSensitivity + ', touchpad = { natural_scroll = ' + ns + ', scroll_factor = ' + root.scrollFactor + ' } } })')
        const blur = root.blurEnabled ? 'true' : 'false'
        lines.push('hl.config({ decoration = { blur = { enabled = ' + blur + ' } } })')
        const args = lines.map(l => "'" + l + "'").join(' ')
        return "printf '%s\\n' " + args + " > \"$HOME/.config/hypr/user-settings.lua\""
    }

    function setWorkspaceMonitor(ws, monitorName) {
        const arr = Array.from(root.workspaceRules)
        const idx = arr.findIndex(r => r.workspace === ws)
        if (idx >= 0) arr[idx] = { workspace: ws, monitor: monitorName }
        else arr.push({ workspace: ws, monitor: monitorName })
        arr.sort((a, b) => parseInt(a.workspace) - parseInt(b.workspace))
        root.workspaceRules = arr
        const evalCmd = "hyprctl eval \"hl.workspace_rule({ workspace = '" + ws + "', monitor = '" + monitorName + "' })\""
        sysApplyProc.command = ["sh", "-c", root._writeUserSettings() + " ; " + evalCmd]
        sysApplyProc.running = false
        sysApplyProc.running = true
    }

    function _rescaleCmd() {
        let cmd = ""
        for (const m of root.systemMonitors) {
            const disableStr = !m.enabled ? ', disabled = true' : ''
            cmd += " ; hyprctl eval \"hl.monitor({ output = '" + m.name + "', mode = '" + m.width + "x" + m.height + "', position = '" + m.x + "x" + m.y + "', scale = " + m.scale + disableStr + " })\""
        }
        cmd += " && hyprctl reload"
        return cmd
    }

    function setMonitorScale(mon, scale) {
        const idx = root.systemMonitors.findIndex(m => m.name === mon.name)
        if (idx >= 0) {
            const arr = Array.from(root.systemMonitors)
            arr[idx] = Object.assign({}, arr[idx], { scale: scale })
            root.systemMonitors = arr
        }
        const evalCmd = "hyprctl eval \"hl.monitor({ output = '" + mon.name + "', mode = '" + mon.width + "x" + mon.height + "', position = '" + mon.x + "x" + mon.y + "', scale = " + scale + " })\""
        sysApplyProc.command = ["sh", "-c", root._writeUserSettings() + " ; " + evalCmd]
        sysApplyProc.running = false
        sysApplyProc.running = true
    }

    function setMonitorEnabled(mon, enabled) {
        const enabledCount = root.systemMonitors.filter(m => m.enabled).length
        if (!enabled && enabledCount <= 1) {
            return
        }
        const idx = root.systemMonitors.findIndex(m => m.name === mon.name)
        if (idx >= 0) {
            const arr = Array.from(root.systemMonitors)
            arr[idx] = Object.assign({}, arr[idx], { enabled: enabled })
            root.systemMonitors = arr
        }
        const disableStr = enabled ? '' : ', disabled = true'
        const evalCmd = "hyprctl eval \"hl.monitor({ output = '" + mon.name + "', mode = '" + mon.width + "x" + mon.height + "', position = '" + mon.x + "x" + mon.y + "', scale = " + mon.scale + disableStr + " })\" && hyprctl reload"
        sysApplyProc.command = ["sh", "-c", root._writeUserSettings() + " ; " + evalCmd]
        sysApplyProc.running = false
        sysApplyProc.running = true
    }

    function setMonitorPosition(mon, dx, dy) {
        const idx = root.systemMonitors.findIndex(m => m.name === mon.name)
        if (idx >= 0) {
            const arr = Array.from(root.systemMonitors)
            arr[idx] = Object.assign({}, arr[idx], { x: mon.x + dx, y: mon.y + dy })
            root.systemMonitors = arr
        }
        const disableStr = !mon.enabled ? ', disabled = true' : ''
        const evalCmd = "hyprctl eval \"hl.monitor({ output = '" + mon.name + "', mode = '" + mon.width + "x" + mon.height + "', position = '" + (mon.x + dx) + "x" + (mon.y + dy) + "', scale = " + mon.scale + disableStr + " })\" && hyprctl reload"
        sysApplyProc.command = ["sh", "-c", root._writeUserSettings() + " ; " + evalCmd]
        sysApplyProc.running = false
        sysApplyProc.running = true
    }

    function setMouseSensitivity(val) {
        val = Math.round(Math.max(-1.0, Math.min(1.0, val)) * 10) / 10
        root.mouseSensitivity = val
        sysApplyProc.command = ["sh", "-c",
            "hyprctl eval \"hl.config({ input = { sensitivity = " + val + " } })\" && " +
            root._writeUserSettings() +
            root._rescaleCmd()
        ]
        sysApplyProc.running = false
        sysApplyProc.running = true
    }

    function setNaturalScroll(val) {
        root.naturalScroll = val
        sysApplyProc.command = ["sh", "-c",
            "hyprctl eval \"hl.config({ input = { touchpad = { natural_scroll = " + (val ? "true" : "false") + " } } })\" && " +
            root._writeUserSettings() +
            root._rescaleCmd()
        ]
        sysApplyProc.running = false
        sysApplyProc.running = true
    }

    function setScrollFactor(val) {
        val = Math.round(Math.max(0.1, Math.min(3.0, val)) * 20) / 20
        root.scrollFactor = val
        sysApplyProc.command = ["sh", "-c",
            "hyprctl eval \"hl.config({ input = { touchpad = { scroll_factor = " + val + " } } })\" && " +
            root._writeUserSettings() +
            root._rescaleCmd()
        ]
        sysApplyProc.running = false
        sysApplyProc.running = true
    }

    function setBlur(val) {
        root.blurEnabled = val
        const opacity = val ? "0.6" : "1.0"
        sysApplyProc.command = ["sh", "-c",
            "hyprctl eval \"hl.config({ decoration = { blur = { enabled = " + (val ? "true" : "false") + " } } })\" && " +
            root._writeUserSettings() + " ; " +
            "for sock in /tmp/kitty-*; do [ -S \"$sock\" ] && kitten @ --to \"unix:$sock\" set-background-opacity --all " + opacity + " 2>/dev/null; done"
        ]
        sysApplyProc.running = false
        sysApplyProc.running = true
    }

    property var clipboardItems: []

    Process {
        id: clipListProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                root.clipboardItems = lines.map(l => {
                    const tab = l.indexOf("\t")
                    return tab === -1
                        ? { id: l, preview: l, line: l }
                        : { id: l.substring(0, tab), preview: l.substring(tab + 1), line: l }
                })
            }
        }
    }

    Process {
        id: clipDecodeProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: clipDaemonProc
        command: ["sh", "-c", "pgrep -f 'wl-paste.*cliphist' || wl-paste --watch cliphist store &"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.page === "clipboard"
        onTriggered: if (!clipListProc.running) clipListProc.running = true
    }

    Timer {
        id: clearAllTimer
        onTriggered: Notifications.clearAll()
    }

    Process {
        id: powerProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    function runPowerAction(item) {
        root.closeRequested()
        powerProc.command = item.cmd
        powerProc.running = false
        // Small delay so the settings window closes before the action fires
        Qt.callLater(() => { powerProc.running = true })
    }

    function clearNotificationsAnimated() {
        const count = notifListView.count
        if (count === 0) return
        for (let i = 0; i < count; i++) {
            const item = notifListView.itemAtIndex(i)
            if (item) item.animateOut(i * 55)
        }
        clearAllTimer.interval = count * 55 + 260
        clearAllTimer.restart()
    }

    function copyClipboardItem(line) {
        clipDecodeProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "--", line]
        clipDecodeProc.running = false
        clipDecodeProc.running = true
        root.notifyClipboardCopy()
    }

    Process {
        id: homeDirProc
        command: ["sh", "-c", "printf '%s' \"$HOME\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.homeDir = this.text.trim()
        }
    }

    Process {
        id: lsProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l.length > 0)
                root.fileEntries = lines.map(l => {
                    const isDir = l.endsWith("/")
                    const name = isDir ? l.slice(0, -1) : l
                    return { name: name, isDir: isDir, path: root.pathDir + name }
                })
            }
        }
    }

    Process {
        id: loadItemsProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/main-items 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = this.text.trim().split(/\s+/).filter(id => id.length > 0)
                if (ids.length > 0) {
                    const order = {}
                    ids.forEach((id, i) => { order[id] = i })
                    const items = Array.from(root.mainItems)
                    items.sort((a, b) => (order[a.id] ?? 999) - (order[b.id] ?? 999))
                    root.mainItems = items
                }
            }
        }
    }

    function applyLayout(id) {
        root.currentLayout = id
        layoutProc.command = ["sh", "-c",
            "sed -i 's/^\\(\\s*\\)layout = \"[^\"]*\"/\\1layout = \"" + id + "\"/' " +
            "$HOME/.config/hypr/hyprland.lua && hyprctl reload"
        ]
        layoutProc.running = false
        layoutProc.running = true
    }

    Timer {
        id: btRefreshTimer
        interval: 3000
        repeat: true
        running: root.page === "bluetooth"
        onTriggered: if (!btListProc.running) btListProc.running = true
    }

    property string pendingWallpaper: ""
    property bool extractingPalette: false

    function extractWallpaperPalette() {
        if (root.wallpaperFiles.length === 0 || root.extractingPalette) return
        const file = root.wallpaperFiles[root.selectedIndex]
        const python = root.homeDir + "/.conda/envs/pywalfox/bin/python3"
        const script = root.homeDir + "/.config/quickshell/scripts/extract-palette.py"
        extractPaletteProc.command = [python, script, root.wallpapersDir + file]
        root.extractingPalette = true
        extractPaletteProc.running = false
        extractPaletteProc.running = true
    }

    function applyWallpaper(filename) {
        if (awwwProc.running) {
            pendingWallpaper = filename
        } else {
            pendingWallpaper = ""
            const types = ["fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer"]
            const type = types[Math.floor(Math.random() * types.length)]
            const cmd = ["awww", "img",
                "--transition-type", type,
                "--transition-duration", "0.5",
                "--transition-fps", "60"]
            if (root.monitorName) cmd.push("--outputs", root.monitorName)
            cmd.push(root.wallpapersDir + filename)
            awwwProc.command = cmd
            awwwProc.running = true
        }
    }

    function launchApp(exec, terminal) {
        const cmd = root.cleanExec(exec)
        if (terminal) {
            Quickshell.execDetached(["sh", "-c", "kitty -e " + cmd])
        } else {
            Quickshell.execDetached(["sh", "-c", cmd])
        }
    }

    function saveMainItems() {
        const ids = root.mainItems.map(m => m.id).join(" ")
        saveItemsProc.command = ["sh", "-c", "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + ids + "' > $HOME/.config/quickshell/main-items"]
        saveItemsProc.running = false
        saveItemsProc.running = true
    }

    function toggleBarModule(id) {
        const positions = ["left", "center", "right", "disabled"]
        const current = Theme[id] || "disabled"
        const idx = positions.indexOf(current)
        Theme[id] = positions[(idx + 1) % positions.length]
    }

    function saveWallpaperTags() {
        const safe = JSON.stringify(root.wallpaperTags).replace(/'/g, "'\\''")
        saveTagsProc.command = ["sh", "-c",
            "printf '%s' '" + safe + "' > \"$HOME/wallpapers/.tags\""]
        saveTagsProc.running = false
        saveTagsProc.running = true
    }

    function toggleWallpaperTag(filename, tag) {
        tag = tag.trim().toLowerCase()
        if (!tag) return
        const tags = Array.from(root.wallpaperTags[filename] || [])
        const idx = tags.indexOf(tag)
        if (idx >= 0) tags.splice(idx, 1)
        else tags.push(tag)
        const updated = Object.assign({}, root.wallpaperTags)
        if (tags.length === 0) delete updated[filename]
        else updated[filename] = tags
        root.wallpaperTags = updated
        root.saveWallpaperTags()
    }

    function startWpAutoTag() {
        if (root.wpTagging || !root.homeDir || !root.wpOllamaOk) return
        wpAutoTagProc.command = ["python3",
            root.homeDir + "/.config/quickshell/scripts/auto-tag-wallpaper.py",
            "--min-cat", String(root.wpMinCat),
            "--vision-model", root.wpVisionModel,
            "--text-model", root.wpTextModel,
            "--retag"]
        wpAutoTagProc.running = false
        wpAutoTagProc.running = true
    }

    function setWpVisionModel(dir) {
        const n = root.wpOllamaModels.length
        if (!n) return
        const i = ((root.wpVisionModelIdx + dir) % n + n) % n
        root.wpVisionModelIdx = i
        root.wpVisionModel = root.wpOllamaModels[i]
        const safe = root.wpVisionModel.replace(/'/g, "'\\''")
        saveVisionModelProc.command = ["sh", "-c",
            "printf '%s' '" + safe + "' > \"$HOME/wallpapers/.vision-model\""]
        saveVisionModelProc.running = false
        saveVisionModelProc.running = true
    }

    function setWpTextModel(dir) {
        const n = root.wpOllamaModels.length
        if (!n) return
        const i = ((root.wpTextModelIdx + dir) % n + n) % n
        root.wpTextModelIdx = i
        root.wpTextModel = root.wpOllamaModels[i]
        const safe = root.wpTextModel.replace(/'/g, "'\\''")
        saveTextModelProc.command = ["sh", "-c",
            "printf '%s' '" + safe + "' > \"$HOME/wallpapers/.text-model\""]
        saveTextModelProc.running = false
        saveTextModelProc.running = true
    }

    function startWpGenThumbs() {
        if (root.wpGenThumb || !root.homeDir) return
        wpGenThumbProc.command = ["sh",
            root.homeDir + "/.config/quickshell/scripts/gen-thumbs.sh"]
        wpGenThumbProc.running = false
        wpGenThumbProc.running = true
    }

    function saveWpHints(hints) {
        root.wpTagHints = hints.trim()
        const safe = hints.replace(/'/g, "'\\''")
        saveWpHintsProc.command = ["sh", "-c",
            "printf '%s' '" + safe + "' > \"$HOME/wallpapers/.tag-hints\""]
        saveWpHintsProc.running = false
        saveWpHintsProc.running = true
    }

    function setWpMinCat(n) {
        n = Math.max(1, n)
        root.wpMinCat = n
        saveWpMinCatProc.command = ["sh", "-c",
            "printf '%d' " + n + " > \"$HOME/wallpapers/.min-cat-size\""]
        saveWpMinCatProc.running = false
        saveWpMinCatProc.running = true
    }


    Connections {
        target: awwwProc
        function onRunningChanged() {
            if (!awwwProc.running && root.pendingWallpaper !== "") {
                const next = root.pendingWallpaper
                root.pendingWallpaper = ""
                root.applyWallpaper(next)
            }
        }
    }

    Item {
        id: keyNav
        anchors.fill: parent
        clip: true
        focus: true


        property real offset: root.page !== "main" ? 1.0 : 0.0
        Behavior on offset {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        readonly property var level2Pages: ["palette", "bar", "layout", "monitor_layout", "wallpapers"]
        property real subOffset: level2Pages.indexOf(root.page) >= 0 ? 1.0 : 0.0
        Behavior on subOffset {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        property real searchOpacity: (root.searchQuery !== "" || root.immediateSearch || (Theme.vimBinds && root.vimSearchMode)) ? 1.0 : 0.0
        Behavior on searchOpacity {
            NumberAnimation { duration: 140; easing.type: Easing.InOutQuad }
        }

        Keys.onPressed: event => {
            const inSearch = root.immediateSearch || (Theme.vimBinds ? root.vimSearchMode : root.searchQuery !== "")

            // WiFi password mode — intercept all input
            if (root.wifiPasswordMode) {
                if (event.key === Qt.Key_Escape) {
                    root.wifiPasswordMode = false
                    root.wifiPasswordInput = ""
                    root.wifiPendingNetwork = null
                } else if (event.key === Qt.Key_Backspace) {
                    root.wifiPasswordInput = root.wifiPasswordInput.slice(0, -1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.connectWifiPassword(root.wifiPendingNetwork, root.wifiPasswordInput)
                    root.wifiPasswordMode = false
                    root.wifiPasswordInput = ""
                    root.wifiPendingNetwork = null
                } else if (event.text.length > 0) {
                    root.wifiPasswordInput += event.text
                }
                event.accepted = true
                return
            }

            // Wallpaper tag-hints edit mode
            if (root.wpHintsEditMode) {
                if (event.key === Qt.Key_Escape) {
                    root.wpHintsEditMode = false
                    root.wpHintsInput = ""
                } else if (event.key === Qt.Key_Backspace) {
                    root.wpHintsInput = root.wpHintsInput.slice(0, -1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.saveWpHints(root.wpHintsInput)
                    root.wpHintsEditMode = false
                } else if (event.text.length > 0) {
                    root.wpHintsInput += event.text
                }
                event.accepted = true
                return
            }

            if (Theme.vimBinds && !inSearch && event.key === Qt.Key_I) {
                root.vimSearchMode = true
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Escape) {
                if (inSearch) {
                    root.searchQuery = ""
                    root.immediateSearch = false
                    if (Theme.vimBinds) root.vimSearchMode = false
                } else if (root.page === "main") {
                    root.closeRequested()
                } else {
                    goBack()
                }
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Backspace && inSearch) {
                root.searchQuery = root.searchQuery.slice(0, -1)
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Up || (Theme.vimBinds && !inSearch && event.key === Qt.Key_K)) {
                if (root.page === "monitor_layout") {
                    const mon = root.systemMonitors[root.selectedMonitorIdx]
                    if (mon) root.setMonitorPosition(mon, 0, -50)
                    event.accepted = true
                    return
                }
                const shiftHeld = (event.modifiers & Qt.ShiftModifier) !== 0
                if (inSearch) {
                    if (root.selectedSearchIndex > 0) {
                        root.selectedSearchIndex--
                        searchList.positionViewAtIndex(Math.max(root.selectedSearchIndex - 1, 0), ListView.Contain)
                    }
                } else if (shiftHeld && root.page === "main" && root.selectedIndex > 0) {
                    const items = Array.from(root.mainItems)
                    const i = root.selectedIndex
                    const tmp = items[i]; items[i] = items[i - 1]; items[i - 1] = tmp
                    root.mainItems = items
                    root.selectedIndex = i - 1
                    root.saveMainItems()
                    mainList.positionViewAtIndex(Math.max(root.selectedIndex - 1, 0), ListView.Contain)
                } else if (root.selectedIndex > 0) {
                    const sectionItems = root.page === "palette" ? root.paletteOptions
                                       : root.page === "system"  ? root.systemSettingItems
                                       : null
                    let target = root.selectedIndex - 1
                    while (target > 0 && sectionItems && sectionItems[target]?.type === "section")
                        target--
                    if (!sectionItems || sectionItems[target]?.type !== "section")
                        root.selectedIndex = target
                    const upScroll = Math.max(root.selectedIndex - 1, 0)
                    if (root.page === "main")
                        mainList.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "appearance")
                        appearanceList.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "palette")
                        paletteList.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "apps")
                        appListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "bluetooth")
                        btListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "wifi")
                        wifiListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "layout")
                        layoutList.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "bar")
                        barListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "clipboard")
                        clipListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "notifications")
                        notifListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "system")
                        sysListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "power")
                        powerListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "emoji")
                        emojiListView.positionViewAtIndex(upScroll, ListView.Contain)
                }
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Down || (Theme.vimBinds && !inSearch && event.key === Qt.Key_J)) {
                if (root.page === "monitor_layout") {
                    const mon = root.systemMonitors[root.selectedMonitorIdx]
                    if (mon) root.setMonitorPosition(mon, 0, 50)
                    event.accepted = true
                    return
                }
                const shiftHeld = (event.modifiers & Qt.ShiftModifier) !== 0
                const maxIdx = root.page === "main"          ? root.mainItems.length - 1
                             : root.page === "appearance"     ? root.appearanceItems.length - 1
                             : root.page === "palette"        ? root.paletteOptions.length - 1
                             : root.page === "apps"           ? Math.max(0, root.appsList.length - 1)
                             : root.page === "bluetooth"      ? Math.max(0, root.bluetoothDevices.length - 1)
                             : root.page === "wifi"           ? Math.max(0, root.wifiNetworks.length - 1)
                             : root.page === "layout"         ? root.layoutOptions.length - 1
                             : root.page === "bar"            ? Math.max(0, root.barModules.length - 1)
                             : root.page === "clipboard"      ? Math.max(0, root.clipboardItems.length - 1)
                             : root.page === "notifications"  ? Math.max(0, notifListView.count - 1)
                             : root.page === "system"         ? Math.max(0, root.systemSettingItems.length - 1)
                             : root.page === "wallpapers"     ? 5
                             : root.page === "power"          ? root.powerItems.length - 1
                             : root.page === "emoji"          ? Math.max(0, root.emojiList.length - 1)
                             : 0
                if (inSearch) {
                    if (root.selectedSearchIndex < root.searchResults.length - 1) {
                        root.selectedSearchIndex++
                        searchList.positionViewAtIndex(root.selectedSearchIndex + 1, ListView.Contain)
                    }
                } else if (shiftHeld && root.page === "main" && root.selectedIndex < maxIdx) {
                    const items = Array.from(root.mainItems)
                    const i = root.selectedIndex
                    const tmp = items[i]; items[i] = items[i + 1]; items[i + 1] = tmp
                    root.mainItems = items
                    root.selectedIndex = i + 1
                    root.saveMainItems()
                    mainList.positionViewAtIndex(root.selectedIndex + 1, ListView.Contain)
                } else if (root.selectedIndex < maxIdx) {
                    root.selectedIndex++
                    while ((root.page === "system" && root.systemSettingItems[root.selectedIndex]?.type === "section") ||
                           (root.page === "palette" && root.paletteOptions[root.selectedIndex]?.type === "section")) {
                        if (root.selectedIndex < maxIdx) root.selectedIndex++
                        else break
                    }
                    const downScroll = root.selectedIndex + 1
                    if (root.page === "main")
                        mainList.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "appearance")
                        appearanceList.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "palette")
                        paletteList.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "apps")
                        appListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "bluetooth")
                        btListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "wifi")
                        wifiListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "layout")
                        layoutList.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "bar")
                        barListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "clipboard")
                        clipListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "notifications")
                        notifListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "system")
                        sysListView.positionViewAtIndex(Math.min(downScroll, root.systemSettingItems.length - 1), ListView.Contain)
                    else if (root.page === "power")
                        powerListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "emoji")
                        emojiListView.positionViewAtIndex(downScroll, ListView.Contain)
                }
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                if (!inSearch) {
                    if (root.page === "monitor_layout") {
                        const mon = root.systemMonitors[root.selectedMonitorIdx]
                        if (mon && event.key === Qt.Key_Left) root.setMonitorPosition(mon, -50, 0)
                        else if (mon && event.key === Qt.Key_Right) root.setMonitorPosition(mon, 50, 0)
                        event.accepted = true
                        return
                    } else if (root.page === "wallpapers") {
                        const dir = event.key === Qt.Key_Right ? 1 : -1
                        if (root.selectedIndex === 0) root.setWpMinCat(root.wpMinCat + dir)
                        else if (root.selectedIndex === 2) root.setWpVisionModel(dir)
                        else if (root.selectedIndex === 3) root.setWpTextModel(dir)
                        event.accepted = true
                        return
                    } else if (root.page === "system") {
                        const item = root.systemSettingItems[root.selectedIndex]
                        if (item && item.type !== "section" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                            const dir = event.key === Qt.Key_Right ? 1 : -1
                            if (item.type === "sensitivity") {
                                root.setMouseSensitivity(root.mouseSensitivity + dir * 0.1)
                            } else if (item.type === "scroll_factor") {
                                root.setScrollFactor(root.scrollFactor + dir * 0.05)
                            } else if (item.type === "font_size") {
                                Theme.barFontSize = Math.max(8, Math.min(20, Theme.barFontSize + dir))
                            } else if (item.type === "scale") {
                                const scales = [1, 1.25, 1.5, 2]
                                const ci = scales.findIndex(s => Math.abs(item.monitor.scale - s) < 0.01)
                                const ni = Math.max(0, Math.min(scales.length - 1, (ci < 0 ? 0 : ci) + dir))
                                root.setMonitorScale(item.monitor, scales[ni])
                            } else if (item.type === "monitor_toggle") {
                                root.setMonitorEnabled(item.monitor, !item.monitor.enabled)
                            } else if (item.type === "blur_toggle") {
                                root.setBlur(!root.blurEnabled)
                            }
                        }
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Left && root.page !== "main") {
                        goBack()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Right && (root.page === "main" || root.page === "appearance")) {
                        activateItem()
                        event.accepted = true
                        return
                    }
                }
            }

            if (Theme.vimBinds && !inSearch) {
                if (event.key === Qt.Key_H) {
                    if (root.page === "monitor_layout") {
                        const mon = root.systemMonitors[root.selectedMonitorIdx]
                        if (mon) root.setMonitorPosition(mon, -50, 0)
                        event.accepted = true
                        return
                    }
                    if (root.page !== "main") {
                        goBack()
                        event.accepted = true
                        return
                    }
                }
                if (event.key === Qt.Key_L) {
                    if (root.page === "monitor_layout") {
                        const mon = root.systemMonitors[root.selectedMonitorIdx]
                        if (mon) root.setMonitorPosition(mon, 50, 0)
                        event.accepted = true
                        return
                    }
                    if (root.page === "main" || root.page === "appearance") {
                        activateItem()
                        event.accepted = true
                        return
                    }
                }
            }

            if (event.key === Qt.Key_Tab) {
                if (root.page === "monitor_layout" && !inSearch) {
                    root.selectedMonitorIdx = (root.selectedMonitorIdx + 1) % root.systemMonitors.length
                    event.accepted = true
                    return
                }
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (inSearch) activateSearchItem()
                else activateItem()
                event.accepted = true
                return
            }

            if (root.page === "monitor_layout" && !inSearch && event.text && event.text.length === 1) {
                const n = parseInt(event.text)
                if (!isNaN(n)) {
                    const ws = String(n === 0 ? 10 : n)
                    const mon = root.systemMonitors[root.selectedMonitorIdx]
                    if (mon) root.setWorkspaceMonitor(ws, mon.name)
                    event.accepted = true
                    return
                }
            }

            if (root.page === "wifi" && !inSearch) {
                if (event.key === Qt.Key_R) {
                    root.wifiScanning = true
                    wifiRescanProc.running = false
                    wifiRescanProc.running = true
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Delete) {
                    const net = root.wifiNetworks[root.selectedIndex]
                    if (net && net.known) root.forgetWifi(net)
                    event.accepted = true
                    return
                }
            }

            if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
                if (!Theme.vimBinds || inSearch) {
                    if (Theme.vimBinds && root.immediateSearch) root.vimSearchMode = true
                    root.searchQuery += event.text
                    root.immediateSearch = false
                    event.accepted = true
                }
            }
        }

        function navigateTo(pageId) {
            root.navStack = root.navStack.concat([{ page: root.page, index: root.selectedIndex }])
            root.page = pageId
            root.selectedIndex = 0
            if (pageId === "apps") {
                appsProc.running = false
                appsProc.running = true
            }
            Qt.callLater(function() {
                const sectionItems = root.page === "palette" ? root.paletteOptions
                                   : root.page === "system"  ? root.systemSettingItems
                                   : null
                if (sectionItems) {
                    while (root.selectedIndex < sectionItems.length && sectionItems[root.selectedIndex]?.type === "section")
                        root.selectedIndex++
                }
            })
        }

        function goBack() {
            if (root.navStack.length === 0) {
                root.page = "main"
                root.selectedIndex = 0
                return
            }
            const stack = Array.from(root.navStack)
            const prev = stack.pop()
            root.navStack = stack
            root.page = prev.page
            root.selectedIndex = prev.index
        }

        function activateItem() {
            if (root.page === "main") {
                const item = root.mainItems[root.selectedIndex]
                if (item) navigateTo(item.id)
            } else if (root.page === "appearance") {
                const item = root.appearanceItems[root.selectedIndex]
                if (item) navigateTo(item.id)
            } else if (root.page === "palette") {
                const palette = root.paletteOptions[root.selectedIndex]
                if (palette && palette.type !== "section") Theme.name = palette.id
            } else if (root.page === "apps") {
                const app = root.appsList[root.selectedIndex]
                if (app) { root.launchApp(app.exec, app.terminal); root.closeRequested() }
            } else if (root.page === "bluetooth") {
                const dev = root.bluetoothDevices[root.selectedIndex]
                if (dev) root.toggleBluetooth(dev)
            } else if (root.page === "wifi") {
                const net = root.wifiNetworks[root.selectedIndex]
                if (net) {
                    if (net.inUse || net.security === "" || net.known) {
                        root.connectWifi(net)
                    } else {
                        root.wifiPendingNetwork = net
                        root.wifiPasswordInput = ""
                        root.wifiPasswordMode = true
                    }
                }
            } else if (root.page === "wallpapers") {
                if (root.selectedIndex === 1) {
                    root.wpHintsInput = root.wpTagHints
                    root.wpHintsEditMode = true
                } else if (root.selectedIndex === 4 && !root.wpTagging) {
                    root.startWpAutoTag()
                } else if (root.selectedIndex === 5 && !root.wpGenThumb) {
                    root.startWpGenThumbs()
                }
            } else if (root.page === "layout") {
                const l = root.layoutOptions[root.selectedIndex]
                if (l) root.applyLayout(l.id)
            } else if (root.page === "bar") {
                const mod = root.barModules[root.selectedIndex]
                if (mod) root.toggleBarModule(mod.id)
            } else if (root.page === "clipboard") {
                const item = root.clipboardItems[root.selectedIndex]
                if (item) { root.copyClipboardItem(item.line); root.closeRequested() }
            } else if (root.page === "notifications") {
                const ni = notifListView.itemAtIndex(root.selectedIndex)
                if (ni) ni.dismiss()
            } else if (root.page === "power") {
                const item = root.powerItems[root.selectedIndex]
                if (item) root.runPowerAction(item)
            } else if (root.page === "emoji") {
                const emoji = root.emojiList[root.selectedIndex]
                if (emoji) { root.copyEmoji(emoji.e); root.closeRequested() }
            } else if (root.page === "system") {
                const item = root.systemSettingItems[root.selectedIndex]
                if (!item || item.type === "section") return
                if (item.type === "scale") {
                    const scales = [1, 1.25, 1.5, 2]
                    const curIdx = scales.findIndex(s => Math.abs(item.monitor.scale - s) < 0.01)
                    root.setMonitorScale(item.monitor, scales[(curIdx + 1) % scales.length])
                } else if (item.type === "monitor_toggle") {
                    root.setMonitorEnabled(item.monitor, !item.monitor.enabled)
                } else if (item.type === "sensitivity") {
                    root.setMouseSensitivity(root.mouseSensitivity + 0.1)
                } else if (item.type === "natural_scroll") {
                    root.setNaturalScroll(!root.naturalScroll)
                } else if (item.type === "blur_toggle") {
                    root.setBlur(!root.blurEnabled)
                } else if (item.type === "scroll_factor") {
                    root.setScrollFactor(root.scrollFactor + 0.05)
                } else if (item.type === "font_size") {
                    Theme.barFontSize = Math.min(20, Theme.barFontSize + 1)
                } else if (item.type === "vim_binds") {
                    Theme.vimBinds = !Theme.vimBinds
                } else if (item.type === "nav") {
                    navigateTo(item.page)
                }
            }
        }

        function activateSearchItem() {
            const result = root.searchResults[root.selectedSearchIndex]
            if (!result) return
            if (result.type === "web") {
                Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(root.searchQuery)])
                root.closeRequested()
                return
            }
            if (result.type === "math") {
                clipProc.command = ["sh", "-c", "printf '%s' '" + result.label + "' | wl-copy"]
                clipProc.running = false
                clipProc.running = true
                root.notifyClipboardCopy()
                root.searchQuery = ""
                return
            }
            if (result.type === "file") {
                if (result.isDir) {
                    root.searchQuery = result.path + "/"
                } else {
                    Quickshell.execDetached(["xdg-open", result.path])
                    root.closeRequested()
                }
                return
            }
            if (result.type === "wallpaper") root.applyWallpaper(result.file)
            else if (result.type === "palette") Theme.name = result.id
            else if (result.type === "app") { root.launchApp(result.exec, result.terminal); root.closeRequested() }
            else if (result.type === "bluetooth") { root.toggleBluetooth(result); return }
            else if (result.type === "wifi") {
                if (result.inUse || result.security === "" || result.known) {
                    root.connectWifi(result)
                } else {
                    root.wifiPendingNetwork = result
                    root.wifiPasswordInput = ""
                    root.wifiPasswordMode = true
                    root.searchQuery = ""
                    root.page = "wifi"
                }
                return
            }
            else if (result.type === "layout") { root.applyLayout(result.id) }
            else if (result.type === "menu") { root.page = result.id; root.selectedIndex = 0 }
            else if (result.type === "clipboard") { root.copyClipboardItem(result.line); root.closeRequested(); return }
            else if (result.type === "emoji") { root.copyEmoji(result.e); root.closeRequested(); return }
            else if (result.type === "system_item") {
                root._pendingSystemLabel = result.label
                root.page = result.page
                const initIdx = root.systemSettingItems.findIndex(s => s.label === result.label)
                root.selectedIndex = initIdx >= 0 ? initIdx : 0
                Qt.callLater(() => sysListView.positionViewAtIndex(root.selectedIndex, ListView.Contain))
            }
            else if (result.type === "bar_module") { root.page = result.page; root.selectedIndex = result.index; Qt.callLater(() => scrollToSelected()) }
            root.searchQuery = ""
            root.vimSearchMode = false
            root.immediateSearch = false
        }

        function scrollToSelected() {
            const idx = root.selectedIndex
            if (root.page === "main")           mainList.positionViewAtIndex(idx, ListView.Contain)
            else if (root.page === "appearance") appearanceList.positionViewAtIndex(idx, ListView.Contain)
            else if (root.page === "system")     sysListView.positionViewAtIndex(idx, ListView.Contain)
            else if (root.page === "bar")        barListView.positionViewAtIndex(idx, ListView.Contain)
            else if (root.page === "apps")       appListView.positionViewAtIndex(idx, ListView.Contain)
            else if (root.page === "bluetooth")  btListView.positionViewAtIndex(idx, ListView.Contain)
            else if (root.page === "wifi")       wifiListView.positionViewAtIndex(idx, ListView.Contain)
            else if (root.page === "palette")    paletteList.positionViewAtIndex(idx, ListView.Contain)
            else if (root.page === "power")      powerListView.positionViewAtIndex(idx, ListView.Contain)
            else if (root.page === "notifications") notifListView.positionViewAtIndex(idx, ListView.Contain)
            else if (root.page === "clipboard")  clipListView.positionViewAtIndex(idx, ListView.Contain)
        }

        // ── Main page ──────────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height
            x: -parent.width * keyNav.offset

            PageHeader {
                id: mainHeader
                title: "Settings"
                showBack: false
                detail: "Type to search"
            }

            ListView {
                id: mainList
                anchors { left: parent.left; right: parent.right; top: mainHeader.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                model: root.mainItems
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: ListRow {
                    required property var modelData
                    required property int index
                    selected: root.selectedIndex === index
                    icon: modelData.icon
                    label: modelData.label
                    chevron: true
                    onClicked: { root.selectedIndex = index; keyNav.activateItem() }
                }
            }
        }

        // ── Sub-page container ─────────────────────────────────
        Item {
            width: parent.width
            height: parent.height
            x: parent.width * (1.0 - keyNav.offset)
            clip: true

            // ── Level-1 container (appearance and direct-from-main pages) ──
            Item {
                width: parent.width
                height: parent.height
                x: -parent.width * keyNav.subOffset

            // ── Appearance ────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "appearance"

                PageHeader {
                    id: appearanceHeader
                    title: "Appearance"
                    onBackClicked: keyNav.goBack()
                }

                ListView {
                    id: appearanceList
                    anchors { left: parent.left; right: parent.right; top: appearanceHeader.bottom; bottom: parent.bottom; topMargin: 8 }
                    model: root.appearanceItems
                    clip: true
                    interactive: false

                    delegate: ListRow {
                        required property var modelData
                        required property int index
                        selected: root.selectedIndex === index
                        icon: modelData.icon
                        label: modelData.label
                        chevron: true
                        onClicked: { root.selectedIndex = index; keyNav.activateItem() }
                    }
                }
            }

            // ── Applications ───────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "apps"

                PageHeader {
                    id: appsHeader
                    title: "Applications"
                    detail: root.appsList.length + " apps"
                    onBackClicked: keyNav.goBack()
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: root.appsList.length === 0
                    icon: "apps"
                    text: "Loading applications…"
                }

                ListView {
                    id: appListView
                    anchors { left: parent.left; right: parent.right; top: appsHeader.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                    model: root.appsList
                    clip: true
                    visible: root.appsList.length > 0

                    delegate: ListRow {
                        id: appRow
                        required property var modelData
                        required property int index
                        selected: root.selectedIndex === index
                        label: modelData.name
                        leading: Component {
                            Image {
                                width: 28; height: 28
                                source: root.resolveIcon(appRow.modelData.icon)
                                sourceSize: Qt.size(56, 56)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }
                        }
                        onClicked: { root.selectedIndex = index; keyNav.activateItem() }
                    }
                }
            }

            // ── Bluetooth ──────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "bluetooth"

                PageHeader {
                    id: btHeader
                    title: "Bluetooth"
                    detail: root.bluetoothDevices.length + " known"
                    onBackClicked: keyNav.goBack()
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: root.bluetoothDevices.length === 0
                    icon: "bluetoothOff"
                    text: "No known devices"
                }

                ListView {
                    id: btListView
                    anchors { left: parent.left; right: parent.right; top: btHeader.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                    model: root.bluetoothDevices
                    clip: true
                    visible: root.bluetoothDevices.length > 0

                    delegate: ListRow {
                        required property var modelData
                        required property int index
                        selected: root.selectedIndex === index
                        icon: modelData.connected ? "bluetoothConnected" : "bluetooth"
                        iconColor: modelData.connected ? Theme.accent : Theme.subtext
                        label: modelData.name
                        sublabel: modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Not paired"
                        onClicked: { root.selectedIndex = index; keyNav.activateItem() }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: parent.parent.selected
                            text: modelData.connected ? "Disconnect" : "Connect"
                            color: Theme.subtext
                            font.pixelSize: Theme.textSm
                        }
                    }
                }
            }

            // ── WiFi ──────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "wifi"

                PageHeader {
                    id: wifiHeader
                    title: "Wi-Fi"
                    detail: root.wifiScanning ? "Scanning…" : root.wifiNetworks.length + " networks"
                    onBackClicked: keyNav.goBack()
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: !root.wifiScanning && root.wifiNetworks.length === 0 && !root.wifiPasswordMode
                    icon: "wifiOff"
                    text: "No networks found"
                }

                ListView {
                    id: wifiListView
                    anchors { left: parent.left; right: parent.right; top: wifiHeader.bottom; bottom: wifiHint.top; topMargin: 8 }
                    model: root.wifiNetworks
                    clip: true
                    visible: root.wifiNetworks.length > 0 && !root.wifiPasswordMode

                    delegate: ListRow {
                        required property var modelData
                        required property int index
                        selected: root.selectedIndex === index
                        label: modelData.ssid
                        sublabel: modelData.inUse ? "Connected"
                                : modelData.known ? "Saved"
                                : modelData.security !== "" ? "Secured" : "Open"
                        onClicked: { root.selectedIndex = index; keyNav.activateItem() }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Repeater {
                                model: 4
                                Rectangle {
                                    required property int index
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    height: 4 + index * 3
                                    radius: 1
                                    readonly property int level: modelData.signal >= 75 ? 4 : modelData.signal >= 50 ? 3 : modelData.signal >= 25 ? 2 : 1
                                    color: index < level ? (modelData.inUse ? Theme.accent : Theme.text) : Theme.track
                                }
                            }
                        }
                    }
                }

                Label {
                    id: wifiHint
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20 }
                    height: visible ? 36 : 0
                    visible: !root.wifiPasswordMode
                    text: root.wifiError !== "" ? root.wifiError : "Enter to connect · R to rescan · Del to forget"
                    color: root.wifiError !== "" ? Theme.red : Theme.subtext
                    font.pixelSize: Theme.textXs
                    elide: Text.ElideRight
                }

                // Password prompt
                Item {
                    anchors { left: parent.left; right: parent.right; top: wifiHeader.bottom; bottom: parent.bottom }
                    visible: root.wifiPasswordMode

                    Column {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 32; rightMargin: 32 }
                        spacing: 6

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.wifiPendingNetwork ? root.wifiPendingNetwork.ssid : ""
                            font.pixelSize: Theme.textLg
                            font.weight: Font.DemiBold
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Enter the network password"
                            color: Theme.subtext
                            font.pixelSize: Theme.textSm
                        }

                        Item { width: 1; height: 12 }

                        Rectangle {
                            width: parent.width
                            height: 42
                            radius: Theme.radiusMd
                            color: Theme.hover
                            border.width: 1
                            border.color: Theme.accent

                            Row {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 1

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "•".repeat(root.wifiPasswordInput.length)
                                    font.pixelSize: Theme.textMd
                                }

                                Rectangle {
                                    width: 2; height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.accent
                                    visible: wifiCursorBlink.blinkOn
                                }
                            }

                            Label {
                                anchors { left: parent.left; leftMargin: 17; verticalCenter: parent.verticalCenter }
                                visible: root.wifiPasswordInput === ""
                                text: "Password"
                                color: Theme.subtext
                            }
                        }

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            visible: root.wifiError !== ""
                            text: root.wifiError
                            color: Theme.red
                            font.pixelSize: Theme.textSm
                            elide: Text.ElideRight
                        }
                    }
                }

                Timer {
                    id: wifiCursorBlink
                    property bool blinkOn: true
                    interval: 530
                    repeat: true
                    running: root.wifiPasswordMode
                    onTriggered: blinkOn = !blinkOn
                    onRunningChanged: if (!running) blinkOn = true
                }
            }

            // ── Clipboard ─────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "clipboard"

                PageHeader {
                    id: clipHeader
                    title: "Clipboard"
                    detail: root.clipboardItems.length + " items"
                    onBackClicked: keyNav.goBack()
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: root.clipboardItems.length === 0
                    icon: "clipboard"
                    text: "Nothing copied yet"
                }

                ListView {
                    id: clipListView
                    anchors { left: parent.left; right: parent.right; top: clipHeader.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                    model: root.clipboardItems
                    clip: true
                    visible: root.clipboardItems.length > 0

                    delegate: ListRow {
                        required property var modelData
                        required property int index
                        selected: root.selectedIndex === index
                        label: modelData.preview
                        mono: true
                        onClicked: { root.selectedIndex = index; keyNav.activateItem() }
                    }
                }
            }

            // ── Notifications ──────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "notifications"

                PageHeader {
                    id: notifHeader
                    title: "Notifications"
                    detail: notifListView.count > 0 ? notifListView.count + " total" : ""
                    onBackClicked: keyNav.goBack()

                    Label {
                        visible: notifListView.count > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear all"
                        color: clearAllHover.hovered ? Theme.text : Theme.accent
                        font.pixelSize: Theme.textSm
                        font.weight: Font.Medium
                        HoverHandler { id: clearAllHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.clearNotificationsAnimated() }
                    }
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: notifListView.count === 0
                    icon: "bell"
                    text: "You're all caught up"
                }

                ListView {
                    id: notifListView
                    anchors { left: parent.left; right: parent.right; top: notifHeader.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                    model: Notifications.history
                    clip: true
                    spacing: 4
                    visible: notifListView.count > 0

                    delegate: Item {
                        id: notifDelegate
                        required property var modelData
                        required property int index

                        property bool _isClearAll: false

                        function dismiss() {
                            if (!notifExitAnim.running) {
                                _isClearAll = false
                                notifExitAnim.start()
                            }
                        }

                        function animateOut(delay) {
                            _isClearAll = true
                            notifExitDelayTimer.interval = Math.max(1, delay)
                            notifExitDelayTimer.restart()
                        }

                        Timer {
                            id: notifExitDelayTimer
                            onTriggered: notifExitAnim.start()
                        }

                        SequentialAnimation {
                            id: notifExitAnim
                            ParallelAnimation {
                                NumberAnimation { target: notifDelegate; property: "x"; to: 520; duration: 220; easing.type: Easing.InCubic }
                                NumberAnimation { target: notifDelegate; property: "opacity"; to: 0; duration: 170; easing.type: Easing.InCubic }
                            }
                            ScriptAction { script: { if (!notifDelegate._isClearAll) Notifications.dismiss(notifDelegate.modelData.id) } }
                        }

                        width: notifListView.width
                        height: notifCol.implicitHeight + 24

                        Rectangle {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            radius: Theme.radiusMd
                            color: root.selectedIndex === notifDelegate.index ? Theme.selected : Theme.hover

                            Column {
                                id: notifCol
                                anchors {
                                    left: parent.left; leftMargin: 14
                                    right: dismissBtn.left; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 3

                                Row {
                                    spacing: 6
                                    Rectangle {
                                        visible: modelData.urgency === NotificationUrgency.Critical
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 6; height: 6; radius: 3
                                        color: Theme.red
                                    }
                                    Label {
                                        text: modelData.appName || "Notification"
                                        color: Theme.subtext
                                        font.pixelSize: Theme.textXs
                                        font.weight: Font.Medium
                                    }
                                }

                                Label {
                                    width: parent.width
                                    text: modelData.summary || ""
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }

                                Label {
                                    width: parent.width
                                    text: modelData.body || ""
                                    color: Theme.subtext
                                    font.pixelSize: Theme.textSm
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }

                            Icon {
                                id: dismissBtn
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                name: "close"
                                size: 16
                                color: dismissHover.hovered ? Theme.text : Theme.subtext
                                HoverHandler { id: dismissHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: notifDelegate.dismiss() }
                            }
                        }
                    }
                }
            }

            // ── System ────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "system"

                PageHeader {
                    id: sysHeader
                    title: "System"
                    onBackClicked: keyNav.goBack()
                }

                ListView {
                    id: sysListView
                    anchors { left: parent.left; right: parent.right; top: sysHeader.bottom; bottom: parent.bottom; bottomMargin: 8 }
                    model: root.systemSettingItems
                    clip: true
                    interactive: true
                    onCountChanged: if (root.activeSubPage === "system") Qt.callLater(() => contentY = 0)

                    delegate: Loader {
                        id: sysDelegate
                        required property var modelData
                        required property int index
                        width: sysListView.width
                        sourceComponent: modelData.type === "section" ? sysSection : sysRow

                        Component {
                            id: sysSection
                            Item {
                                width: sysListView.width
                                height: 40
                                SectionLabel {
                                    anchors { left: parent.left; leftMargin: 20; bottom: parent.bottom; bottomMargin: 6 }
                                    text: sysDelegate.modelData.label
                                }
                            }
                        }

                        Component {
                            id: sysRow
                            ListRow {
                                id: row
                                readonly property var entry: sysDelegate.modelData
                                readonly property string kind: entry.type
                                width: sysListView.width
                                selected: root.selectedIndex === sysDelegate.index
                                label: entry.label
                                sublabel: entry.sub || ""
                                chevron: kind === "nav"
                                onClicked: {
                                    root.selectedIndex = sysDelegate.index
                                    if (kind === "nav") keyNav.navigateTo(entry.page)
                                }

                                // Monitor scale chips
                                Row {
                                    visible: row.kind === "scale"
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Repeater {
                                        model: [1, 1.25, 1.5, 2]
                                        delegate: Rectangle {
                                            id: scaleChip
                                            required property var modelData
                                            readonly property bool active: row.entry.monitor
                                                ? Math.abs(row.entry.monitor.scale - modelData) < 0.01 : false
                                            width: 42; height: 26; radius: Theme.radiusSm
                                            color: active ? Theme.accent : Theme.hover

                                            Label {
                                                anchors.centerIn: parent
                                                text: scaleChip.modelData + "×"
                                                color: scaleChip.active ? Theme.base : Theme.subtext
                                                font.pixelSize: Theme.textXs
                                                font.weight: Font.Medium
                                            }

                                            TapHandler {
                                                onTapped: {
                                                    root.selectedIndex = sysDelegate.index
                                                    root.setMonitorScale(row.entry.monitor, scaleChip.modelData)
                                                }
                                            }
                                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                                        }
                                    }
                                }

                                // Stepper for pointer speed, scroll speed and text size
                                Row {
                                    visible: row.kind === "sensitivity" || row.kind === "scroll_factor" || row.kind === "font_size"
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    function step(dir) {
                                        root.selectedIndex = sysDelegate.index
                                        if (row.kind === "sensitivity") root.setMouseSensitivity(root.mouseSensitivity + dir * 0.1)
                                        else if (row.kind === "scroll_factor") root.setScrollFactor(root.scrollFactor + dir * 0.05)
                                        else if (row.kind === "font_size") Theme.barFontSize = Math.max(8, Math.min(20, Theme.barFontSize + dir))
                                    }

                                    Repeater {
                                        model: [-1, 0, 1]
                                        delegate: Item {
                                            required property int modelData
                                            width: modelData === 0 ? 48 : 26
                                            height: 26

                                            Rectangle {
                                                anchors.fill: parent
                                                visible: parent.modelData !== 0
                                                radius: Theme.radiusSm
                                                color: stepHover.hovered ? Theme.selected : Theme.hover
                                            }

                                            Label {
                                                anchors.centerIn: parent
                                                text: parent.modelData < 0 ? "−"
                                                    : parent.modelData > 0 ? "+"
                                                    : row.kind === "sensitivity" ? root.mouseSensitivity.toFixed(1)
                                                    : row.kind === "scroll_factor" ? root.scrollFactor.toFixed(2)
                                                    : Theme.barFontSize + " px"
                                                color: parent.modelData === 0 ? Theme.text : Theme.subtext
                                                font.pixelSize: parent.modelData === 0 ? Theme.textSm : Theme.textMd
                                            }

                                            HoverHandler { id: stepHover; enabled: parent.modelData !== 0; cursorShape: Qt.PointingHandCursor }
                                            TapHandler {
                                                enabled: parent.modelData !== 0
                                                onTapped: parent.parent.step(parent.modelData)
                                            }
                                        }
                                    }
                                }

                                Toggle {
                                    visible: row.kind === "natural_scroll"
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: root.naturalScroll
                                    onToggled: { root.selectedIndex = sysDelegate.index; root.setNaturalScroll(!root.naturalScroll) }
                                }

                                Toggle {
                                    visible: row.kind === "blur_toggle"
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: root.blurEnabled
                                    onToggled: { root.selectedIndex = sysDelegate.index; root.setBlur(!root.blurEnabled) }
                                }

                                Toggle {
                                    visible: row.kind === "vim_binds"
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: Theme.vimBinds
                                    onToggled: { root.selectedIndex = sysDelegate.index; Theme.vimBinds = !Theme.vimBinds }
                                }

                                Toggle {
                                    visible: row.kind === "monitor_toggle"
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property bool canDisable: root.systemMonitors.filter(m => m.enabled).length > 1
                                    checked: !!(row.entry.monitor && row.entry.monitor.enabled)
                                    opacity: checked && !canDisable ? 0.4 : 1.0
                                    onToggled: { root.selectedIndex = sysDelegate.index; root.setMonitorEnabled(row.entry.monitor, !row.entry.monitor.enabled) }
                                }
                            }
                        }
                    }
                }
            }

            // ── Power ─────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "power"

                PageHeader {
                    id: powerHeader
                    title: "Power"
                    onBackClicked: keyNav.goBack()
                }

                ListView {
                    id: powerListView
                    anchors { left: parent.left; right: parent.right; top: powerHeader.bottom; bottom: parent.bottom; topMargin: 8 }
                    model: root.powerItems
                    clip: true
                    interactive: false

                    delegate: ListRow {
                        required property var modelData
                        required property int index
                        selected: root.selectedIndex === index
                        icon: modelData.icon
                        iconColor: modelData.destructive ? Theme.red : Theme.subtext
                        label: modelData.label
                        labelColor: modelData.destructive ? Theme.red : Theme.text
                        onClicked: { root.selectedIndex = index; root.runPowerAction(modelData) }
                    }
                }
            }

            // ── Emoji picker ───────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "emoji"

                PageHeader {
                    id: emojiHeader
                    title: "Emoji"
                    detail: "Type to search"
                    onBackClicked: keyNav.goBack()
                }

                ListView {
                    id: emojiListView
                    anchors { left: parent.left; right: parent.right; top: emojiHeader.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                    model: root.emojiList
                    clip: true

                    delegate: ListRow {
                        id: emojiRow
                        required property var modelData
                        required property int index
                        selected: root.selectedIndex === index
                        label: modelData.n.charAt(0).toUpperCase() + modelData.n.slice(1)
                        leading: Component {
                            Text {
                                width: 28
                                text: emojiRow.modelData.e
                                font.pixelSize: 20
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                        onClicked: { root.selectedIndex = index; keyNav.activateItem() }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: emojiRow.selected
                            text: "Copy"
                            color: Theme.subtext
                            font.pixelSize: Theme.textSm
                        }
                    }
                }
            }

            }

            // ── Level-2 container (appearance sub-pages) ─────────────────
            Item {
                width: parent.width
                height: parent.height
                x: parent.width * (1.0 - keyNav.subOffset)

            // ── Layout ────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "layout"

                PageHeader {
                    id: layoutHeader
                    title: "Tiling layout"
                    onBackClicked: keyNav.goBack()
                }

                ListView {
                    id: layoutList
                    anchors { left: parent.left; right: parent.right; top: layoutHeader.bottom; bottom: parent.bottom; topMargin: 8 }
                    model: root.layoutOptions
                    clip: true
                    interactive: false

                    delegate: ListRow {
                        id: layoutRow
                        required property var modelData
                        required property int index
                        selected: root.selectedIndex === index
                        label: modelData.label
                        sublabel: modelData.desc
                        leading: Component { LayoutGlyph { layoutId: layoutRow.modelData.id } }
                        onClicked: { root.selectedIndex = index; keyNav.activateItem() }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.currentLayout === layoutRow.modelData.id
                            name: "check"
                            size: 18
                            color: Theme.accent
                        }
                    }
                }
            }

            // ── Monitor Layout ──────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "monitor_layout"

                PageHeader {
                    id: monLayoutHeader
                    title: "Arrangement"
                    detail: "Arrows move · Tab switches · 0–9 assigns"
                    onBackClicked: keyNav.goBack()
                }

                Item {
                    id: monLayoutCanvas
                    anchors { left: parent.left; right: parent.right; top: monLayoutHeader.bottom; bottom: wsPanel.top; margins: 24 }

                    property real minX: root.systemMonitors.length > 0 ? root.systemMonitors.reduce((mn, m) => Math.min(mn, m.x), Infinity) : 0
                    property real minY: root.systemMonitors.length > 0 ? root.systemMonitors.reduce((mn, m) => Math.min(mn, m.y), Infinity) : 0
                    property real totalW: root.systemMonitors.length > 0 ? root.systemMonitors.reduce((max, m) => Math.max(max, m.x + m.width  / m.scale), -Infinity) - minX : 1920
                    property real totalH: root.systemMonitors.length > 0 ? root.systemMonitors.reduce((max, m) => Math.max(max, m.y + m.height / m.scale), -Infinity) - minY : 1080
                    property real monScale: Math.min(width / totalW, height / totalH, 1.0)
                    property real offsetX: (width  - totalW * monScale) / 2 - minX * monScale
                    property real offsetY: (height - totalH * monScale) / 2 - minY * monScale

                    Repeater {
                        model: root.systemMonitors
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool sel: root.selectedMonitorIdx === index

                            x: modelData.x * monLayoutCanvas.monScale + monLayoutCanvas.offsetX
                            y: modelData.y * monLayoutCanvas.monScale + monLayoutCanvas.offsetY
                            width:  (modelData.width  / modelData.scale) * monLayoutCanvas.monScale
                            height: (modelData.height / modelData.scale) * monLayoutCanvas.monScale

                            radius: Theme.radiusSm
                            color: sel ? Theme.alpha(Theme.accent, 0.18) : Theme.hover
                            border.width: sel ? 2 : 1
                            border.color: sel ? Theme.accent : Theme.hairline
                            opacity: modelData.enabled ? 1.0 : 0.4

                            TapHandler { onTapped: root.selectedMonitorIdx = index }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.name
                                    font.pixelSize: Math.max(10, Math.min(14, monLayoutCanvas.monScale * 40))
                                    font.weight: Font.DemiBold
                                }

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(modelData.width / modelData.scale) + " × " + Math.round(modelData.height / modelData.scale)
                                    color: Theme.subtext
                                    font.pixelSize: Theme.textXs
                                }
                            }
                        }
                    }
                }

                // ── Workspace assignment panel ──────────────────
                Column {
                    id: wsPanel
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20; bottomMargin: 16 }
                    spacing: 8

                    SectionLabel {
                        property var selMon: root.systemMonitors[root.selectedMonitorIdx]
                        text: selMon ? "Workspaces on " + selMon.name : "Workspaces"
                    }

                    Row {
                        id: wsChipRow
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: 10
                            delegate: Rectangle {
                                required property int index
                                property string ws: String(index + 1)
                                property var rule: root.workspaceRules.find(r => r.workspace === ws) || null
                                property var selMon: root.systemMonitors[root.selectedMonitorIdx]
                                property bool onSelectedMon: rule && selMon && rule.monitor === selMon.name

                                width: (wsChipRow.width - 9 * wsChipRow.spacing) / 10
                                height: 40
                                radius: Theme.radiusSm
                                color: onSelectedMon ? Theme.accent : Theme.hover

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: ws
                                        color: onSelectedMon ? Theme.base : Theme.text
                                        font.weight: Font.Medium
                                    }

                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: !!rule && !onSelectedMon
                                        text: rule ? rule.monitor : ""
                                        color: Theme.subtext
                                        font.pixelSize: 9
                                        width: Math.min(implicitWidth, wsChipRow.width / 10 - 4)
                                        elide: Text.ElideRight
                                    }
                                }

                                TapHandler {
                                    onTapped: { if (selMon) root.setWorkspaceMonitor(ws, selMon.name) }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }
            }

            // ── Palette ────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "palette"

                PageHeader {
                    id: paletteHeader
                    title: "Color palette"
                    detail: Theme.name === "custom" ? "From wallpaper" : ""
                    onBackClicked: keyNav.goBack()
                }

                ListView {
                    id: paletteList
                    anchors { left: parent.left; right: parent.right; top: paletteHeader.bottom; bottom: parent.bottom; bottomMargin: 8 }
                    model: root.paletteOptions
                    clip: true
                    interactive: false

                    delegate: Loader {
                        id: paletteDelegate
                        required property var modelData
                        required property int index
                        width: paletteList.width
                        sourceComponent: modelData.type === "section" ? paletteSection : paletteRow

                        Component {
                            id: paletteSection
                            Item {
                                width: paletteList.width
                                height: 36
                                SectionLabel {
                                    anchors { left: parent.left; leftMargin: 20; bottom: parent.bottom; bottomMargin: 6 }
                                    text: paletteDelegate.modelData.label
                                }
                            }
                        }

                        Component {
                            id: paletteRow
                            ListRow {
                                width: paletteList.width
                                height: 40
                                selected: root.selectedIndex === paletteDelegate.index
                                label: paletteDelegate.modelData.label
                                onClicked: {
                                    root.selectedIndex = paletteDelegate.index
                                    Theme.name = paletteDelegate.modelData.id
                                }

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: Theme.name === paletteDelegate.modelData.id
                                    name: "check"
                                    size: 16
                                    color: Theme.accent
                                }

                                Swatches { anchors.verticalCenter: parent.verticalCenter; colors: paletteDelegate.modelData.swatches }
                            }
                        }
                    }
                }
            }

            // ── Bar ───────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "bar"

                PageHeader {
                    id: barHeader
                    title: "Bar layout"
                    detail: "Enter cycles position"
                    onBackClicked: keyNav.goBack()
                }

                ListView {
                    id: barListView
                    anchors { left: parent.left; right: parent.right; top: barHeader.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                    model: root.barModules
                    clip: true

                    delegate: ListRow {
                        id: barRow
                        required property var modelData
                        required property int index
                        readonly property string pos: Theme[modelData.id] || "disabled"
                        selected: root.selectedIndex === index
                        label: modelData.label
                        labelColor: pos === "disabled" ? Theme.subtext : Theme.text
                        onClicked: { root.selectedIndex = index; keyNav.activateItem() }

                        // Segmented control: left · center · right · off
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200
                            height: 28
                            radius: Theme.radiusSm + 2
                            color: Theme.hover

                            readonly property var options: ["left", "center", "right", "disabled"]
                            readonly property int idx: Math.max(0, options.indexOf(barRow.pos))

                            Rectangle {
                                width: (parent.width - 4) / 4
                                height: parent.height - 4
                                y: 2
                                x: 2 + parent.idx * width
                                radius: Theme.radiusSm
                                color: barRow.pos === "disabled" ? Theme.selected : Theme.accent
                                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }

                            Row {
                                x: 2
                                anchors.verticalCenter: parent.verticalCenter
                                Repeater {
                                    model: ["Left", "Center", "Right", "Off"]
                                    Label {
                                        required property string modelData
                                        required property int index
                                        width: 49
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData
                                        color: index === parent.parent.idx && barRow.pos !== "disabled" ? Theme.base : Theme.subtext
                                        font.pixelSize: Theme.textXs
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    root.selectedIndex = barRow.index
                                    Theme[barRow.modelData.id] = parent.options[Math.min(3, Math.floor(mouse.x / width * 4))]
                                }
                            }
                        }
                    }
                }
            }

            // ── Wallpaper Tags ────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "wallpapers"

                PageHeader {
                    id: wpTagsHeader
                    title: "Wallpaper tags"
                    detail: root.wpTagged + " of " + root.wpTotal + " tagged"
                    onBackClicked: keyNav.goBack()
                }

                Column {
                    anchors { left: parent.left; right: parent.right; top: wpTagsHeader.bottom; topMargin: 8 }

                    ListRow {
                        selected: root.selectedIndex === 0
                        label: "Minimum category size"
                        sublabel: "Tags with fewer wallpapers are hidden in the picker"
                        onClicked: root.selectedIndex = 0
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "‹  " + root.wpMinCat + "  ›"
                            color: Theme.subtext
                        }
                    }

                    ListRow {
                        selected: root.selectedIndex === 1
                        label: "Tag hints"
                        sublabel: root.wpHintsEditMode ? root.wpHintsInput + "▏"
                                : root.wpTagHints !== "" ? root.wpTagHints : "None · Enter to edit"
                        onClicked: { root.selectedIndex = 1; keyNav.activateItem() }
                    }

                    ListRow {
                        selected: root.selectedIndex === 2
                        label: "Vision model"
                        onClicked: root.selectedIndex = 2
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.wpOllamaOk ? "‹  " + root.wpVisionModel + "  ›" : "Unavailable"
                            color: root.wpOllamaOk ? Theme.subtext : Theme.red
                            font.pixelSize: Theme.textSm
                        }
                    }

                    ListRow {
                        selected: root.selectedIndex === 3
                        label: "Text model"
                        onClicked: root.selectedIndex = 3
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.wpOllamaOk ? "‹  " + root.wpTextModel + "  ›" : "Unavailable"
                            color: root.wpOllamaOk ? Theme.subtext : Theme.red
                            font.pixelSize: Theme.textSm
                        }
                    }

                    ListRow {
                        selected: root.selectedIndex === 4
                        label: "Retag all wallpapers"
                        sublabel: root.wpOllamaOk ? "Uses the local Ollama models above" : "Ollama is not running"
                        onClicked: { root.selectedIndex = 4; keyNav.activateItem() }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.wpTagging ? "Tagging…" : "Start"
                            color: root.wpTagging ? Theme.accent : Theme.subtext
                            font.pixelSize: Theme.textSm
                        }
                    }

                    ListRow {
                        selected: root.selectedIndex === 5
                        label: "Generate thumbnails"
                        onClicked: { root.selectedIndex = 5; keyNav.activateItem() }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.wpGenThumb ? "Generating…" : "Start"
                            color: root.wpGenThumb ? Theme.accent : Theme.subtext
                            font.pixelSize: Theme.textSm
                        }
                    }
                }
            }

            }
        }

        // ── Fuzzy search overlay ───────────────────────────────
        Item {
            anchors.fill: parent
            opacity: keyNav.searchOpacity
            visible: keyNav.searchOpacity > 0
            enabled: root.searchQuery !== "" || root.immediateSearch || (Theme.vimBinds && root.vimSearchMode)

            Rectangle { anchors.fill: parent; color: Theme.base }

            // Search field
            Rectangle {
                id: searchBar
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                height: 44
                radius: Theme.radiusMd
                color: Theme.hover

                Icon {
                    id: searchIcon
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    name: "magnify"
                    size: 18
                    color: Theme.subtext
                }

                Row {
                    anchors { left: searchIcon.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 1

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.searchQuery
                        font.pixelSize: Theme.textLg - 2
                    }

                    Rectangle {
                        width: 2
                        height: 20
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.searchQuery !== "" || root.immediateSearch || (Theme.vimBinds && root.vimSearchMode)
                            NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                        }
                    }
                }

                Label {
                    anchors { left: searchIcon.right; leftMargin: 13; verticalCenter: parent.verticalCenter }
                    visible: root.searchQuery === ""
                    text: "Search apps, settings, files, emoji…"
                    color: Theme.subtext
                    font.pixelSize: Theme.textLg - 2
                }

                Label {
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    visible: root.searchQuery !== ""
                    text: root.searchResults.length === 0 ? "No results"
                        : root.searchResults.length + (root.searchResults.length === 1 ? " result" : " results")
                    color: Theme.subtext
                    font.pixelSize: Theme.textSm
                }
            }

            ListView {
                id: searchList
                anchors { left: parent.left; right: parent.right; top: searchBar.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                model: root.searchResults
                clip: true

                delegate: ListRow {
                    id: resultRow
                    required property var modelData
                    required property int index
                    readonly property string kind: modelData.type
                    selected: root.selectedSearchIndex === index
                    label: kind === "math" ? "= " + modelData.label
                         : kind === "web" ? "Search the web for “" + modelData.label + "”"
                         : modelData.label
                    mono: kind === "clipboard" || kind === "file"
                    sublabel: kind === "layout" ? modelData.desc
                            : kind === "menu" ? "Settings"
                            : kind === "file" ? (modelData.isDir ? "Folder" : "File")
                            : kind === "math" ? modelData.expr + " · Enter to copy"
                            : kind === "web" ? "DuckDuckGo"
                            : kind === "clipboard" ? "Clipboard"
                            : kind === "system_item" ? (modelData.sub || "System setting")
                            : kind === "bar_module" ? "Bar layout"
                            : kind === "emoji" ? "Emoji"
                            : kind === "wifi" ? (modelData.inUse ? "Wi-Fi · Connected" : "Wi-Fi")
                            : kind === "bluetooth" ? (modelData.connected ? "Bluetooth · Connected" : "Bluetooth")
                            : kind === "app" ? "Application"
                            : kind === "wallpaper" ? "Wallpaper"
                            : kind === "palette" ? "Color palette"
                            : ""
                    icon: kind === "menu" ? "cog"
                        : kind === "file" ? (modelData.isDir ? "folder" : "file")
                        : kind === "math" ? "calculator"
                        : kind === "web" ? "web"
                        : kind === "clipboard" ? "clipboard"
                        : kind === "system_item" || kind === "bar_module" ? "cog"
                        : kind === "wifi" ? "wifi"
                        : kind === "bluetooth" ? "bluetooth"
                        : kind === "palette" ? "palette"
                        : ""
                    leading: kind === "app" ? appIconComp
                           : kind === "emoji" ? emojiComp
                           : kind === "wallpaper" ? wallpaperComp
                           : kind === "layout" ? layoutComp
                           : null
                    onClicked: { root.selectedSearchIndex = index; keyNav.activateSearchItem() }

                    Component {
                        id: appIconComp
                        Image {
                            width: 28; height: 28
                            source: root.resolveIcon(resultRow.modelData.icon)
                            sourceSize: Qt.size(56, 56)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }
                    Component {
                        id: emojiComp
                        Text {
                            width: 28
                            text: resultRow.modelData.e
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    Component {
                        id: wallpaperComp
                        Rectangle {
                            width: 48; height: 30
                            radius: Theme.radiusSm
                            color: Theme.hover
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: "file://" + root.wallpapersDir + resultRow.modelData.file
                                sourceSize: Qt.size(96, 60)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                    }
                    Component {
                        id: layoutComp
                        LayoutGlyph { layoutId: resultRow.modelData.id }
                    }

                    Swatches {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: resultRow.kind === "palette"
                        colors: resultRow.kind === "palette" ? resultRow.modelData.swatches : []
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (resultRow.kind === "layout" && root.currentLayout === resultRow.modelData.id) ||
                                 (resultRow.kind === "palette" && Theme.name === resultRow.modelData.id)
                        name: "check"
                        size: 16
                        color: Theme.accent
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: resultRow.kind === "menu" || (resultRow.kind === "file" && resultRow.modelData.isDir)
                        name: "chevronRight"
                        size: 16
                        color: Theme.subtext
                    }
                }
            }
        }
    }

    // Small schematic of a tiling layout.
    component LayoutGlyph: Rectangle {
        property string layoutId: ""
        width: 34; height: 26
        radius: 4
        color: Theme.hover

        readonly property color tile: Theme.alpha(Theme.text, 0.35)

        Row {
            visible: parent.layoutId === "dwindle"
            anchors.centerIn: parent; spacing: 2
            Rectangle { width: 13; height: 20; radius: 2; color: parent.parent.tile }
            Column {
                spacing: 2
                Rectangle { width: 13; height: 9; radius: 2; color: parent.parent.parent.tile }
                Row {
                    spacing: 2
                    Rectangle { width: 5.5; height: 9; radius: 1.5; color: parent.parent.parent.parent.tile }
                    Rectangle { width: 5.5; height: 9; radius: 1.5; color: parent.parent.parent.parent.tile }
                }
            }
        }
        Row {
            visible: parent.layoutId === "master"
            anchors.centerIn: parent; spacing: 2
            Rectangle { width: 16; height: 20; radius: 2; color: parent.parent.tile }
            Column {
                spacing: 2
                Rectangle { width: 10; height: 9; radius: 2; color: parent.parent.parent.tile }
                Rectangle { width: 10; height: 9; radius: 2; color: parent.parent.parent.tile }
            }
        }
        Row {
            visible: parent.layoutId === "scrolling"
            anchors.centerIn: parent; spacing: 2
            Repeater {
                model: 3
                Rectangle { width: 8; height: 20; radius: 2; color: Theme.alpha(Theme.text, 0.35) }
            }
        }
        Rectangle {
            visible: parent.layoutId === "monocle"
            anchors.centerIn: parent
            width: 28; height: 20; radius: 2; color: parent.tile
        }
    }

    // Row of palette color dots.
    component Swatches: Row {
        property var colors: []
        spacing: 3
        Repeater {
            model: parent.colors
            delegate: Rectangle {
                required property var modelData
                width: 10; height: 10; radius: 5
                color: modelData
            }
        }
    }
}
