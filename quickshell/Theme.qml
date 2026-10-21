pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string name:          "mocha"
    property int    barFontSize:   13
    property int    barHeight:     barFontSize + 19
    property string showMenu:       "disabled"
    property string showClock:      "center"
    property string showBattery:    "center"
    property string showCpu:        "disabled"
    property string showMemory:     "disabled"
    property string showGpu:        "disabled"
    property string showWorkspaces: "center"
    property string showMusic:      "right"
    property string showAudio:      "center"
    property string showBluetooth:  "center"
    property string showNetwork:    "center"
    property string showInhibit:    "disabled"
    property string showTray:       "right"
    property int  gapsOut:        10
    property bool vimBinds:     false

    // ── Design tokens ─────────────────────────────────────────────
    // One sans-serif for all UI text; the first installed family wins.
    readonly property string fontFamily: {
        const installed = Qt.fontFamilies()
        for (const f of ["Inter", "Inter Variable", "SF Pro Text", "Geist", "Noto Sans", "Cantarell"])
            if (installed.indexOf(f) >= 0) return f
        return "sans-serif"
    }
    readonly property string monoFamily: "JetBrains Mono"
    readonly property string iconFamily: "Symbols Nerd Font Mono"

    readonly property int radiusSm: 6
    readonly property int radiusMd: 10
    readonly property int radiusLg: 16

    // Type scale (pixel sizes)
    readonly property int textXs: 11
    readonly property int textSm: 12
    readonly property int textMd: 14
    readonly property int textLg: 17
    readonly property int textXl: 24

    // Tinted overlays derived from the text color, so they work on both
    // dark and light palettes.
    readonly property color hairline: alpha(text, 0.08)
    readonly property color hover:    alpha(text, 0.05)
    readonly property color selected: alpha(text, 0.09)
    readonly property color track:    alpha(text, 0.12)
    readonly property color accent:   blue

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // Monochrome Nerd Font (Material Design) glyphs used across the shell.
    readonly property var icons: ({
        bluetooth:          "\u{F00AF}",
        bluetoothConnected: "\u{F00B1}",
        bluetoothOff:       "\u{F00B2}",
        ethernet:           "\u{F0200}",
        wifiOff:            "\u{F05AA}",
        volumeHigh:         "\u{F057E}",
        volumeMedium:       "\u{F0580}",
        volumeLow:          "\u{F057F}",
        volumeMute:         "\u{F075F}",
        coffee:             "\u{F0176}",
        apps:               "\u{F003B}",
        palette:            "\u{F03D8}",
        bell:               "\u{F009A}",
        clipboard:          "\u{F0147}",
        emoji:              "\u{F0C7A}",
        cog:                "\u{F0493}",
        power:              "\u{F0425}",
        lock:               "\u{F033E}",
        sleep:              "\u{F04B2}",
        hibernate:          "\u{F0904}",
        logout:             "\u{F0343}",
        restart:            "\u{F0709}",
        wifi:               "\u{F05A9}",
        chevronLeft:        "\u{F0141}",
        chevronRight:       "\u{F0142}",
        check:              "\u{F012C}",
        close:              "\u{F0156}",
        magnify:            "\u{F0349}",
        image:              "\u{F02E9}",
        viewDashboard:      "\u{F056E}",
        tag:                "\u{F04F9}",
        monitor:            "\u{F0379}",
        play:               "\u{F040A}",
        pause:              "\u{F03E4}",
        next:               "\u{F04AD}",
        previous:           "\u{F04AE}",
        account:            "\u{F0004}",
        folder:             "\u{F024B}",
        file:               "\u{F0214}",
        web:                "\u{F059F}",
        calculator:         "\u{F00EC}",
        brightness:         "\u{F00DF}"
    })

    property color base:    "#1e1e2e"
    property color surface: "#181825"
    property color border:  "#313244"
    property color text:    "#cdd6f4"
    property color subtext: "#6c7086"
    property color blue:    "#89b4fa"
    property color green:   "#a6e3a1"
    property color red:     "#f38ba8"
    property color yellow:  "#f9e2af"
    property color teal:    "#94e2d5"
    property color purple:  "#cba6f7"

    // Target colors (not animated) — always reflect the intended final values.
    // Use these when building Kitty/Firefox commands so rapid palette switches
    // don't send intermediate animation values.
    property var _target: ({
        base: "#1e1e2e", surface: "#181825", border: "#313244",
        text: "#cdd6f4", subtext: "#6c7086",
        blue: "#89b4fa", green: "#a6e3a1", red: "#f38ba8",
        yellow: "#f9e2af", teal: "#94e2d5", purple: "#cba6f7"
    })

    Behavior on base    { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on surface { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on border  { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on text    { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on subtext { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on blue    { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on green   { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on red     { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on yellow  { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on teal    { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on purple  { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }

    function applyPalette(n) {
        if (n === "custom") return
        let b, sf, bo, tx, sx, bl, gn, rd, ye, te, pu
        if (n === "macchiato") {
            b="#24273a"; sf="#1e2030"; bo="#363a4f"
            tx="#cad3f5"; sx="#6e738d"
            bl="#8aadf4"; gn="#a6da95"; rd="#ed8796"; ye="#eed49f"; te="#8bd5ca"; pu="#c6a0f6"
        } else if (n === "frappe") {
            b="#303446"; sf="#292c3c"; bo="#414559"
            tx="#c6d0f5"; sx="#737994"
            bl="#8caaee"; gn="#a6d189"; rd="#e78284"; ye="#e5c890"; te="#81c8be"; pu="#ca9ee6"
        } else if (n === "latte") {
            b="#eff1f5"; sf="#e6e9ef"; bo="#ccd0da"
            tx="#4c4f69"; sx="#8c8fa1"
            bl="#1e66f5"; gn="#40a02b"; rd="#d20f39"; ye="#df8e1d"; te="#179299"; pu="#8839ef"
        } else if (n === "tokyo-night") {
            b="#1a1b26"; sf="#16161e"; bo="#292e42"
            tx="#c0caf5"; sx="#565f89"
            bl="#7aa2f7"; gn="#9ece6a"; rd="#f7768e"; ye="#e0af68"; te="#73daca"; pu="#bb9af7"
        } else if (n === "gruvbox") {
            b="#282828"; sf="#1d2021"; bo="#3c3836"
            tx="#ebdbb2"; sx="#928374"
            bl="#83a598"; gn="#b8bb26"; rd="#fb4934"; ye="#fabd2f"; te="#8ec07c"; pu="#d3869b"
        } else if (n === "nord") {
            b="#2e3440"; sf="#3b4252"; bo="#434c5e"
            tx="#eceff4"; sx="#4c566a"
            bl="#81a1c1"; gn="#a3be8c"; rd="#bf616a"; ye="#ebcb8b"; te="#88c0d0"; pu="#b48ead"
        } else if (n === "dracula") {
            b="#282a36"; sf="#21222c"; bo="#44475a"
            tx="#f8f8f2"; sx="#6272a4"
            bl="#6272a4"; gn="#50fa7b"; rd="#ff5555"; ye="#f1fa8c"; te="#8be9fd"; pu="#bd93f9"
        } else if (n === "rosepine") {
            b="#191724"; sf="#1f1d2e"; bo="#26233a"
            tx="#e0def4"; sx="#6e6a86"
            bl="#9ccfd8"; gn="#31748f"; rd="#eb6f92"; ye="#f6c177"; te="#ebbcba"; pu="#c4a7e7"
        } else if (n === "onedark") {
            b="#282c34"; sf="#21252b"; bo="#3e4451"
            tx="#abb2bf"; sx="#5c6370"
            bl="#61afef"; gn="#98c379"; rd="#e06c75"; ye="#e5c07b"; te="#56b6c2"; pu="#c678dd"
        } else if (n === "everforest") {
            b="#2d353b"; sf="#232a2e"; bo="#3d484d"
            tx="#d3c6aa"; sx="#7a8478"
            bl="#7fbbb3"; gn="#a7c080"; rd="#e67e80"; ye="#dbbc7f"; te="#83c092"; pu="#d699b6"
        } else if (n === "solarized") {
            b="#002b36"; sf="#073642"; bo="#586e75"
            tx="#839496"; sx="#657b83"
            bl="#268bd2"; gn="#859900"; rd="#dc322f"; ye="#b58900"; te="#2aa198"; pu="#6c71c4"
        } else if (n === "solarized-light") {
            b="#fdf6e3"; sf="#eee8d5"; bo="#d6d0be"
            tx="#657b83"; sx="#93a1a1"
            bl="#268bd2"; gn="#859900"; rd="#dc322f"; ye="#b58900"; te="#2aa198"; pu="#6c71c4"
        } else if (n === "gruvbox-light") {
            b="#fbf1c7"; sf="#f9f5d7"; bo="#f3eac7"
            tx="#3c3836"; sx="#7c6f64"
            bl="#458588"; gn="#689d6a"; rd="#cc241d"; ye="#d79921"; te="#689d6a"; pu="#b16286"
        } else if (n === "nord-light") {
            b="#eceff4"; sf="#e5e9f0"; bo="#d8dee9"
            tx="#2e3440"; sx="#4c566a"
            bl="#5e81ac"; gn="#a3be8c"; rd="#bf616a"; ye="#ebcb8b"; te="#88c0d0"; pu="#b48ead"
        } else if (n === "rosepine-dawn") {
            b="#faf4ed"; sf="#fffaf3"; bo="#f2ede5"
            tx="#575279"; sx="#9893a5"
            bl="#286983"; gn="#d7827e"; rd="#b4637a"; ye="#ea9d34"; te="#56949f"; pu="#907aa9"
        } else if (n === "onelight") {
            b="#fafafa"; sf="#f3f3f3"; bo="#e8e8e8"
            tx="#383a42"; sx="#a0a1a7"
            bl="#4078f2"; gn="#50a14f"; rd="#e45649"; ye="#c18401"; te="#0184bc"; pu="#a626a4"
        } else {
            // mocha (default)
            b="#1e1e2e"; sf="#181825"; bo="#313244"
            tx="#cdd6f4"; sx="#6c7086"
            bl="#89b4fa"; gn="#a6e3a1"; rd="#f38ba8"; ye="#f9e2af"; te="#94e2d5"; pu="#cba6f7"
        }
        root._target = { base: b, surface: sf, border: bo, text: tx, subtext: sx, blue: bl, green: gn, red: rd, yellow: ye, teal: te, purple: pu }
        base = b; surface = sf; border = bo; text = tx; subtext = sx
        blue = bl; green = gn; red = rd; yellow = ye; teal = te; purple = pu
    }


    Component.onCompleted: {
        applyPalette(name)
        updateKittyTheme()
        updateFirefoxTheme()
        updateSystemColorScheme()
        updateHyprlandBorder()
    }

    onNameChanged: {
        applyPalette(name)
        saveToFile(saveProc, "theme", name)
        updateKittyTheme()
        updateFirefoxTheme()
        updateSystemColorScheme()
        updateHyprlandBorder()
    }

    function saveBarModules() {
        saveToFile(barModulesSaveProc, "bar-modules", JSON.stringify({
            showClock: root.showClock, showBattery: root.showBattery,
            showCpu: root.showCpu, showMemory: root.showMemory,
            showAudio: root.showAudio, showBluetooth: root.showBluetooth,
            showNetwork: root.showNetwork, showTray: root.showTray,
            showWorkspaces: root.showWorkspaces, showMenu: root.showMenu,
            showGpu: root.showGpu, showMusic: root.showMusic,
            showInhibit: root.showInhibit
        }))
    }

    function updateHyprlandBorder() {
        const c = root._target
        function toRgba(hex, alpha) {
            return "rgba(" + hex.slice(1).toLowerCase() + alpha + ")"
        }
        const col = toRgba(c.blue, "99")
        hyprBorderProc.command = ["sh", "-c",
            "hyprctl eval \"hl.config({ general = { col = { active_border = '" + col + "' } } })\""
        ]
        hyprBorderProc.running = false
        hyprBorderProc.running = true
    }

    function updateFirefoxTheme() {
        const c = root._target
        const json = '{"wallpaper":"","colors":{"color0":"' + c.surface +
            '","color1":"' + c.red +
            '","color2":"' + c.green +
            '","color3":"' + c.yellow +
            '","color4":"' + c.blue +
            '","color5":"' + c.purple +
            '","color6":"' + c.teal +
            '","color7":"' + c.text +
            '","color8":"' + c.subtext +
            '","color9":"' + c.red +
            '","color10":"' + c.green +
            '","color11":"' + c.yellow +
            '","color12":"' + c.blue +
            '","color13":"' + c.purple +
            '","color14":"' + c.teal +
            '","color15":"' + c.text + '"}}'
        const escaped = json.replace(/'/g, "'\\''")
        firefoxThemeSaveProc.command = ["sh", "-c",
            "mkdir -p \"$HOME/.cache/wal\" && printf '%s' '" + escaped + "' > \"$HOME/.cache/wal/colors.json\" && " +
            "$HOME/.conda/envs/pywalfox/bin/pywalfox update 2>/dev/null || true"
        ]
        firefoxThemeSaveProc.running = false
        firefoxThemeSaveProc.running = true
    }

    function updateKittyTheme() {
        const c = root._target
        const lines = [
            "foreground " + c.text,
            "background " + c.base,
            "color0 " + c.surface,
            "color1 " + c.red,
            "color2 " + c.green,
            "color3 " + c.yellow,
            "color4 " + c.blue,
            "color5 " + c.purple,
            "color6 " + c.teal,
            "color7 " + c.text,
            "color8 " + c.subtext,
            "color9 " + c.red,
            "color10 " + c.green,
            "color11 " + c.yellow,
            "color12 " + c.blue,
            "color13 " + c.purple,
            "color14 " + c.teal,
            "color15 " + c.text,
            "cursor " + c.blue
        ]
        const themeContent = lines.join('\n')
        const escaped = themeContent.replace(/'/g, "'\\''")
        kittyThemeSaveProc.command = ["sh", "-c",
            "mkdir -p \"$HOME/.config/kitty\" && printf '%s' '" + escaped + "' > $HOME/.config/kitty/color_scheme.conf && " +
            "\"$HOME/.config/quickshell/scripts/update-kitty-colors.sh\" \"$HOME/.config/kitty/color_scheme.conf\" 2>/dev/null || true"
        ]
        kittyThemeSaveProc.running = false
        kittyThemeSaveProc.running = true
    }

    onShowClockChanged: saveBarModules()
    onShowBatteryChanged: saveBarModules()
    onShowCpuChanged: saveBarModules()
    onShowMemoryChanged: saveBarModules()
    onShowAudioChanged: saveBarModules()
    onShowBluetoothChanged: saveBarModules()
    onShowNetworkChanged: saveBarModules()
    onShowTrayChanged: saveBarModules()
    onShowWorkspacesChanged: saveBarModules()
    onShowMenuChanged: saveBarModules()
    onShowGpuChanged: saveBarModules()
    onShowMusicChanged: saveBarModules()
    onShowInhibitChanged: saveBarModules()

    onBarFontSizeChanged: saveToFile(saveBarFontSizeProc, "bar-font-size", barFontSize)

    onVimBindsChanged: saveToFile(saveVimBindsProc, "vim-binds", vimBinds ? "1" : "0")

    // GTK 3/4, libadwaita and Qt/KDE colors are written by a script so the
    // logic stays readable; see scripts/sync-system-colors.py for what updates
    // live. Debounced: palette switches can arrive in quick bursts.
    function updateSystemColorScheme() {
        systemColorTimer.restart()
    }

    Timer {
        id: systemColorTimer
        interval: 150
        onTriggered: {
            const t = root._target
            systemColorSchemeProc.command = ["sh", "-c",
                "exec python3 \"$HOME/.config/quickshell/scripts/sync-system-colors.py\" \"$@\"", "--",
                t.base, t.surface, t.border, t.text, t.subtext,
                t.blue, t.green, t.red, t.yellow, t.teal, t.purple]
            systemColorSchemeProc.running = false
            systemColorSchemeProc.running = true
        }
    }

    function saveToFile(proc, filename, content) {
        const safe = String(content).replace(/'/g, "'\\''")
        proc.command = ["sh", "-c",
            "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + safe + "' > \"$HOME/.config/quickshell/" + filename + "\""]
        proc.running = false
        proc.running = true
    }

    function loadCustomPalette() {
        saveToFile(saveCustomActiveProc, "theme", "custom")
        customPaletteProc.running = false
        customPaletteProc.running = true
    }

    function saveCustomPaletteColors(colors) {
        saveToFile(saveCustomPaletteProc, "custom-palette", colors.join(' '))
        saveToFile(saveCustomActiveProc, "theme", "custom")
    }

    Process { id: hyprBorderProc }
    Process { id: saveProc }
    Process { id: saveCustomPaletteProc }
    Process { id: saveCustomActiveProc }
    Process { id: barModulesSaveProc }
    Process { id: saveBarFontSizeProc }
    Process { id: saveVimBindsProc }
    Process { id: kittyThemeSaveProc }
    Process { id: firefoxThemeSaveProc }
    Process { id: systemColorSchemeProc }

    Process {
        id: customPaletteProc
        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/custom-palette\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(' ')
                if (p.length !== 11) return
                root._target = { base: p[0], surface: p[1], border: p[2], text: p[3], subtext: p[4], blue: p[5], green: p[6], red: p[7], yellow: p[8], teal: p[9], purple: p[10] }
                root.base    = p[0]; root.surface = p[1]; root.border  = p[2]
                root.text    = p[3]; root.subtext = p[4]
                root.blue    = p[5]; root.green   = p[6]; root.red     = p[7]
                root.yellow  = p[8]; root.teal    = p[9]; root.purple  = p[10]
                updateKittyTheme()
                updateFirefoxTheme()
                updateSystemColorScheme()
                updateHyprlandBorder()
            }
        }
    }

    Process {
        id: loadProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/theme 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = this.text.trim()
                if (saved === "custom") loadCustomPalette()
                else if (saved) root.name = saved
            }
        }
    }



    Process {
        id: loadBarFontSizeProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/bar-font-size 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = this.text.trim()
                if (saved) {
                    const val = parseInt(saved, 10)
                    if (!isNaN(val)) root.barFontSize = val
                }
            }
        }
    }

    Process {
        id: loadVimBindsProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/vim-binds 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = this.text.trim()
                if (saved) root.vimBinds = saved === "1"
            }
        }
    }

    function _migratePos(val, def) {
        if (typeof val === "boolean") return val ? def : "disabled"
        return val
    }

    Process {
        id: loadBarModulesProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/bar-modules 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = this.text.trim()
                if (saved) {
                    try {
                        const obj = JSON.parse(saved)
                        if (obj.showMenu !== undefined)       root.showMenu       = root._migratePos(obj.showMenu,       "left")
                        if (obj.showClock !== undefined)      root.showClock      = root._migratePos(obj.showClock,      "left")
                        if (obj.showBattery !== undefined)    root.showBattery    = root._migratePos(obj.showBattery,    "left")
                        if (obj.showCpu !== undefined)        root.showCpu        = root._migratePos(obj.showCpu,        "left")
                        if (obj.showMemory !== undefined)     root.showMemory     = root._migratePos(obj.showMemory,     "left")
                        if (obj.showGpu !== undefined)        root.showGpu        = root._migratePos(obj.showGpu,        "left")
                        if (obj.showWorkspaces !== undefined) root.showWorkspaces = root._migratePos(obj.showWorkspaces, "center")
                        if (obj.showMusic !== undefined)      root.showMusic      = root._migratePos(obj.showMusic,      "right")
                        if (obj.showAudio !== undefined)      root.showAudio      = root._migratePos(obj.showAudio,      "right")
                        if (obj.showBluetooth !== undefined)  root.showBluetooth  = root._migratePos(obj.showBluetooth,  "right")
                        if (obj.showNetwork !== undefined)    root.showNetwork    = root._migratePos(obj.showNetwork,    "right")
                        if (obj.showInhibit !== undefined)    root.showInhibit    = root._migratePos(obj.showInhibit,    "right")
                        if (obj.showTray !== undefined)       root.showTray       = root._migratePos(obj.showTray,       "right")
                    } catch(e) {}
                }
            }
        }
    }
}
