-- Ignore client maximize requests (kitty opens maximized since Hyprland 0.56)
hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })

-- Never allow any app to inhibit idle — screen only wakes from real input
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "none" })
