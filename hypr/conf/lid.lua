-- Laptop lid: while the lid is closed and an external monitor is connected,
-- the internal panel is turned off. Closing or opening the lid reloads the
-- config, which re-runs this check. Loaded after user-settings.lua so it
-- overrides the panel's monitor rule there; that rule comes back on reload.
-- It also makes sure at least one connected output stays enabled.

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

local connected, internal, external = {}, {}, false
local status = sh('for f in /sys/class/drm/card*-*/status; do echo "$f $(cat "$f")"; done 2>/dev/null')
for name, state in status:gmatch("card%d+%-([^/]+)/status (%a+)") do
	if state == "connected" then
		table.insert(connected, name)
		if isInternal(name) then
			table.insert(internal, name)
		else
			external = true
		end
	end
end

-- Outputs that end up disabled: those user-settings.lua disables, plus the
-- internal panels this file turns off for a closed lid.
local disabled = {}
local us = io.open(os.getenv("HOME") .. "/.config/hypr/user-settings.lua", "r")
if us then
	for name in us:read("a"):gmatch('output%s*=%s*"([^"]+)"%s*,%s*disabled%s*=%s*true') do
		disabled[name] = true
	end
	us:close()
end

if external and sh("cat /proc/acpi/button/lid/*/state 2>/dev/null"):find("closed") then
	for _, name in ipairs(internal) do
		hl.monitor({ output = name, disabled = true })
		disabled[name] = true
	end
end

-- Never start without a screen: if every connected output would be disabled
-- (e.g. the laptop panel was disabled while docked and the session now starts
-- undocked), turn them all back on. The later rule overrides user-settings.
local anyOn = false
for _, name in ipairs(connected) do
	if not disabled[name] then
		anyOn = true
	end
end
if #connected > 0 and not anyOn then
	for _, name in ipairs(connected) do
		hl.monitor({ output = name, mode = "preferred", position = "auto", scale = 1 })
	end
end

hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("hyprctl reload"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl reload"), { locked = true })
