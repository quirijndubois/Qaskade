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

	misc = {
		force_default_wallpaper = -1,
		disable_hyprland_logo = true,
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

hl.animation({ leaf = "windows", enabled = true, speed = 2.0, bezier = "mdStandard" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.0, bezier = "mdStandard", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.0, bezier = "mdStandard", style = "slide" })

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
	style = "slidevert",
})
hl.animation({
	leaf = "workspacesIn",
	enabled = true,
	speed = 2.0,
	bezier = "mdStandard",
	style = "slidevert",
})
hl.animation({
	leaf = "workspacesOut",
	enabled = true,
	speed = 2.0,
	bezier = "mdStandard",
	style = "slidevert",
})
