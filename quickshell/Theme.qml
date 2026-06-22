pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string name:          "mocha"
    property string design:           "default"
    property string lockDesign:       "default"
    property int    barHeightPadding: 17
    property int    barHeight:        barFontSize + barHeightPadding
    property int    barFontSize:      13
    property string barFontFamily: "JetBrains Mono"
    property bool   barFontBold:   false
    property string separatorText: "  │  "
    property bool showClock:      true
    property bool showBattery:    true
    property bool showCpu:        true
    property bool showMemory:     true
    property bool showAudio:      true
    property bool showBluetooth:  true
    property bool showNetwork:    true
    property bool showTray:       true
    property bool showWorkspaces: true
    property bool showMenu:       true
    property bool showGpu:        true
    property bool showMusic:      true
    property bool showInhibit:    true
    property int  gapsOut:        10
    property bool vimBinds:     false

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

    function applyDesign(d) {
        if (d === "compact") {
            barHeightPadding = 11
            barFontFamily = "JetBrains Mono"; barFontBold = false
            separatorText = "  │  "
        } else if (d === "islands") {
            barHeightPadding = 17
            barFontFamily = "JetBrains Mono"; barFontBold = false
            separatorText = "  │  "
        } else if (d === "bold") {
            barHeightPadding = 27
            barFontFamily = "JetBrains Mono"; barFontBold = true
            separatorText = "  │  "
        } else if (d === "minimal") {
            barHeightPadding = 5
            barFontFamily = "JetBrains Mono"; barFontBold = false
            separatorText = " · "
        } else if (d === "clean") {
            barHeightPadding = 17
            barFontFamily = "Noto Sans"; barFontBold = false
            separatorText = "  /  "
        } else if (d === "hacker") {
            barHeightPadding = 19
            barFontFamily = "Hack"; barFontBold = false
            separatorText = "  |  "
        } else if (d === "pills") {
            barHeightPadding = 19
            barFontFamily = "JetBrains Mono"; barFontBold = false
            separatorText = "  │  "
        } else {
            // default
            barHeightPadding = 17
            barFontFamily = "JetBrains Mono"; barFontBold = false
            separatorText = "  │  "
        }
    }

    Component.onCompleted: {
        applyPalette(name)
        updateKittyTheme()
        updateFirefoxTheme()
        updateSystemColorScheme()
    }

    onNameChanged: {
        applyPalette(name)
        saveToFile(saveProc, "theme", name)
        updateKittyTheme()
        updateFirefoxTheme()
        updateSystemColorScheme()
    }

    onDesignChanged: {
        applyDesign(design)
        saveToFile(saveDesignProc, "design", design)
    }

    onLockDesignChanged: saveToFile(saveLockDesignProc, "lock-design", lockDesign)

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

    function updateSystemColorScheme() {
        const t = root._target
        const bx = t.base
        const br = parseInt(bx.slice(1, 3), 16)
        const bg = parseInt(bx.slice(3, 5), 16)
        const bb = parseInt(bx.slice(5, 7), 16)
        const dark     = (0.299 * br + 0.587 * bg + 0.114 * bb) < 128
        const pref     = dark ? "prefer-dark" : "prefer-light"
        const gtkTheme = dark ? "Adwaita-dark" : "Adwaita"
        const gtkDark  = dark ? "1" : "0"

        // Convert #rrggbb → #ffrrggbb for qt6ct palette format
        function qc(hex) { return '#ff' + hex.slice(1).toLowerCase() }
        // Adjust lightness of a #rrggbb hex by amt (clamped)
        function qa(hex, amt) {
            const pr = Math.min(255, Math.max(0, parseInt(hex.slice(1, 3), 16) + amt))
            const pg = Math.min(255, Math.max(0, parseInt(hex.slice(3, 5), 16) + amt))
            const pb = Math.min(255, Math.max(0, parseInt(hex.slice(5, 7), 16) + amt))
            return '#ff' + pr.toString(16).padStart(2, '0') + pg.toString(16).padStart(2, '0') + pb.toString(16).padStart(2, '0')
        }

        const highlightText = dark ? qc(t.base)   : '#ffffffff'
        const brightText    = dark ? '#ffffffff'   : '#ff000000'
        const altBase       = qa(t.base, dark ? 10 : -10)

        // Qt QPalette roles 0-20: WindowText, Button, Light, Midlight, Dark, Mid,
        // Text, BrightText, ButtonText, Base, Window, Shadow, Highlight,
        // HighlightedText, Link, LinkVisited, AlternateBase, NoRole,
        // ToolTipBase, ToolTipText, PlaceholderText
        const active = [
            qc(t.text),       qc(t.border),     qa(t.border, 20), qa(t.border, 10),
            qc(t.surface),    qc(t.border),      qc(t.text),        brightText,
            qc(t.text),       qc(t.base),        qc(t.surface),     qc(t.base),
            qc(t.blue),       highlightText,     qc(t.blue),        qc(t.purple),
            altBase,          '#00000000',        qc(t.border),      qc(t.text),       qc(t.subtext)
        ].join(', ')

        const disabled = [
            qc(t.subtext),    qc(t.border),     qa(t.border, 20), qa(t.border, 10),
            qc(t.surface),    qc(t.border),      qc(t.subtext),     '#ff888888',
            qc(t.subtext),    qc(t.base),        qc(t.surface),     qc(t.base),
            qc(t.border),     highlightText,     qc(t.subtext),     qc(t.subtext),
            altBase,          '#00000000',        qc(t.border),      qc(t.subtext),    qc(t.subtext)
        ].join(', ')

        const qt6ctScheme = "[ColorScheme]\nactive_colors=" + active + "\ndisabled_colors=" + disabled + "\ninactive_colors=" + active
        const escapedScheme = qt6ctScheme.replace(/'/g, "'\\''")

        systemColorSchemeProc.command = ["sh", "-c",
            // GTK3 — write settings.ini directly (no dconf required)
            "mkdir -p \"$HOME/.config/gtk-3.0\" && " +
            "printf '[Settings]\\ngtk-application-prefer-dark-theme=" + gtkDark + "\\ngtk-theme-name=" + gtkTheme + "\\n' > \"$HOME/.config/gtk-3.0/settings.ini\" && " +
            // GTK4
            "mkdir -p \"$HOME/.config/gtk-4.0\" && " +
            "printf '[Settings]\\ngtk-application-prefer-dark-theme=" + gtkDark + "\\n' > \"$HOME/.config/gtk-4.0/settings.ini\" && " +
            // gsettings (best-effort, gives live updates to running GTK4 apps)
            "gsettings set org.gnome.desktop.interface color-scheme '" + pref + "' 2>/dev/null; " +
            "gsettings set org.gnome.desktop.interface gtk-theme '" + gtkTheme + "' 2>/dev/null; " +
            // qt6ct — write a palette file and point qt6ct.conf at it
            "mkdir -p \"$HOME/.config/qt6ct/colors\" && " +
            "printf '%s' '" + escapedScheme + "' > \"$HOME/.config/qt6ct/colors/qaskade.conf\" && " +
            "kwriteconfig6 --file qt6ct.conf --group Appearance --key custom_palette true && " +
            "kwriteconfig6 --file qt6ct.conf --group Appearance --key color_scheme_path \"$HOME/.config/qt6ct/colors/qaskade.conf\" 2>/dev/null; " +
            "true"
        ]
        systemColorSchemeProc.running = false
        systemColorSchemeProc.running = true
    }

    function saveToFile(proc, filename, content) {
        const safe = String(content).replace(/'/g, "'\\''")
        proc.command = ["sh", "-c",
            "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + safe + "' > \"$HOME/.config/quickshell/" + filename + "\""]
        proc.running = false
        proc.running = true
    }

    function loadCustomPalette() {
        customPaletteProc.running = false
        customPaletteProc.running = true
    }

    Process { id: saveProc }
    Process { id: saveDesignProc }
    Process { id: saveLockDesignProc }
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
                if (saved) root.name = saved
            }
        }
    }

    Process {
        id: loadDesignProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/design 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = this.text.trim()
                if (saved) root.design = saved
            }
        }
    }

    Process {
        id: loadLockDesignProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/lock-design 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = this.text.trim()
                if (saved) root.lockDesign = saved
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
                        if (obj.showClock !== undefined) root.showClock = obj.showClock
                        if (obj.showBattery !== undefined) root.showBattery = obj.showBattery
                        if (obj.showCpu !== undefined) root.showCpu = obj.showCpu
                        if (obj.showMemory !== undefined) root.showMemory = obj.showMemory
                        if (obj.showAudio !== undefined) root.showAudio = obj.showAudio
                        if (obj.showBluetooth !== undefined) root.showBluetooth = obj.showBluetooth
                        if (obj.showNetwork !== undefined) root.showNetwork = obj.showNetwork
                        if (obj.showTray !== undefined) root.showTray = obj.showTray
                        if (obj.showWorkspaces !== undefined) root.showWorkspaces = obj.showWorkspaces
                        if (obj.showMenu !== undefined) root.showMenu = obj.showMenu
                        if (obj.showGpu !== undefined) root.showGpu = obj.showGpu
                        if (obj.showMusic !== undefined) root.showMusic = obj.showMusic
                        if (obj.showInhibit !== undefined) root.showInhibit = obj.showInhibit
                    } catch(e) {}
                }
            }
        }
    }
}
