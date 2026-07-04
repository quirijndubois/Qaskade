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
