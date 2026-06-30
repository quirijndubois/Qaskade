local cfg = os.getenv("HOME") .. "/.config/hypr/conf"

dofile(cfg .. "/monitors.lua")
dofile(cfg .. "/autostart.lua")
dofile(cfg .. "/env.lua")
dofile(cfg .. "/appearance.lua")
dofile(cfg .. "/layouts.lua")
dofile(cfg .. "/rules.lua")
dofile(cfg .. "/input.lua")
dofile(cfg .. "/keybindings.lua")

-- User-specific settings (not tracked by git, excluded from install.sh sync)
local _us = os.getenv("HOME") .. "/.config/hypr/user-settings.lua"
local _f = io.open(_us, "r")
if _f then
	_f:close()
	dofile(_us)
end
