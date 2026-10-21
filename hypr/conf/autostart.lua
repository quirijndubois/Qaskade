-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
	-- Apps started through D-Bus/systemd (Dolphin, portals, …) don't inherit
	-- Hyprland's env; push the theming variables to them as well.
	hl.exec_cmd("dbus-update-activation-environment --systemd QT_QPA_PLATFORMTHEME WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd('kitty -e zsh -c "sleep 1 && hyfetch; exec zsh"')
	-- hl.exec_cmd("waybar")
	hl.exec_cmd("quickshell")
	hl.exec_cmd("solaar --window=hide")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("hyprctl dispatch workspace 1")
end)
