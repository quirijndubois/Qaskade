import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import "../"

FloatingWindow {
    id: root
    implicitWidth: 520
    implicitHeight: 420
    color: Theme.base
    title: "Quickshell Settings"

    signal closeRequested()

    property bool focusGrabReady: false

    HyprlandFocusGrab {
        windows: [root]
        active: root.focusGrabReady
        onCleared: root.closeRequested()
    }

    Timer {
        id: focusGrabTimer
        interval: 80
        onTriggered: root.focusGrabReady = true
    }

    Timer {
        id: moveMonitorTimer
        interval: 60
        onTriggered: {
            const mon = root.monitorName
            if (mon) {
                moveMonitorProc.command = ["sh", "-c",
                    "hyprctl dispatch focuswindow 'title:Quickshell Settings'" +
                    " ; hyprctl dispatch movewindow 'mon:" + mon + "'" +
                    " ; hyprctl dispatch focuswindow 'title:Quickshell Settings'"]
                moveMonitorProc.running = false
                moveMonitorProc.running = true
            }
        }
    }

    Process {
        id: moveMonitorProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    property string page: "main"
    property string activeSubPage: "appearance"
    property var navStack: []
    property string requestedPage: "main"
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

    readonly property var monitorColors: [Theme.blue, Theme.green, Theme.yellow, Theme.teal, Theme.purple, Theme.red]

    readonly property int sf: Theme.barFontSize

    property var systemSettingItems: {
        const items = []
        items.push({ type: "section", label: "monitors" })
        for (const m of root.systemMonitors) {
            items.push({ type: "scale", label: m.name, sub: m.width + "×" + m.height, monitor: m })
            items.push({ type: "monitor_toggle", label: m.enabled ? "disable" : "enable", monitor: m })
        }
        items.push({ type: "nav", label: "monitor layout", icon: "", page: "monitor_layout" })
        items.push({ type: "font_size", label: "font size" })
        items.push({ type: "section", label: "input" })
        items.push({ type: "sensitivity",    label: "mouse sensitivity" })
        items.push({ type: "natural_scroll", label: "natural scroll" })
        items.push({ type: "scroll_factor",  label: "scroll factor" })
        items.push({ type: "section", label: "window" })
        items.push({ type: "nav", label: "layout", icon: "", page: "layout" })
        items.push({ type: "blur_toggle", label: "blur" })
        items.push({ type: "section", label: "navigation" })
        items.push({ type: "vim_binds", label: "vim binds" })
        return items
    }

    onPageChanged: {
        if (page !== "main") activeSubPage = page
        if (page === "bluetooth") btListProc.running = true
        if (page === "wifi") { root.wifiScanning = true; wifiListProc.running = true }
        if (page !== "wifi") { root.wifiPasswordMode = false; root.wifiPasswordInput = ""; root.wifiPendingNetwork = null; root.wifiError = "" }
        if (page === "layout") layoutQueryProc.running = true
        if (page === "clipboard") { clipDaemonProc.running = true; clipListProc.running = true }
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
            const s = root.fuzzyScore(searchQuery, name)
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
        for (const d of designOptions) {
            const s = Math.max(root.fuzzyScore(searchQuery, d.label), root.fuzzyScore(searchQuery, d.desc))
            if (s > 0) results.push({ score: s, type: "design", label: d.label, id: d.id, desc: d.desc, bars: d.bars, barH: d.barH })
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
        { type: "section", label: "dark" },
        { id: "mocha",       label: "catppuccin mocha",      swatches: ["#89b4fa","#a6e3a1","#f38ba8","#f9e2af","#94e2d5","#cba6f7"] },
        { id: "macchiato",   label: "catppuccin macchiato",  swatches: ["#8aadf4","#a6da95","#ed8796","#eed49f","#8bd5ca","#c6a0f6"] },
        { id: "frappe",      label: "catppuccin frappe",     swatches: ["#8caaee","#a6d189","#e78284","#e5c890","#81c8be","#ca9ee6"] },
        { id: "tokyo-night", label: "tokyo night",           swatches: ["#7aa2f7","#9ece6a","#f7768e","#e0af68","#73daca","#bb9af7"] },
        { id: "gruvbox",     label: "gruvbox",               swatches: ["#83a598","#b8bb26","#fb4934","#fabd2f","#8ec07c","#d3869b"] },
        { id: "nord",        label: "nord",                  swatches: ["#81a1c1","#a3be8c","#bf616a","#ebcb8b","#88c0d0","#b48ead"] },
        { id: "dracula",     label: "dracula",               swatches: ["#6272a4","#50fa7b","#ff5555","#f1fa8c","#8be9fd","#bd93f9"] },
        { id: "rosepine",    label: "rose pine",             swatches: ["#9ccfd8","#31748f","#eb6f92","#f6c177","#ebbcba","#c4a7e7"] },
        { id: "onedark",     label: "one dark",              swatches: ["#61afef","#98c379","#e06c75","#e5c07b","#56b6c2","#c678dd"] },
        { id: "everforest",  label: "everforest",            swatches: ["#7fbbb3","#a7c080","#e67e80","#dbbc7f","#83c092","#d699b6"] },
        { id: "solarized",   label: "solarized dark",        swatches: ["#268bd2","#859900","#dc322f","#b58900","#2aa198","#6c71c4"] },
        { type: "section", label: "light" },
        { id: "latte",       label: "catppuccin latte",      swatches: ["#1e66f5","#40a02b","#d20f39","#df8e1d","#179299","#8839ef"] },
        { id: "solarized-light", label: "solarized light",   swatches: ["#268bd2","#859900","#dc322f","#b58900","#2aa198","#6c71c4"] },
        { id: "gruvbox-light", label: "gruvbox light",       swatches: ["#458588","#689d6a","#cc241d","#d79921","#689d6a","#b16286"] },
        { id: "nord-light",  label: "nord light",            swatches: ["#5e81ac","#a3be8c","#bf616a","#ebcb8b","#88c0d0","#b48ead"] },
        { id: "rosepine-dawn", label: "rose pine dawn",      swatches: ["#286983","#d7827e","#b4637a","#ea9d34","#56949f","#907aa9"] },
        { id: "onelight",    label: "one light",             swatches: ["#4078f2","#50a14f","#e45649","#c18401","#0184bc","#a626a4"] },
    ]

    readonly property var lockscreenOptions: [
        { id: "default",  label: "default",  desc: "clock · date · input" },
        { id: "minimal",  label: "minimal",  desc: "floating dots · zen" },
        { id: "clock",    label: "clock",    desc: "oversized time face" },
        { id: "terminal", label: "terminal", desc: "console login prompt" },
        { id: "split",    label: "split",    desc: "time left · input right" },
        { id: "random",   label: "random",   desc: "different design each lock" },
    ]

    readonly property var designOptions: [
        { id: "default",  label: "default",  desc: "JetBrains Mono · flat",          bars: 1, barH: 6  },
        { id: "compact",  label: "compact",  desc: "JetBrains Mono · slim",          bars: 1, barH: 3  },
        { id: "islands",  label: "islands",  desc: "JetBrains Mono · floating",      bars: 3, barH: 14 },
        { id: "pills",    label: "pills",    desc: "JetBrains Mono · per-module pills", bars: 5, barH: 14 },
        { id: "bold",     label: "bold",     desc: "JetBrains Mono bold · tall",     bars: 1, barH: 10 },
        { id: "minimal",  label: "minimal",  desc: "JetBrains Mono · ultra-thin",    bars: 1, barH: 2  },
        { id: "clean",    label: "clean",    desc: "Noto Sans · sans-serif",         bars: 1, barH: 6  },
        { id: "hacker",   label: "hacker",   desc: "Hack · terminal",                bars: 1, barH: 5  },
    ]

    readonly property var layoutOptions: [
        { id: "dwindle",   label: "dwindle",   desc: "BSP spiral tiling" },
        { id: "master",    label: "master",    desc: "master-stack tiling" },
        { id: "scrolling", label: "scrolling", desc: "infinite horizontal tape" },
        { id: "monocle",   label: "monocle",   desc: "fullscreen stack" },
    ]

    readonly property var barModules: [
        { id: "showMenu",      label: "menu button" },
        { id: "showClock",     label: "clock" },
        { id: "showBattery",   label: "battery" },
        { id: "showCpu",       label: "cpu" },
        { id: "showMemory",    label: "memory" },
        { id: "showGpu",       label: "gpu" },
        { id: "showWorkspaces", label: "workspaces" },
        { id: "showMusic",     label: "music visualizer" },
        { id: "showAudio",     label: "audio" },
        { id: "showBluetooth", label: "bluetooth" },
        { id: "showNetwork",   label: "network" },
        { id: "showInhibit",   label: "inhibit sleep" },
        { id: "showTray",      label: "tray" },
    ]

    property var mainItems: [
        { id: "appearance",    label: "appearance",    icon: "" },
        { id: "apps",          label: "applications",  icon: "" },
        { id: "bluetooth",     label: "bluetooth",     icon: "" },
        { id: "wifi",          label: "wifi",          icon: "󰤡" },
        { id: "clipboard",     label: "clipboard",     icon: "" },
        { id: "notifications", label: "notifications", icon: "" },
        { id: "system",        label: "system",        icon: "" },
    ]

    readonly property var appearanceItems: [
        { id: "wallpaper", label: "wallpaper",    icon: "" },
        { id: "palette",   label: "palette",      icon: "" },
        { id: "design",    label: "bar design",   icon: "" },
        { id: "bar",        label: "bar elements", icon: "" },
        { id: "lockscreen", label: "lock screen",  icon: "󰌮" },
    ]

    onVisibleChanged: {
        if (visible) {
            monitorName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            page = requestedPage
            requestedPage = "main"
            navStack = []
            selectedIndex = 0
            searchQuery = ""
            vimSearchMode = false
            wifiPasswordMode = false
            wifiPasswordInput = ""
            wifiPendingNetwork = null
            wifiError = ""
            Qt.callLater(() => keyNav.forceActiveFocus())
            focusGrabReady = false
            focusGrabTimer.restart()
            moveMonitorTimer.restart()
        } else {
            focusGrabReady = false
            focusGrabTimer.stop()
            moveMonitorTimer.stop()
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
                Theme.updateKittyTheme()
                Theme.updateFirefoxTheme()
                Theme.updateSystemColorScheme()
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
    Process { id: clipProc; stdout: StdioCollector {} }

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
                "--transition-duration", "1.5",
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
        Theme[id] = !Theme[id]
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

        readonly property var level2Pages: ["wallpaper", "palette", "design", "bar", "layout", "monitor_layout", "lockscreen"]
        property real subOffset: level2Pages.indexOf(root.page) >= 0 ? 1.0 : 0.0
        Behavior on subOffset {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        property real searchOpacity: (root.searchQuery !== "" || (Theme.vimBinds && root.vimSearchMode)) ? 1.0 : 0.0
        Behavior on searchOpacity {
            NumberAnimation { duration: 140; easing.type: Easing.InOutQuad }
        }

        Keys.onPressed: event => {
            const inSearch = Theme.vimBinds ? root.vimSearchMode : root.searchQuery !== ""

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

            if (Theme.vimBinds && !inSearch && event.key === Qt.Key_I) {
                root.vimSearchMode = true
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Escape) {
                if (inSearch) {
                    root.searchQuery = ""
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
                    else if (root.page === "wallpaper")
                        wpList.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "palette")
                        paletteList.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "apps")
                        appListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "bluetooth")
                        btListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "wifi")
                        wifiListView.positionViewAtIndex(upScroll, ListView.Contain)
                    else if (root.page === "design")
                        designList.positionViewAtIndex(upScroll, ListView.Contain)
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
                    else if (root.page === "lockscreen")
                        lockscreenList.positionViewAtIndex(upScroll, ListView.Contain)
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
                             : root.page === "wallpaper"      ? Math.max(0, root.wallpaperFiles.length - 1)
                             : root.page === "palette"        ? root.paletteOptions.length - 1
                             : root.page === "apps"           ? Math.max(0, root.appsList.length - 1)
                             : root.page === "bluetooth"      ? Math.max(0, root.bluetoothDevices.length - 1)
                             : root.page === "wifi"           ? Math.max(0, root.wifiNetworks.length - 1)
                             : root.page === "design"         ? root.designOptions.length - 1
                             : root.page === "layout"         ? root.layoutOptions.length - 1
                             : root.page === "bar"            ? Math.max(0, root.barModules.length - 1)
                             : root.page === "clipboard"      ? Math.max(0, root.clipboardItems.length - 1)
                             : root.page === "notifications"  ? Math.max(0, notifListView.count - 1)
                             : root.page === "system"         ? Math.max(0, root.systemSettingItems.length - 1)
                             : root.page === "lockscreen"     ? root.lockscreenOptions.length - 1
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
                    else if (root.page === "wallpaper")
                        wpList.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "palette")
                        paletteList.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "apps")
                        appListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "bluetooth")
                        btListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "wifi")
                        wifiListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "design")
                        designList.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "layout")
                        layoutList.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "bar")
                        barListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "clipboard")
                        clipListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "notifications")
                        notifListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "system")
                        sysListView.positionViewAtIndex(downScroll, ListView.Contain)
                    else if (root.page === "lockscreen")
                        lockscreenList.positionViewAtIndex(downScroll, ListView.Contain)
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

            if (event.key === Qt.Key_A && root.page === "wallpaper" && !inSearch) {
                root.extractWallpaperPalette()
                event.accepted = true
                return
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
                    root.searchQuery += event.text
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
            } else if (root.page === "wallpaper" && root.wallpaperFiles.length > 0) {
                root.applyWallpaper(root.wallpaperFiles[root.selectedIndex])
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
            } else if (root.page === "design") {
                const d = root.designOptions[root.selectedIndex]
                if (d) Theme.design = d.id
            } else if (root.page === "lockscreen") {
                const ld = root.lockscreenOptions[root.selectedIndex]
                if (ld) Theme.lockDesign = ld.id
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
            else if (result.type === "design") { Theme.design = result.id }
            else if (result.type === "layout") { root.applyLayout(result.id) }
            else if (result.type === "menu") { root.page = result.id; root.selectedIndex = 0 }
            else if (result.type === "clipboard") { root.copyClipboardItem(result.line); root.closeRequested(); return }
            else if (result.type === "system_item") { root.page = result.page; root.selectedIndex = result.index }
            else if (result.type === "bar_module") { root.page = result.page; root.selectedIndex = result.index }
            root.searchQuery = ""
        }

        // ── Main page ──────────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height
            x: -parent.width * keyNav.offset

            Rectangle {
                id: mainHeader
                width: parent.width
                height: 44
                color: Theme.surface

                Text {
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    text: "settings"
                    color: Theme.purple
                    font.family: "JetBrains Mono"
                    font.pixelSize: sf + 1
                    font.bold: true
                }
            }

            Rectangle { anchors.top: mainHeader.bottom; width: parent.width; height: 1; color: Theme.border }

            ListView {
                id: mainList
                anchors { left: parent.left; right: parent.right; top: mainHeader.bottom; bottom: parent.bottom; topMargin: 1 }
                model: root.mainItems
                clip: true

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: mainList.width
                    height: 44
                    color: root.selectedIndex === index ? Theme.border : "transparent"

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 10

                        Text {
                            text: root.selectedIndex === index ? ">" : " "
                            color: Theme.blue
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf
                            verticalAlignment: Text.AlignVCenter
                            width: 12
                        }

                        Text {
                            text: modelData.icon || ""
                            color: Theme.purple
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: sf + 1
                            verticalAlignment: Text.AlignVCenter
                            width: 20
                        }

                        Text {
                            text: modelData.label
                            color: root.selectedIndex === index ? Theme.text : Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        text: ">"
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 1
                    }

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

                Rectangle {
                    id: appearanceHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "appearance"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle { id: appearanceDivider; anchors.top: appearanceHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                ListView {
                    id: appearanceList
                    anchors { left: parent.left; right: parent.right; top: appearanceDivider.bottom; bottom: parent.bottom; topMargin: 1 }
                    model: root.appearanceItems
                    clip: true
                    interactive: false

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: appearanceList.width
                        height: 44
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        Row {
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 10

                            Text {
                                text: root.selectedIndex === index ? ">" : " "
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                                width: 12
                            }

                            Text {
                                text: modelData.icon || ""
                                color: Theme.purple
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: sf + 1
                                verticalAlignment: Text.AlignVCenter
                                width: 20
                            }

                            Text {
                                text: modelData.label
                                color: root.selectedIndex === index ? Theme.text : Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Text {
                            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                            text: ">"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                        }
                    }
                }
            }

            // ── Applications ───────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "apps"

                Rectangle {
                    id: appsHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "applications"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        text: root.appsList.length + " apps"
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 2
                    }
                }

                Rectangle { id: appsDivider; anchors.top: appsHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                Text {
                    anchors.centerIn: parent
                    visible: root.appsList.length === 0
                    text: "loading..."
                    color: Theme.subtext
                    font.family: "JetBrains Mono"
                    font.pixelSize: sf
                }

                ListView {
                    id: appListView
                    anchors { left: parent.left; right: parent.right; top: appsDivider.bottom; bottom: parent.bottom }
                    model: root.appsList
                    clip: true
                    visible: root.appsList.length > 0

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: appListView.width
                        height: 56
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        Row {
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 14

                            Text {
                                text: root.selectedIndex === index ? ">" : " "
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                text: modelData.name
                                color: root.selectedIndex === index ? Theme.text : Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Rectangle {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            width: 45
                            height: 45
                            radius: 4
                            color: Theme.surface
                            clip: true

                            Image {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                source: root.resolveIcon(modelData.icon)
                                sourceSize: Qt.size(32, 32)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }
                        }

                    }
                }
            }


            // ── Bluetooth ──────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "bluetooth"

                Rectangle {
                    id: btHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "bluetooth"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        text: root.bluetoothDevices.length + " known"
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 2
                    }
                }

                Rectangle { id: btDivider; anchors.top: btHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                Text {
                    anchors.centerIn: parent
                    visible: root.bluetoothDevices.length === 0
                    text: "no known devices"
                    color: Theme.subtext
                    font.family: "JetBrains Mono"
                    font.pixelSize: sf
                }

                ListView {
                    id: btListView
                    anchors { left: parent.left; right: parent.right; top: btDivider.bottom; bottom: parent.bottom }
                    model: root.bluetoothDevices
                    clip: true
                    visible: root.bluetoothDevices.length > 0

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: btListView.width
                        height: 56
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        Row {
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 14

                            Text {
                                text: root.selectedIndex === index ? ">" : " "
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                text: modelData.name
                                color: root.selectedIndex === index ? Theme.text : Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Rectangle {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            width: 45
                            height: 45
                            radius: 4
                            color: Theme.surface

                            Rectangle {
                                anchors.centerIn: parent
                                width: 10
                                height: 10
                                radius: 5
                                color: modelData.connected ? Theme.green
                                     : modelData.paired    ? Theme.blue
                                     : Theme.subtext
                                opacity: modelData.connected ? 1.0 : 0.35
                            }
                        }

                    }
                }
            }

            // ── WiFi ──────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "wifi"

                Rectangle {
                    id: wifiHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "wifi"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        text: root.wifiScanning ? "scanning..." : root.wifiNetworks.length + " networks"
                        color: root.wifiScanning ? Theme.blue : Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 2
                    }
                }

                Rectangle { id: wifiDivider; anchors.top: wifiHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                Text {
                    anchors.centerIn: parent
                    visible: !root.wifiScanning && root.wifiNetworks.length === 0 && !root.wifiPasswordMode
                    text: "no networks found"
                    color: Theme.subtext
                    font.family: "JetBrains Mono"
                    font.pixelSize: sf
                }

                ListView {
                    id: wifiListView
                    anchors { left: parent.left; right: parent.right; top: wifiDivider.bottom; bottom: parent.bottom }
                    model: root.wifiNetworks
                    clip: true
                    visible: root.wifiNetworks.length > 0 && !root.wifiPasswordMode

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: wifiListView.width
                        height: 52
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        Row {
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 14

                            Text {
                                text: root.selectedIndex === index ? ">" : " "
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: modelData.ssid
                                    color: modelData.inUse ? Theme.green
                                         : root.selectedIndex === index ? Theme.text : Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf
                                }

                                Text {
                                    visible: modelData.security !== ""
                                    text: modelData.security
                                    color: Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf - 3
                                }
                            }
                        }

                        Text {
                            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            text: modelData.signal >= 75 ? "▂▄▆█"
                                : modelData.signal >= 50 ? "▂▄▆ "
                                : modelData.signal >= 25 ? "▂▄  "
                                :                          "▂   "
                            color: modelData.signal >= 75 ? Theme.green
                                 : modelData.signal >= 50 ? Theme.yellow
                                 : modelData.signal >= 25 ? Theme.teal
                                 :                          Theme.red
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 1
                            color: Theme.border; opacity: 0.3
                        }
                    }
                }

                // Password overlay
                Item {
                    anchors { left: parent.left; right: parent.right; top: wifiDivider.bottom; bottom: parent.bottom }
                    visible: root.wifiPasswordMode

                    Column {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        anchors.verticalCenterOffset: -16
                        spacing: 0

                        // Network name
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.wifiPendingNetwork ? root.wifiPendingNetwork.ssid : ""
                            color: Theme.text
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 3
                            font.bold: true
                        }

                        Item { width: 1; height: 4 }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.wifiPendingNetwork ? root.wifiPendingNetwork.security : ""
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 3
                        }

                        Item { width: 1; height: 20 }

                        // Password field
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; leftMargin: 24; rightMargin: 24 }
                            height: 38
                            color: Theme.border
                            radius: 6

                            Row {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 0

                                Text {
                                    text: "•".repeat(root.wifiPasswordInput.length)
                                    color: Theme.text
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf + 2
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Rectangle {
                                    width: 2; height: sf + 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.blue
                                    visible: wifiCursorBlink.blinkOn
                                }
                            }

                            Text {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                visible: root.wifiPasswordInput === ""
                                text: "password"
                                color: Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf - 3
                            }
                        }

                        Item { width: 1; height: 14 }

                        // Error message
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.wifiError !== ""
                            text: root.wifiError
                            color: Theme.red
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 3
                            elide: Text.ElideRight
                            width: parent.width - 48
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

                Rectangle {
                    id: clipHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "clipboard"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        text: root.clipboardItems.length + " entries"
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 2
                    }
                }

                Rectangle { id: clipDivider; anchors.top: clipHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                Text {
                    anchors.centerIn: parent
                    visible: root.clipboardItems.length === 0
                    text: "no history yet"
                    color: Theme.subtext
                    font.family: "JetBrains Mono"
                    font.pixelSize: sf - 2
                }

                ListView {
                    id: clipListView
                    anchors { left: parent.left; right: parent.right; top: clipDivider.bottom; bottom: parent.bottom }
                    model: root.clipboardItems
                    clip: true
                    visible: root.clipboardItems.length > 0

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: clipListView.width
                        height: 44
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        Row {
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 14

                            Text {
                                text: root.selectedIndex === index ? ">" : " "
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                text: modelData.preview
                                color: root.selectedIndex === index ? Theme.text : Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                width: clipListView.width - 80
                            }
                        }

                    }
                }
            }

            // ── Notifications ──────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "notifications"

                Rectangle {
                    id: notifHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "notifications"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Row {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 12

                        Text {
                            text: notifListView.count + " total"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 2
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            visible: notifListView.count > 0
                            text: "clear all"
                            color: Theme.red
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 2
                            verticalAlignment: Text.AlignVCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearNotificationsAnimated()
                            }
                        }
                    }
                }

                Rectangle { id: notifDivider; anchors.top: notifHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                Text {
                    anchors.centerIn: parent
                    visible: notifListView.count === 0
                    text: "no notifications"
                    color: Theme.subtext
                    font.family: "JetBrains Mono"
                    font.pixelSize: sf
                }

                ListView {
                    id: notifListView
                    anchors { left: parent.left; right: parent.right; top: notifDivider.bottom; bottom: parent.bottom }
                    model: Notifications.history
                    clip: true
                    visible: notifListView.count > 0

                    delegate: Rectangle {
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
                        height: 64
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        // Urgency bar on left edge
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 3
                            color: modelData.urgency === NotificationUrgency.Critical ? Theme.red
                                 : modelData.urgency === NotificationUrgency.Low      ? Theme.subtext
                                 : Theme.blue
                        }

                        Column {
                            anchors {
                                left: parent.left; leftMargin: 16
                                right: dismissBtn.left; rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 3

                            Text {
                                width: parent.width
                                text: modelData.appName || "unknown"
                                color: modelData.urgency === NotificationUrgency.Critical ? Theme.red
                                     : modelData.urgency === NotificationUrgency.Low      ? Theme.subtext
                                     : Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf - 3
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: modelData.summary || ""
                                color: root.selectedIndex === index ? Theme.text : Theme.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                font.bold: true
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            Text {
                                width: parent.width
                                text: modelData.body || ""
                                color: Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf - 3
                                elide: Text.ElideRight
                                visible: text !== ""
                            }
                        }

                        Text {
                            id: dismissBtn
                            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            text: "x"
                            color: root.selectedIndex === index ? Theme.red : Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notifDelegate.dismiss()
                            }
                        }

                    }
                }
            }

            // ── System ────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "system"

                Rectangle {
                    id: sysHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "system"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle { id: sysDivider; anchors.top: sysHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                ListView {
                    id: sysListView
                    anchors { left: parent.left; right: parent.right; top: sysDivider.bottom; bottom: parent.bottom }
                    model: root.systemSettingItems
                    clip: true
                    interactive: true
                    onCountChanged: if (root.activeSubPage === "system") Qt.callLater(() => contentY = 0)

                    delegate: Item {
                        id: sysDelegate
                        required property var modelData
                        required property int index
                        property bool isSection: sysDelegate.modelData.type === "section"
                        property bool isSelected: root.selectedIndex === sysDelegate.index

                        width: sysListView.width
                        height: isSection ? 32 : 48

                        // Section header background
                        Rectangle {
                            anchors.fill: parent
                            visible: sysDelegate.isSection
                            color: Theme.surface

                            Text {
                                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                                text: sysDelegate.modelData.label || ""
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf - 2
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: { /* sections are not selectable */ }
                            }
                        }

                        // Interactive row
                        Rectangle {
                            anchors.fill: parent
                            visible: !sysDelegate.isSection
                            color: sysDelegate.isSelected ? Theme.border : "transparent"

                            // Cursor indicator
                            Text {
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                visible: sysDelegate.isSelected
                                text: ">"
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                            }

                            // Label column
                            Column {
                                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                                spacing: 2

                                Text {
                                    text: sysDelegate.modelData.label || ""
                                    color: sysDelegate.isSelected ? Theme.text : Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf - 1
                                }

                                Text {
                                    visible: (sysDelegate.modelData.sub || "") !== ""
                                    text: sysDelegate.modelData.sub || ""
                                    color: Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf - 3
                                }
                            }

                            // Scale chips
                            Row {
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                visible: sysDelegate.modelData.type === "scale"
                                spacing: 4

                                Repeater {
                                    id: scaleRep
                                    property var entry: sysDelegate.modelData
                                    model: [1, 1.25, 1.5, 2]

                                    delegate: Rectangle {
                                        id: scaleChip
                                        required property var modelData
                                        property bool active: scaleRep.entry.monitor
                                            ? Math.abs(scaleRep.entry.monitor.scale - scaleChip.modelData) < 0.01
                                            : false
                                        width: 36; height: 22; radius: 3
                                        color: active ? Theme.blue : Theme.surface

                                        Text {
                                            anchors.centerIn: parent
                                            text: scaleChip.modelData % 1 === 0
                                                ? Math.round(scaleChip.modelData) + "×"
                                                : scaleChip.modelData + "×"
                                            color: active ? Theme.base : Theme.subtext
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: sf - 4
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.selectedIndex = sysDelegate.index
                                                root.setMonitorScale(scaleRep.entry.monitor, scaleChip.modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            // Stepper (+/value/−) for sensitivity, scroll_factor, and font_size
                            Row {
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                visible: sysDelegate.modelData.type === "sensitivity" || sysDelegate.modelData.type === "scroll_factor" || sysDelegate.modelData.type === "font_size"
                                spacing: 10

                                Text {
                                    text: "−"
                                    color: (sysDelegate.modelData.type === "sensitivity" && root.mouseSensitivity <= -1.0) ||
                                           (sysDelegate.modelData.type === "scroll_factor" && root.scrollFactor <= 0.1) ||
                                           (sysDelegate.modelData.type === "font_size" && Theme.barFontSize <= 8)
                                           ? Theme.surface : Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf + 3
                                    verticalAlignment: Text.AlignVCenter
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedIndex = sysDelegate.index
                                            if (sysDelegate.modelData.type === "sensitivity") root.setMouseSensitivity(root.mouseSensitivity - 0.1)
                                            else if (sysDelegate.modelData.type === "scroll_factor") root.setScrollFactor(root.scrollFactor - 0.05)
                                            else if (sysDelegate.modelData.type === "font_size") Theme.barFontSize = Math.max(8, Theme.barFontSize - 1)
                                        }
                                    }
                                }

                                Text {
                                    text: sysDelegate.modelData.type === "sensitivity"
                                        ? root.mouseSensitivity.toFixed(2)
                                        : sysDelegate.modelData.type === "scroll_factor"
                                        ? root.scrollFactor.toFixed(2)
                                        : Theme.barFontSize
                                    color: Theme.text
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf - 1
                                    width: 44
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: "+"
                                    color: (sysDelegate.modelData.type === "sensitivity" && root.mouseSensitivity >= 1.0) ||
                                           (sysDelegate.modelData.type === "scroll_factor" && root.scrollFactor >= 3.0) ||
                                           (sysDelegate.modelData.type === "font_size" && Theme.barFontSize >= 20)
                                           ? Theme.surface : Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf + 1
                                    verticalAlignment: Text.AlignVCenter
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedIndex = sysDelegate.index
                                            if (sysDelegate.modelData.type === "sensitivity") root.setMouseSensitivity(root.mouseSensitivity + 0.1)
                                            else if (sysDelegate.modelData.type === "scroll_factor") root.setScrollFactor(root.scrollFactor + 0.05)
                                            else if (sysDelegate.modelData.type === "font_size") Theme.barFontSize = Math.min(20, Theme.barFontSize + 1)
                                        }
                                    }
                                }
                            }

                            // Toggle for natural_scroll
                            Rectangle {
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                visible: sysDelegate.modelData.type === "natural_scroll"
                                width: 34; height: 18; radius: 9
                                color: root.naturalScroll ? Theme.green : Theme.border
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Rectangle {
                                    width: 12; height: 12; radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.base
                                    x: root.naturalScroll ? parent.width - width - 3 : 3
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.selectedIndex = sysDelegate.index; root.setNaturalScroll(!root.naturalScroll) }
                                }
                            }

                            // Toggle for blur
                            Rectangle {
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                visible: sysDelegate.modelData.type === "blur_toggle"
                                width: 34; height: 18; radius: 9
                                color: root.blurEnabled ? Theme.green : Theme.border
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Rectangle {
                                    width: 12; height: 12; radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.base
                                    x: root.blurEnabled ? parent.width - width - 3 : 3
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.selectedIndex = sysDelegate.index; root.setBlur(!root.blurEnabled) }
                                }
                            }

                            // Toggle for vim binds
                            Rectangle {
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                visible: sysDelegate.modelData.type === "vim_binds"
                                width: 34; height: 18; radius: 9
                                color: Theme.vimBinds ? Theme.green : Theme.border
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Rectangle {
                                    width: 12; height: 12; radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.base
                                    x: Theme.vimBinds ? parent.width - width - 3 : 3
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.selectedIndex = sysDelegate.index; Theme.vimBinds = !Theme.vimBinds }
                                }
                            }

                            // Toggle for monitor enable/disable
                            Rectangle {
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                visible: sysDelegate.modelData.type === "monitor_toggle"
                                property var entry: sysDelegate.modelData
                                property bool isOn: entry.monitor && entry.monitor.enabled
                                property bool canDisable: root.systemMonitors.filter(m => m.enabled).length > 1
                                width: 34; height: 18; radius: 9
                                opacity: (!isOn && !canDisable) ? 0.35 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                color: isOn ? Theme.green : Theme.border
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Rectangle {
                                    width: 12; height: 12; radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.base
                                    x: parent.isOn ? parent.width - width - 3 : 3
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: (parent.canDisable || parent.isOn) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                    onClicked: { root.selectedIndex = sysDelegate.index; root.setMonitorEnabled(sysDelegate.modelData.monitor, !sysDelegate.modelData.monitor.enabled) }
                                }
                            }

                            // Arrow for nav items
                            Text {
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                visible: sysDelegate.modelData.type === "nav"
                                text: "›"
                                color: sysDelegate.isSelected ? Theme.blue : Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf + 5
                            }

                            MouseArea {
                                anchors.fill: parent
                                visible: sysDelegate.modelData.type === "nav"
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.selectedIndex = sysDelegate.index; keyNav.navigateTo(sysDelegate.modelData.page) }
                            }

                            MouseArea {
                                anchors.fill: parent
                                visible: sysDelegate.modelData.type !== "scale" && sysDelegate.modelData.type !== "sensitivity" && sysDelegate.modelData.type !== "natural_scroll" && sysDelegate.modelData.type !== "scroll_factor" && sysDelegate.modelData.type !== "font_size" && sysDelegate.modelData.type !== "monitor_toggle" && sysDelegate.modelData.type !== "nav"
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.selectedIndex = sysDelegate.index }
                            }

                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 1
                            color: Theme.border; opacity: 0.3
                            visible: !sysDelegate.isSection
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

                Rectangle {
                    id: layoutHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "layout"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle { id: layoutDivider; anchors.top: layoutHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                ListView {
                    id: layoutList
                    anchors { left: parent.left; right: parent.right; top: layoutDivider.bottom; bottom: parent.bottom }
                    model: root.layoutOptions
                    clip: true
                    interactive: false

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: layoutList.width
                        height: 56
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        Row {
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 14

                            Text {
                                text: root.selectedIndex === index ? ">" : " "
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    text: modelData.label
                                    color: root.selectedIndex === index ? Theme.text : Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf
                                }

                                Text {
                                    text: modelData.desc
                                    color: Theme.teal
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf - 3
                                }
                            }
                        }

                        // Layout diagram
                        Rectangle {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            width: 45; height: 45; radius: 4; color: Theme.surface

                            // dwindle: left tall + right top wide + right bottom pair
                            Row {
                                visible: modelData.id === "dwindle"
                                anchors.centerIn: parent; spacing: 1
                                Rectangle { width: 16; height: 37; radius: 2; color: Theme.blue; opacity: 0.45 }
                                Column {
                                    spacing: 1
                                    Rectangle { width: 20; height: 18; radius: 2; color: Theme.blue; opacity: 0.45 }
                                    Row {
                                        spacing: 1
                                        Rectangle { width: 9; height: 18; radius: 2; color: Theme.blue; opacity: 0.45 }
                                        Rectangle { width: 9; height: 18; radius: 2; color: Theme.blue; opacity: 0.45 }
                                    }
                                }
                            }

                            // master: tall left + stacked right
                            Row {
                                visible: modelData.id === "master"
                                anchors.centerIn: parent; spacing: 1
                                Rectangle { width: 20; height: 37; radius: 2; color: Theme.blue; opacity: 0.45 }
                                Column {
                                    spacing: 1
                                    Rectangle { width: 16; height: 18; radius: 2; color: Theme.blue; opacity: 0.45 }
                                    Rectangle { width: 16; height: 18; radius: 2; color: Theme.blue; opacity: 0.45 }
                                }
                            }

                            // scrolling: three equal columns
                            Row {
                                visible: modelData.id === "scrolling"
                                anchors.centerIn: parent; spacing: 1
                                Rectangle { width: 11; height: 37; radius: 2; color: Theme.blue; opacity: 0.45 }
                                Rectangle { width: 11; height: 37; radius: 2; color: Theme.blue; opacity: 0.45 }
                                Rectangle { width: 11; height: 37; radius: 2; color: Theme.blue; opacity: 0.45 }
                            }

                            // monocle: single full window
                            Rectangle {
                                visible: modelData.id === "monocle"
                                anchors.centerIn: parent
                                width: 37; height: 37; radius: 2; color: Theme.blue; opacity: 0.45
                            }
                        }

                        Text {
                            anchors { right: parent.right; rightMargin: 64; verticalCenter: parent.verticalCenter }
                            visible: root.currentLayout === modelData.id
                            text: "*"
                            color: Theme.green
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf
                        }

                    }
                }
            }

            // ── Monitor Layout ──────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "monitor_layout"

                Rectangle {
                    id: monLayoutHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "monitor layout"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: ""
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 3
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 20
                        }
                    }
                }

                Rectangle { id: monLayoutDivider; anchors.top: monLayoutHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                Item {
                    id: monLayoutCanvas
                    anchors { left: parent.left; right: parent.right; top: monLayoutDivider.bottom; bottom: wsPanel.top; margins: 16 }

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

                            x: modelData.x * monLayoutCanvas.monScale + monLayoutCanvas.offsetX
                            y: modelData.y * monLayoutCanvas.monScale + monLayoutCanvas.offsetY
                            width:  (modelData.width  / modelData.scale) * monLayoutCanvas.monScale
                            height: (modelData.height / modelData.scale) * monLayoutCanvas.monScale

                            color: root.selectedMonitorIdx === index ? Theme.blue : Theme.surface
                            opacity: modelData.enabled ? 1.0 : 0.35
                            border.width: 0
                            radius: 0

                            // Selection outline drawn outside bounds so it doesn't affect adjacency
                            Rectangle {
                                visible: root.selectedMonitorIdx === index
                                anchors { fill: parent; margins: -2 }
                                color: "transparent"
                                border.color: Theme.blue
                                border.width: 2
                                radius: 2
                                z: 1
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.name
                                    color: root.selectedMonitorIdx === index ? Theme.base : Theme.text
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: Math.max(8, Math.min(13, monLayoutCanvas.monScale * 40))
                                    font.bold: true
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(modelData.width / modelData.scale) + "×" + Math.round(modelData.height / modelData.scale)
                                    color: root.selectedMonitorIdx === index ? Theme.base : Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: Math.max(7, Math.min(10, monLayoutCanvas.monScale * 30))
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.x + "x" + modelData.y
                                    color: root.selectedMonitorIdx === index ? Theme.base : Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: Math.max(7, Math.min(10, monLayoutCanvas.monScale * 30))
                                }
                            }

                        }
                    }
                }

                // ── Workspace assignment panel ──────────────────
                Rectangle {
                    id: wsPanel
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 76
                    color: Theme.surface

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 1; color: Theme.border
                    }

                    Column {
                        anchors { fill: parent; topMargin: 8; leftMargin: 16; rightMargin: 16; bottomMargin: 8 }
                        spacing: 6

                        Text {
                            property var selMon: root.systemMonitors[root.selectedMonitorIdx]
                            text: selMon ? "workspaces → " + selMon.name : "workspaces"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 3
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
                                    property bool onOtherMon: rule && selMon && rule.monitor !== selMon.name
                                    property int otherMonIdx: onOtherMon ? root.systemMonitors.findIndex(m => m.name === rule.monitor) : -1

                                    width: (wsChipRow.width - 9 * wsChipRow.spacing) / 10; height: 36; radius: 3
                                    color: onSelectedMon ? Theme.blue : Theme.surface

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: ws
                                            color: onSelectedMon ? Theme.base : Theme.text
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: sf
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: onSelectedMon ? "✓" : (onOtherMon && otherMonIdx >= 0 ? root.systemMonitors[otherMonIdx].name : (rule ? rule.monitor : "—"))
                                            color: onSelectedMon ? Theme.base : (onOtherMon ? Theme.subtext : Theme.surface)
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: sf - 4
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Wallpaper ──────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "wallpaper"

                Rectangle {
                    id: wpHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "wallpaper"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        text: root.extractingPalette ? "analyzing..." : "a: extract palette"
                        color: root.extractingPalette ? Theme.yellow : Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 2
                    }
                }

                Rectangle { id: wpDivider; anchors.top: wpHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                Text {
                    anchors.centerIn: parent
                    visible: root.wallpaperFiles.length === 0
                    text: "loading..."
                    color: Theme.subtext
                    font.family: "JetBrains Mono"
                    font.pixelSize: sf
                }

                ListView {
                    id: wpList
                    anchors { left: parent.left; right: parent.right; top: wpDivider.bottom; bottom: parent.bottom }
                    model: root.wallpaperFiles
                    clip: true
                    visible: root.wallpaperFiles.length > 0

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: wpList.width
                        height: 56
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        Row {
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 14

                            Text {
                                text: root.selectedIndex === index ? ">" : " "
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                text: modelData.replace(/\.[^.]+$/, "")
                                color: root.selectedIndex === index ? Theme.text : Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Rectangle {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            width: 80
                            height: 45
                            radius: 4
                            color: Theme.surface
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: "file://" + root.wallpapersDir + modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }
                        }

                    }
                }
            }

            // ── Palette ────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "palette"

                Rectangle {
                    id: paletteHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "palette"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle { id: paletteDivider; anchors.top: paletteHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                ListView {
                    id: paletteList
                    anchors { left: parent.left; right: parent.right; top: paletteDivider.bottom; bottom: parent.bottom }
                    model: root.paletteOptions
                    clip: true
                    interactive: false

                    delegate: Item {
                        required property var modelData
                        required property int index
                        property bool isSection: paletteDelegate.modelData.type === "section"
                        property bool isSelected: root.selectedIndex === index

                        width: paletteList.width
                        height: isSection ? 32 : 40

                        id: paletteDelegate

                        // Section header background
                        Rectangle {
                            anchors.fill: parent
                            visible: paletteDelegate.isSection
                            color: Theme.surface

                            Text {
                                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                                text: paletteDelegate.modelData.label || ""
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf - 2
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: { /* sections are not selectable */ }
                            }
                        }

                        // Palette item (interactive)
                        Rectangle {
                            anchors.fill: parent
                            visible: !paletteDelegate.isSection
                            color: paletteDelegate.isSelected ? Theme.border : "transparent"

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedIndex = paletteDelegate.index
                                    Theme.name = paletteDelegate.modelData.id
                                }
                            }

                            Row {
                                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                                spacing: 14

                                Text {
                                    text: paletteDelegate.isSelected ? ">" : " "
                                    color: Theme.blue
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: modelData.label
                                    color: paletteDelegate.isSelected ? Theme.text : Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Row {
                                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                                spacing: 4

                                Repeater {
                                    model: modelData.swatches
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 10; height: 10; radius: 5
                                        color: modelData
                                    }
                                }
                            }

                            Text {
                                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                                visible: Theme.name === modelData.id
                                text: "*"
                                color: Theme.green
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                            }
                        }
                    }
                }
            }

            // ── Design ────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "design"

                Rectangle {
                    id: designHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "bar design"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle { id: designDivider; anchors.top: designHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                ListView {
                    id: designList
                    anchors { left: parent.left; right: parent.right; top: designDivider.bottom; bottom: parent.bottom }
                    model: root.designOptions
                    clip: true
                    interactive: false

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: designList.width
                        height: 56
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        Row {
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 14

                            Text {
                                text: root.selectedIndex === index ? ">" : " "
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    text: modelData.label
                                    color: root.selectedIndex === index ? Theme.text : Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf
                                }

                                Text {
                                    text: modelData.desc
                                    color: Theme.purple
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf - 3
                                }
                            }
                        }

                        // Visual preview of the design layout
                        Row {
                            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 4

                            Repeater {
                                model: modelData.bars
                                Rectangle {
                                    width: modelData.bars === 1 ? 60 : modelData.bars === 5 ? 10 : 18
                                    height: modelData.barH
                                    radius: modelData.bars === 3 ? 4 : modelData.bars === 5 ? modelData.barH / 2 : 2
                                    color: root.selectedIndex === index ? Theme.blue : Theme.subtext
                                    opacity: root.selectedIndex === index ? 0.7 : 0.35
                                }
                            }
                        }

                        Text {
                            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                            visible: Theme.design === modelData.id
                            text: "*"
                            color: Theme.green
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf
                        }

                    }
                }
            }

            // ── Bar ───────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "bar"

                Rectangle {
                    id: barHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "bar elements"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        text: root.barModules.length + " modules"
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 2
                    }
                }

                Rectangle { id: barDivider; anchors.top: barHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                ListView {
                    id: barListView
                    anchors { left: parent.left; right: parent.right; top: barDivider.bottom; bottom: parent.bottom }
                    model: root.barModules
                    clip: true
                    interactive: false

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: barListView.width
                        height: 44
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        Row {
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 14

                            Text {
                                text: root.selectedIndex === index ? ">" : " "
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                text: modelData.label
                                color: root.selectedIndex === index ? Theme.text : Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Rectangle {
                            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            property bool active: !!Theme[modelData.id]
                            width: 34; height: 18; radius: 9
                            color: active ? Theme.green : Theme.border
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                width: 12; height: 12; radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.base
                                x: parent.active ? parent.width - width - 3 : 3
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.selectedIndex = index; root.toggleBarModule(modelData.id) }
                            }
                        }

                    }
                }
            }

            // ── Lock Screen ───────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubPage === "lockscreen"

                Rectangle {
                    id: lockscreenHeader
                    width: parent.width
                    height: 44
                    color: Theme.surface

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: "< back"
                            color: Theme.subtext
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf - 1
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "lock screen"
                            color: Theme.purple
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf + 1
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle { id: lockscreenDivider; anchors.top: lockscreenHeader.bottom; width: parent.width; height: 1; color: Theme.border }

                ListView {
                    id: lockscreenList
                    anchors { left: parent.left; right: parent.right; top: lockscreenDivider.bottom; bottom: parent.bottom }
                    model: root.lockscreenOptions
                    clip: true
                    interactive: false

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: lockscreenList.width
                        height: 60
                        color: root.selectedIndex === index ? Theme.border : "transparent"

                        property bool active: root.selectedIndex === index
                        property color previewColor: active ? Theme.blue : Theme.subtext
                        property real previewOpacity: active ? 0.7 : 0.35

                        Row {
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 14

                            Text {
                                text: active ? ">" : " "
                                color: Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf
                                verticalAlignment: Text.AlignVCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    text: modelData.label
                                    color: active ? Theme.text : Theme.subtext
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf
                                }

                                Text {
                                    text: modelData.desc
                                    color: Theme.purple
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: sf - 3
                                }
                            }
                        }

                        // Visual preview schematic
                        Item {
                            anchors { right: parent.right; rightMargin: 56; verticalCenter: parent.verticalCenter }
                            width: 62; height: 44

                            // default: clock block + separator + password box
                            Column {
                                visible: modelData.id === "default"
                                anchors.centerIn: parent
                                spacing: 3
                                Rectangle { width: 54; height: 14; radius: 2; color: previewColor; opacity: previewOpacity }
                                Rectangle { width: 54; height: 1;  color: previewColor; opacity: previewOpacity * 0.5 }
                                Rectangle { width: 54; height: 12; radius: 2; color: previewColor; opacity: previewOpacity * 0.6 }
                            }

                            // minimal: floating pill
                            Rectangle {
                                visible: modelData.id === "minimal"
                                anchors.centerIn: parent
                                width: 46; height: 16; radius: 8
                                color: "transparent"; border.width: 1
                                border.color: previewColor; opacity: previewOpacity
                            }

                            // clock: large time block + small pill
                            Column {
                                visible: modelData.id === "clock"
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle { width: 54; height: 22; radius: 2; color: previewColor; opacity: previewOpacity }
                                Rectangle { width: 54; height: 10; radius: 5; color: previewColor; opacity: previewOpacity * 0.6 }
                            }

                            // terminal: card outline with lines
                            Rectangle {
                                visible: modelData.id === "terminal"
                                anchors.centerIn: parent
                                width: 54; height: 40; radius: 4
                                color: "transparent"; border.width: 1
                                border.color: previewColor; opacity: previewOpacity

                                Column {
                                    anchors { left: parent.left; top: parent.top; margins: 5 }
                                    spacing: 4
                                    Rectangle { width: 22; height: 3; radius: 1; color: previewColor; opacity: previewOpacity }
                                    Rectangle { width: 38; height: 1; color: previewColor; opacity: previewOpacity * 0.5 }
                                    Rectangle { width: 14; height: 3; radius: 1; color: previewColor; opacity: previewOpacity * 0.6 }
                                }
                            }

                            // random: dice / question mark preview
                            Text {
                                visible: modelData.id === "random"
                                anchors.centerIn: parent
                                text: "?"
                                color: previewColor
                                opacity: previewOpacity
                                font.family: "JetBrains Mono"
                                font.pixelSize: 28; font.bold: true
                            }

                            // split: two columns with divider
                            Item {
                                visible: modelData.id === "split"
                                anchors.centerIn: parent
                                width: 50; height: 36

                                Rectangle { x: 0;  y: 1;  width: 22; height: 34; radius: 2; color: previewColor; opacity: previewOpacity }
                                Rectangle { x: 24; y: 3;  width: 1;  height: 30; color: previewColor; opacity: previewOpacity * 0.5 }
                                Rectangle { x: 27; y: 9;  width: 22; height: 18; radius: 2; color: previewColor; opacity: previewOpacity * 0.6 }
                            }
                        }

                        Text {
                            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                            visible: Theme.lockDesign === modelData.id
                            text: "*"
                            color: Theme.green
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf
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
            enabled: root.searchQuery !== "" || (Theme.vimBinds && root.vimSearchMode)

            Rectangle { anchors.fill: parent; color: Theme.base }

            Rectangle {
                id: searchBar
                width: parent.width
                height: 44
                color: Theme.surface

                Row {
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    spacing: 8

                    Text {
                        text: "/"
                        color: Theme.purple
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf + 1
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        text: root.searchQuery
                        color: Theme.text
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        width: 2
                        height: 14
                        color: Theme.blue
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.searchQuery !== "" || (Theme.vimBinds && root.vimSearchMode)
                            NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                        }
                    }
                }

                Text {
                    anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    text: (Theme.vimBinds && root.vimSearchMode && root.searchQuery === "") ? "type to search"
                        : root.searchResults.length === 0 ? "no results"
                        : root.searchResults.length + " result" + (root.searchResults.length === 1 ? "" : "s")
                    color: Theme.subtext
                    font.family: "JetBrains Mono"
                    font.pixelSize: sf - 2
                }
            }

            Rectangle { id: searchDivider; anchors.top: searchBar.bottom; width: parent.width; height: 1; color: Theme.border }

            ListView {
                id: searchList
                anchors { left: parent.left; right: parent.right; top: searchDivider.bottom; bottom: parent.bottom }
                model: root.searchResults
                clip: true

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: searchList.width
                    height: 52
                    color: root.selectedSearchIndex === index ? Theme.border : "transparent"

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1
                        color: Theme.border
                        opacity: 0.3
                    }

                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 14

                        Text {
                            text: root.selectedSearchIndex === index ? ">" : " "
                            color: Theme.blue
                            font.family: "JetBrains Mono"
                            font.pixelSize: sf
                            verticalAlignment: Text.AlignVCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: modelData.label
                                color: modelData.type === "math" ? Theme.green
                                     : root.selectedSearchIndex === index ? Theme.text : Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: modelData.type === "math" ? sf + 3 : sf
                                font.bold: modelData.type === "math"
                                elide: modelData.type === "clipboard" ? Text.ElideRight : Text.ElideNone
                                width: modelData.type === "clipboard" ? searchList.width - 100 : implicitWidth
                            }

                            Text {
                                text: modelData.type === "design" || modelData.type === "layout" ? modelData.desc
                                    : modelData.type === "menu" ? "open menu"
                                    : modelData.type === "file" ? (modelData.isDir ? "directory" : "file")
                                    : modelData.type === "math" ? modelData.expr
                                    : modelData.type === "web"       ? "search the web"
                                    : modelData.type === "clipboard" ? "clipboard"
                                    : modelData.type === "system_item" ? (modelData.sub || "system setting")
                                    : modelData.type === "bar_module" ? "bar module"
                                    : modelData.type === "wifi" ? (modelData.inUse ? "connected" : "wifi")
                                    : modelData.type
                                color: modelData.type === "wallpaper"  ? Theme.teal
                                     : modelData.type === "palette"    ? Theme.yellow
                                     : modelData.type === "bluetooth"  ? Theme.blue
                                     : modelData.type === "wifi"       ? (modelData.inUse ? Theme.green : Theme.teal)
                                     : modelData.type === "design"     ? Theme.purple
                                     : modelData.type === "layout"     ? Theme.teal
                                     : modelData.type === "menu"       ? Theme.purple
                                     : modelData.type === "file"       ? (modelData.isDir ? Theme.blue : Theme.subtext)
                                     : modelData.type === "math"       ? Theme.subtext
                                     : modelData.type === "web"        ? Theme.yellow
                                     : modelData.type === "clipboard"  ? Theme.teal
                                     : modelData.type === "system_item" ? Theme.blue
                                     : modelData.type === "bar_module" ? Theme.purple
                                     : Theme.blue
                                font.family: "JetBrains Mono"
                                font.pixelSize: sf - 3
                            }
                        }
                    }

                    // Wallpaper thumbnail
                    Rectangle {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 80; height: 45; radius: 4
                        color: Theme.surface
                        clip: true
                        visible: modelData.type === "wallpaper"

                        Image {
                            anchors.fill: parent
                            source: modelData.type === "wallpaper" ? "file://" + root.wallpapersDir + modelData.file : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }
                    }

                    // App icon
                    Rectangle {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 45; height: 45; radius: 4
                        color: Theme.surface
                        clip: true
                        visible: modelData.type === "app"

                        Image {
                            anchors.centerIn: parent
                            width: 32; height: 32
                            source: modelData.type === "app" ? root.resolveIcon(modelData.icon) : ""
                            sourceSize: Qt.size(32, 32)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }
                    }

                    // Bluetooth status dot
                    Rectangle {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 45; height: 45; radius: 4
                        color: Theme.surface
                        visible: modelData.type === "bluetooth"

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10; height: 10; radius: 5
                            color: modelData.type === "bluetooth" && modelData.connected ? Theme.green
                                 : modelData.type === "bluetooth" && modelData.paired    ? Theme.blue
                                 : Theme.subtext
                            opacity: (modelData.type === "bluetooth" && modelData.connected) ? 1.0 : 0.35
                        }
                    }

                    // WiFi signal bars
                    Text {
                        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        visible: modelData.type === "wifi"
                        text: modelData.type === "wifi"
                            ? (modelData.signal >= 75 ? "▂▄▆█"
                             : modelData.signal >= 50 ? "▂▄▆ "
                             : modelData.signal >= 25 ? "▂▄  "
                             :                          "▂   ")
                            : ""
                        color: modelData.type === "wifi"
                             ? (modelData.signal >= 75 ? Theme.green
                              : modelData.signal >= 50 ? Theme.yellow
                              : modelData.signal >= 25 ? Theme.teal
                              :                          Theme.red)
                             : Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 1
                    }

                    // Palette swatches
                    Row {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        visible: modelData.type === "palette"

                        Repeater {
                            model: modelData.type === "palette" ? modelData.swatches : []
                            delegate: Rectangle {
                                required property var modelData
                                width: 10; height: 10; radius: 5
                                color: modelData
                            }
                        }
                    }

                    // Layout diagram
                    Rectangle {
                        id: layoutSearchPrev
                        property var res: modelData
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        visible: layoutSearchPrev.res.type === "layout"
                        width: 45; height: 45; radius: 4; color: Theme.surface

                            Row {
                                visible: layoutSearchPrev.res.type === "layout" && layoutSearchPrev.res.id === "dwindle"
                                anchors.centerIn: parent; spacing: 1
                                Rectangle { width: 16; height: 37; radius: 2; color: Theme.blue; opacity: 0.45 }
                                Column {
                                    spacing: 1
                                    Rectangle { width: 20; height: 18; radius: 2; color: Theme.blue; opacity: 0.45 }
                                    Row {
                                        spacing: 1
                                        Rectangle { width: 9; height: 18; radius: 2; color: Theme.blue; opacity: 0.45 }
                                        Rectangle { width: 9; height: 18; radius: 2; color: Theme.blue; opacity: 0.45 }
                                    }
                                }
                            }
                            Row {
                                visible: layoutSearchPrev.res.type === "layout" && layoutSearchPrev.res.id === "master"
                                anchors.centerIn: parent; spacing: 1
                                Rectangle { width: 20; height: 37; radius: 2; color: Theme.blue; opacity: 0.45 }
                                Column {
                                    spacing: 1
                                    Rectangle { width: 16; height: 18; radius: 2; color: Theme.blue; opacity: 0.45 }
                                    Rectangle { width: 16; height: 18; radius: 2; color: Theme.blue; opacity: 0.45 }
                                }
                            }
                            Row {
                                visible: layoutSearchPrev.res.type === "layout" && layoutSearchPrev.res.id === "scrolling"
                                anchors.centerIn: parent; spacing: 1
                                Rectangle { width: 11; height: 37; radius: 2; color: Theme.blue; opacity: 0.45 }
                                Rectangle { width: 11; height: 37; radius: 2; color: Theme.blue; opacity: 0.45 }
                                Rectangle { width: 11; height: 37; radius: 2; color: Theme.blue; opacity: 0.45 }
                            }
                            Rectangle {
                                visible: layoutSearchPrev.res.type === "layout" && layoutSearchPrev.res.id === "monocle"
                                anchors.centerIn: parent
                                width: 37; height: 37; radius: 2; color: Theme.blue; opacity: 0.45
                            }
                    }

                    // Menu / directory arrow
                    Text {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        visible: modelData.type === "menu" || (modelData.type === "file" && modelData.isDir)
                        text: ">"
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 1
                    }

                    // Math copy hint
                    Text {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        visible: modelData.type === "math"
                        text: "copy"
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 3
                    }

                    // Web open hint
                    Text {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        visible: modelData.type === "web"
                        text: "open"
                        color: Theme.yellow
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf - 3
                    }

                    // Active indicator for designs, layouts, palettes
                    Text {
                        anchors { right: parent.right; rightMargin: modelData.type === "design" || modelData.type === "layout" ? 80 : 20; verticalCenter: parent.verticalCenter }
                        visible: (modelData.type === "design" && Theme.design === modelData.id) ||
                                 (modelData.type === "layout" && root.currentLayout === modelData.id) ||
                                 (modelData.type === "palette" && Theme.name === modelData.id)
                        text: "*"
                        color: Theme.green
                        font.family: "JetBrains Mono"
                        font.pixelSize: sf
                    }

                    // Design bar preview
                    Row {
                        id: designPrevRow
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        visible: modelData.type === "design"
                        property int itemIndex: index

                        Repeater {
                            model: designPrevRow.visible ? modelData.bars : 0
                            Rectangle {
                                width: modelData.bars === 1 ? 60 : modelData.bars === 5 ? 10 : 18
                                height: modelData.barH
                                radius: modelData.bars === 3 ? 4 : modelData.bars === 5 ? modelData.barH / 2 : 2
                                color: root.selectedSearchIndex === designPrevRow.itemIndex ? Theme.blue : Theme.subtext
                                opacity: root.selectedSearchIndex === designPrevRow.itemIndex ? 0.7 : 0.35
                            }
                        }
                    }

                }
            }
        }
    }
}
