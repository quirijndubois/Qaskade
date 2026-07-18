hl.window_rule({
	name = "qs-settings",
	match = { class = "org.quickshell", title = "Quickshell Settings" },
	float = true,
	pin = true,
	move = "center center",
	border_size = 0,
})

-- Never allow any app to inhibit idle — screen only wakes from real input
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "none" })
