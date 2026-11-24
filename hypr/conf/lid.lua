-- Laptop lid: while the lid is closed and an external monitor is connected,
-- the internal panel is turned off. Closing or opening the lid reloads the
-- config, which re-runs this check. Loaded after user-settings.lua so it
-- overrides the panel's monitor rule there; that rule comes back on reload.

local function sh(cmd)
	local p = io.popen(cmd)
	if not p then
		return ""
	end
	local out = p:read("a") or ""
	p:close()
	return out
end

local function isInternal(name)
	return name:match("^eDP") or name:match("^LVDS") or name:match("^DSI")
end

if sh("cat /proc/acpi/button/lid/*/state 2>/dev/null"):find("closed") then
	local internal, external = {}, false
	local status = sh('for f in /sys/class/drm/card*-*/status; do echo "$f $(cat "$f")"; done 2>/dev/null')
	for name, state in status:gmatch("card%d+%-([^/]+)/status (%a+)") do
		if state == "connected" then
			if isInternal(name) then
				table.insert(internal, name)
			else
				external = true
			end
		end
	end
	if external then
		for _, name in ipairs(internal) do
			hl.monitor({ output = name, disabled = true })
		end
	end
end

hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("hyprctl reload"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl reload"), { locked = true })
