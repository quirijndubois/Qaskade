#!/usr/bin/env python3
"""Push the shell palette to GTK 3, GTK 4 / libadwaita and Qt / KDE apps.

Usage: sync-system-colors.py BASE SURFACE BORDER TEXT SUBTEXT BLUE GREEN RED YELLOW TEAL PURPLE

What updates live, in running apps:
  * GTK 3     - full palette. Colors live in a generated theme; we alternate
                between two identical theme names (Qaskade-A / Qaskade-B) so
                every change is a theme switch, which GTK 3 reloads instantly.
  * GTK 4     - light/dark and accent color (via gsettings). libadwaita only
                reads custom colors at startup, so the full palette applies to
                GTK 4 apps launched afterwards.
  * Qt / KDE  - full palette, through the KDE platform theme
                (QT_QPA_PLATFORMTHEME=kde) and a KGlobalSettings notification.
  * Portals   - color-scheme, so Electron/Chromium/Firefox follow light/dark.
"""

import colorsys
import os
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local" / "share")


# ── Color helpers ──────────────────────────────────────────────────────────

def rgb(hex_):
    hex_ = hex_.lstrip("#")
    return tuple(int(hex_[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in c)


def mix(a, b, t):
    """Blend hex a toward hex b by t (0–1)."""
    ca, cb = rgb(a), rgb(b)
    return to_hex(tuple(x + (y - x) * t for x, y in zip(ca, cb)))


def luminance(hex_):
    r, g, b = rgb(hex_)
    return 0.299 * r + 0.587 * g + 0.114 * b


def kde(hex_):
    return ",".join(str(v) for v in rgb(hex_))


# libadwaita's named accents (org.gnome.desktop.interface accent-color).
ADW_ACCENTS = {
    "blue": "#3584e4", "teal": "#2190a4", "green": "#3a944a",
    "yellow": "#c88800", "orange": "#ed5b00", "red": "#e62d42",
    "pink": "#d56199", "purple": "#9141ac", "slate": "#6f8396",
}


def nearest_accent(hex_):
    h, s, _ = colorsys.rgb_to_hsv(*(v / 255 for v in rgb(hex_)))
    if s < 0.2:
        return "slate"
    best, best_d = "blue", 9.0
    for name, ref in ADW_ACCENTS.items():
        if name == "slate":
            continue
        rh = colorsys.rgb_to_hsv(*(v / 255 for v in rgb(ref)))[0]
        d = min(abs(h - rh), 1 - abs(h - rh))
        if d < best_d:
            best, best_d = name, d
    return best


# ── Writers ────────────────────────────────────────────────────────────────

def write(path, content):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    # Replace symlinks (e.g. left behind by theme installers) with real files.
    if path.is_symlink():
        path.unlink()
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(content)
    tmp.replace(path)


def run(*cmd):
    if shutil.which(cmd[0]):
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def named_colors(p, dark):
    """libadwaita / adw-gtk3 named colors."""
    on_accent = p["base"] if dark else "#ffffff"
    shade = "rgba(0, 0, 0, 0.36)" if dark else "rgba(0, 0, 0, 0.07)"
    card = mix(p["base"], p["text"], 0.05)
    raised = mix(p["base"], p["text"], 0.08)
    return {
        "accent_color": p["blue"], "accent_bg_color": p["blue"], "accent_fg_color": on_accent,
        "destructive_color": p["red"], "destructive_bg_color": p["red"], "destructive_fg_color": on_accent,
        "success_color": p["green"], "success_bg_color": p["green"], "success_fg_color": on_accent,
        "warning_color": p["yellow"], "warning_bg_color": p["yellow"], "warning_fg_color": on_accent,
        "error_color": p["red"], "error_bg_color": p["red"], "error_fg_color": on_accent,
        "window_bg_color": p["base"], "window_fg_color": p["text"],
        "view_bg_color": p["base"], "view_fg_color": p["text"],
        "headerbar_bg_color": p["base"], "headerbar_fg_color": p["text"],
        "headerbar_border_color": p["text"], "headerbar_backdrop_color": p["base"],
        "headerbar_shade_color": shade, "headerbar_darker_shade_color": shade,
        "sidebar_bg_color": p["surface"], "sidebar_fg_color": p["text"],
        "sidebar_backdrop_color": p["surface"], "sidebar_shade_color": shade,
        "secondary_sidebar_bg_color": p["surface"], "secondary_sidebar_fg_color": p["text"],
        "secondary_sidebar_backdrop_color": p["surface"], "secondary_sidebar_shade_color": shade,
        "card_bg_color": card, "card_fg_color": p["text"], "card_shade_color": shade,
        "thumbnail_bg_color": card, "thumbnail_fg_color": p["text"],
        "dialog_bg_color": raised, "dialog_fg_color": p["text"],
        "popover_bg_color": raised, "popover_fg_color": p["text"], "popover_shade_color": shade,
        "shade_color": shade, "scrollbar_outline_color": shade,
    }


def css_block(colors, legacy=False, variables=False):
    lines = [f"@define-color {k} {v};" for k, v in colors.items()]
    if legacy:
        # Older GTK 3 themes read these names instead.
        lines += [
            f"@define-color theme_bg_color {colors['window_bg_color']};",
            f"@define-color theme_fg_color {colors['window_fg_color']};",
            f"@define-color theme_base_color {colors['view_bg_color']};",
            f"@define-color theme_text_color {colors['view_fg_color']};",
            f"@define-color theme_selected_bg_color {colors['accent_bg_color']};",
            f"@define-color theme_selected_fg_color {colors['accent_fg_color']};",
            f"@define-color borders {colors['headerbar_shade_color']};",
        ]
    if variables:
        # libadwaita ≥ 1.6 reads CSS custom properties.
        lines.append(":root {")
        lines += [f"  --{k.replace('_', '-')}: {v};" for k, v in colors.items()]
        lines.append("}")
    return "\n".join(lines) + "\n"


def sync_gtk(p, dark):
    colors = named_colors(p, dark)
    header = "/* Generated by Qaskade (scripts/sync-system-colors.py). Changes are overwritten. */\n"

    # Base themes to build on: adw-gtk3 if installed, else GTK's built-in Adwaita.
    variant = "adw-gtk3-dark" if dark else "adw-gtk3"
    gtk3_base = Path("/usr/share/themes") / variant / "gtk-3.0" / "gtk.css"
    gtk4_base = Path("/usr/share/themes") / variant / "gtk-4.0" / "gtk.css"
    gtk3_import = (f'@import url("file://{gtk3_base}");\n' if gtk3_base.exists()
                   else f'@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained{"-dark" if dark else ""}.css");\n')
    gtk4_import = f'@import url("file://{gtk4_base}");\n' if gtk4_base.exists() else ""

    # Alternate between two theme names so each sync is a theme change.
    current = ""
    if shutil.which("gsettings"):
        current = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"],
                                 capture_output=True, text=True).stdout.strip().strip("'")
    slot = "Qaskade-B" if current == "Qaskade-A" else "Qaskade-A"

    theme = DATA / "themes" / slot
    write(theme / "index.theme",
          f"[Desktop Entry]\nType=X-GNOME-Metatheme\nName={slot}\nComment=Generated by Qaskade\n\n"
          f"[X-GNOME-Metatheme]\nGtkTheme={slot}\n")
    write(theme / "gtk-3.0" / "gtk.css", header + gtk3_import + css_block(colors, legacy=True))
    write(theme / "gtk-4.0" / "gtk.css", header + gtk4_import + css_block(colors))

    # User stylesheets. GTK 3 must not define colors here: this file outranks
    # the theme and is only read at startup, so it would pin stale colors.
    write(CONFIG / "gtk-3.0" / "gtk.css", header)
    # libadwaita ignores themes; this file is its only source of custom colors.
    gtk4_user = header + css_block(colors, variables=True)
    write(CONFIG / "gtk-4.0" / "gtk.css", gtk4_user)
    write(CONFIG / "gtk-4.0" / "gtk-dark.css", gtk4_user)

    dark_flag = "1" if dark else "0"
    write(CONFIG / "gtk-3.0" / "settings.ini",
          f"[Settings]\ngtk-theme-name={slot}\ngtk-application-prefer-dark-theme={dark_flag}\n")
    # libadwaita takes light/dark from the color-scheme setting and warns if
    # gtk-application-prefer-dark-theme is set, so leave it out for GTK 4.
    write(CONFIG / "gtk-4.0" / "settings.ini", "[Settings]\n")

    # Live updates. Theme switch last, once every file is in place.
    run("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark" if dark else "prefer-light")
    run("gsettings", "set", "org.gnome.desktop.interface", "accent-color", nearest_accent(p["blue"]))
    run("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", slot)

    # XWayland GTK apps read XSETTINGS.
    xs = CONFIG / "xsettingsd" / "xsettingsd.conf"
    if xs.exists():
        lines = [l for l in xs.read_text().splitlines() if not l.startswith("Net/ThemeName")]
        lines.append(f'Net/ThemeName "{slot}"')
        write(xs, "\n".join(lines) + "\n")
        run("pkill", "-HUP", "-x", "xsettingsd")


def sync_qt(p, dark):
    on_accent = p["base"] if dark else "#ffffff"
    alt = mix(p["base"], p["text"], 0.04)
    button = mix(p["base"], p["text"], 0.08)

    def group(bg, alt_bg, fg_active=None):
        return {
            "BackgroundAlternate": kde(alt_bg), "BackgroundNormal": kde(bg),
            "DecorationFocus": kde(p["blue"]), "DecorationHover": kde(p["blue"]),
            "ForegroundActive": kde(fg_active or p["blue"]), "ForegroundInactive": kde(p["subtext"]),
            "ForegroundLink": kde(p["blue"]), "ForegroundNegative": kde(p["red"]),
            "ForegroundNeutral": kde(p["yellow"]), "ForegroundNormal": kde(p["text"]),
            "ForegroundPositive": kde(p["green"]), "ForegroundVisited": kde(p["purple"]),
        }

    selection = group(p["blue"], p["blue"], on_accent)
    selection.update({k: kde(on_accent) for k in ("ForegroundNormal", "ForegroundInactive", "ForegroundLink", "ForegroundVisited")})

    sections = {
        "Colors:Window": group(p["base"], p["surface"]),
        "Colors:View": group(p["base"], alt),
        "Colors:Button": group(button, mix(button, p["text"], 0.04)),
        "Colors:Header": group(p["base"], p["surface"]),
        "Colors:Complementary": group(p["surface"], p["base"]),
        "Colors:Tooltip": group(p["surface"], p["surface"]),
        "Colors:Selection": selection,
        "WM": {
            "activeBackground": kde(p["base"]), "activeBlend": kde(p["text"]),
            "activeForeground": kde(p["text"]), "inactiveBackground": kde(p["base"]),
            "inactiveBlend": kde(p["subtext"]), "inactiveForeground": kde(p["subtext"]),
        },
        "General": {"ColorScheme": "Qaskade", "Name": "Qaskade"},
    }

    scheme = "".join(f"[{name}]\n" + "".join(f"{k}={v}\n" for k, v in keys.items()) + "\n"
                     for name, keys in sections.items())
    write(DATA / "color-schemes" / "Qaskade.colors", scheme)

    # Write the palette straight into kdeglobals, which the KDE platform theme reads.
    if shutil.which("kwriteconfig6"):
        for name, keys in sections.items():
            for k, v in keys.items():
                subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", name, "--key", k, v],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # Breeze draws everything from the palette, so it follows color changes.
        run("kwriteconfig6", "--file", "kdeglobals", "--group", "KDE", "--key", "widgetStyle", "Breeze")
        # Keep an icon theme if one is set; otherwise prefer Papirus.
        icons = subprocess.run(["kreadconfig6", "--file", "kdeglobals", "--group", "Icons", "--key", "Theme"],
                               capture_output=True, text=True).stdout.strip() if shutil.which("kreadconfig6") else ""
        if not icons:
            icons = "Papirus" if Path("/usr/share/icons/Papirus").exists() else "breeze"
            run("kwriteconfig6", "--file", "kdeglobals", "--group", "Icons", "--key", "Theme", icons)

    sync_qt6ct(p, dark)

    # Tell running KDE/Qt apps that the palette changed (KGlobalSettings::PaletteChanged).
    run("dbus-send", "--session", "--type=signal", "/KGlobalSettings",
        "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0")


def sync_qt6ct(p, dark):
    """Fallback for apps still started with QT_QPA_PLATFORMTHEME=qt6ct.

    qt6ct only reads its palette at startup, but keeping it in sync means such
    apps at least open with the right colors and the same Breeze style.
    """
    conf = CONFIG / "qt6ct" / "qt6ct.conf"
    if not conf.exists():
        return

    def q(hex_):
        return "#ff" + hex_.lstrip("#").lower()

    on_accent = p["base"] if dark else "#ffffff"
    button = mix(p["base"], p["text"], 0.08)
    # QPalette roles: WindowText, Button, Light, Midlight, Dark, Mid, Text,
    # BrightText, ButtonText, Base, Window, Shadow, Highlight, HighlightedText,
    # Link, LinkVisited, AlternateBase, NoRole, ToolTipBase, ToolTipText, PlaceholderText
    def roles(fg, dim):
        return ", ".join([
            q(fg), q(button), q(mix(button, p["text"], 0.15)), q(mix(button, p["text"], 0.08)),
            q(p["surface"]), q(p["border"]), q(fg), "#ffffffff" if dark else "#ff000000",
            q(fg), q(p["base"]), q(p["base"]), "#ff000000",
            q(p["blue"]), q(on_accent), q(p["blue"]), q(p["purple"]),
            q(mix(p["base"], p["text"], 0.04)), "#00000000", q(p["surface"]), q(fg), q(dim),
        ])

    active = roles(p["text"], p["subtext"])
    disabled = roles(p["subtext"], p["subtext"])
    scheme = CONFIG / "qt6ct" / "colors" / "qaskade.conf"
    write(scheme, f"[ColorScheme]\nactive_colors={active}\ndisabled_colors={disabled}\ninactive_colors={active}\n")

    for key, value in (("custom_palette", "true"), ("color_scheme_path", str(scheme)), ("style", "Breeze")):
        run("kwriteconfig6", "--file", str(conf), "--group", "Appearance", "--key", key, value)


def main():
    keys = ["base", "surface", "border", "text", "subtext", "blue", "green", "red", "yellow", "teal", "purple"]
    if len(sys.argv) != len(keys) + 1:
        sys.exit(__doc__)
    p = dict(zip(keys, sys.argv[1:]))
    dark = luminance(p["base"]) < 128
    sync_gtk(p, dark)
    sync_qt(p, dark)


if __name__ == "__main__":
    main()
