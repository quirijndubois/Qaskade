#!/bin/sh
# Runs (debounced) whenever the set of screens changes.
#  - No active output left (e.g. the external monitor was unplugged while the
#    laptop panel was disabled): drop every persisted `disabled = true` and
#    reload, so the system is never left without a screen.
#  - Lid closed while the internal panel is still on next to another monitor
#    (an external monitor was plugged in with the lid shut): reload, so
#    hypr/conf/lid.lua turns the panel off.

us="$HOME/.config/hypr/user-settings.lua"
mons=$(hyprctl monitors 2>/dev/null | grep '^Monitor ' | grep -v 'FALLBACK')

if [ -z "$mons" ]; then
	[ -f "$us" ] && sed -i 's/, disabled = true//g' "$us"
	exec hyprctl reload
fi

if grep -qs closed /proc/acpi/button/lid/*/state \
	&& [ "$(printf '%s\n' "$mons" | wc -l)" -gt 1 ] \
	&& printf '%s\n' "$mons" | grep -qE '^Monitor (eDP|LVDS|DSI)'; then
	exec hyprctl reload
fi
