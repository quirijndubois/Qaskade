-- Hyprland configuration
-- See https://wiki.hypr.land/Configuring/Start/

--------------------
---- MONITORS ----
--------------------

-- System-specific monitor setup
hl.monitor({ output = "DP-2", mode = "1920x1080", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1080", position = "1920x0", scale = 1 })

hl.workspace_rule({ workspace = "1", monitor = "DP-2", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-2" })
hl.workspace_rule({ workspace = "3", monitor = "DP-2" })
hl.workspace_rule({ workspace = "4", monitor = "DP-2" })
hl.workspace_rule({ workspace = "5", monitor = "DP-2" })
hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-1", default = true })
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "9", monitor = "HDMI-A-1" })

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
local fileManager = "kitty -e yazi"
local browser = "firefox"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
	hl.exec_cmd('kitty -e zsh -c "sleep 1 && hyfetch; exec zsh"')
	-- hl.exec_cmd("waybar")
	hl.exec_cmd("quickshell")
	hl.exec_cmd("solaar --window=hide")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("hyprctl dispatch workspace 1")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 10,

		border_size = 1,

		col = {
			active_border = { colors = { "rgba(888888cc)", "rgba(aaaaaa88)" }, angle = 45 },
			inactive_border = "rgba(33333300)",
		},

		resize_on_border = false,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,

		active_opacity = 1.0,
		inactive_opacity = 1.0,

		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = "rgba(1a1a1aee)",
		},

		blur = {
			enabled = true,
			size = 5,
			passes = 3,
			vibrancy = 0,
		},
	},

	animations = {
		enabled = true,
	},
})

-- Material Design 3 motion curves (material.io/design/motion)
-- Emphasized: expressive entrance/exit for containers and prominent elements
-- Standard:   functional transitions for less prominent UI changes
hl.curve("mdEmphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1.0 } } }) -- cubic-bezier(0.05, 0.70, 0.10, 1.00)
hl.curve("mdEmphasizedAccel", { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.15 } } }) -- cubic-bezier(0.30, 0.00, 0.80, 0.15)
hl.curve("mdStandard", { type = "bezier", points = { { 0.2, 0.0 }, { 0.0, 1.0 } } }) -- cubic-bezier(0.20, 0.00, 0.00, 1.00)
hl.curve("mdStandardDecel", { type = "bezier", points = { { 0.0, 0.0 }, { 0.0, 1.0 } } }) -- cubic-bezier(0.00, 0.00, 0.00, 1.00)
hl.curve("mdStandardAccel", { type = "bezier", points = { { 0.3, 0.0 }, { 1.0, 1.0 } } }) -- cubic-bezier(0.30, 0.00, 1.00, 1.00)

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 4.0, bezier = "mdStandard" })

hl.animation({ leaf = "windows", enabled = true, speed = 4.0, bezier = "mdEmphasizedDecel" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.5, bezier = "mdEmphasizedDecel", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.0, bezier = "mdEmphasizedAccel", style = "slide" })

hl.animation({ leaf = "fadeIn", enabled = true, speed = 3.0, bezier = "mdStandardDecel" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.5, bezier = "mdStandardAccel" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.5, bezier = "mdStandard" })

hl.animation({ leaf = "layers", enabled = true, speed = 4.0, bezier = "mdEmphasizedDecel" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4.0, bezier = "mdEmphasizedDecel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.5, bezier = "mdEmphasizedAccel", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 3.0, bezier = "mdStandardDecel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.5, bezier = "mdStandardAccel" })

hl.animation({
	leaf = "workspaces",
	enabled = true,
	speed = 2.0,
	bezier = "mdStandard",
	style = "slidefade",
})
hl.animation({
	leaf = "workspacesIn",
	enabled = true,
	speed = 2.0,
	bezier = "mdStandard",
	style = "slidefade",
})
hl.animation({
	leaf = "workspacesOut",
	enabled = true,
	speed = 2.0,
	bezier = "mdStandard",
	style = "slidefade",
})

-------------------
---- LAYOUTS ----
-------------------

hl.config({
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "master",
	},
})

--------------------
---- WINDOW RULES --
--------------------

hl.window_rule({
	name = "qs-settings",
	match = { class = "org.quickshell", title = "Quickshell Settings" },
	float = true,
	pin = true,
	move = "center center",
	border_size = 0,
})

----------------
----  MISC  ----
----------------

hl.config({
	misc = {
		force_default_wallpaper = -1,
		disable_hyprland_logo = true,
	},
})

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		follow_mouse = 1,
		sensitivity = 0.4,

		touchpad = {
			natural_scroll = true,
			scroll_factor = 0.4,
		},
	},

	binds = {
		allow_workspace_cycles = true,
	},

	xwayland = {
		force_zero_scaling = true,
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "ALT"

hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + W", hl.dsp.window.close())

hl.bind(
	mainMod .. " + M",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)

hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("quickshell ipc -c default call settings openApps"))
-- hl.bind(mainMod .. " + I",        hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + Delete", hl.dsp.exec_cmd("quickshell ipc -c default call lock lock"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("quickshell ipc -c default call settings toggle"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("quickshell ipc -c default call statusbar toggle"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd('sh "$HOME/.config/quickshell/scripts/random-wallpaper.sh"'))

-- Move focus with arrow keys and vim keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Move windows with arrow keys and vim keys
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

-- Resize windows
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -50, y = 0, relative = true }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 50, y = 0, relative = true }))
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -50, relative = true }))
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 50, relative = true }))
hl.bind(mainMod .. " + I", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }))
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }))
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }))

-- Switch workspaces and move windows to workspaces
for i = 1, 9 do
	hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + 0", function()
	hl.config({ cursor = { zoom_factor = 1.0 } })
end)
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Move/resize windows with mouse dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + CTRL + mouse:272", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys for volume and brightness
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd(
		"brightnessctl s 10%+ && "
			.. "v=$(brightnessctl g) && m=$(brightnessctl max) && "
			.. "quickshell ipc -c default call osd brightness $((v * 100 / m))"
	),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd(
		"brightnessctl s 10%- && "
			.. "v=$(brightnessctl g) && m=$(brightnessctl max) && "
			.. "quickshell ipc -c default call osd brightness $((v * 100 / m))"
	),
	{ locked = true, repeating = true }
)

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Cursor zoom controls
local ZOOM_STEP = 0.25
local MAX_ZOOM = 3.0
local MIN_ZOOM = 1.0

local function zoom(offset)
	local current = hl.get_config("cursor.zoom_factor") or 1.0
	current = math.max(MIN_ZOOM, math.min(MAX_ZOOM, current + offset))
	hl.config({ cursor = { zoom_factor = current } })
end

hl.bind(mainMod .. " + equal", function()
	zoom(ZOOM_STEP)
end, { repeating = true })
hl.bind(mainMod .. " + minus", function()
	zoom(-ZOOM_STEP)
end, { repeating = true })
hl.bind(mainMod .. " + SHIFT + mouse_up", function()
	zoom(0)
end)

-- User-specific settings (not tracked by git, excluded from install.sh sync)
local _us = os.getenv("HOME") .. "/.config/hypr/user-settings.lua"
local _f = io.open(_us, "r")
if _f then
	_f:close()
	dofile(_us)
end
