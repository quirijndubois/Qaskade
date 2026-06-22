---
layout: home
title: Palette Extraction
---

# Palette Extraction

Qaskade can extract a color palette from any wallpaper image and apply it system-wide. Every extraction is slightly different thanks to randomized jitter.

---

## User Guide

### From the Settings Overlay

1. Open **Settings → Appearance → Wallpaper**
2. Navigate to any image
3. Press `A`

The extracted palette applies instantly across the shell, Kitty, Firefox, and system dark/light mode.

### Random Wallpaper with Auto-Extraction

Press `Alt + R` to pick a random wallpaper from `~/wallpapers/`, apply it with an animated transition, and immediately extract and apply its palette.

---

## Internals

**Files:** `quickshell/scripts/extract-palette.py`, `quickshell/scripts/random-wallpaper.sh`

### Extraction Pipeline

`extract-palette.py` takes an image path and prints 11 hex colors to stdout:

```
base surface border text subtext blue green red yellow teal purple
```

The pipeline:

1. **Resize** to 200×200 for speed
2. **Quantize** to 14–20 colors (randomized) using PIL median-cut
3. **Sort** by luminance to separate dark and light colors
4. **Detect** dark vs light theme by median luminance of the palette
5. **Select backgrounds** (3 colors: base, surface, border) from the dark end for dark images
6. **Select foregrounds** (text, subtext) from the light end, enforced to WCAG contrast
7. **Map accents** (red, yellow, green, teal, blue, purple) by finding the best hue match from mid-saturation colors
8. **Enforce contrast** on all accents (≥ 4.5:1 vs base)
9. **Apply jitter** to all accents for variety across runs

### WCAG Enforcement

`push_toward_readable` iteratively adjusts lightness by ±0.04 per step until the contrast ratio meets the target:

```python
def push_toward_readable(color, bg, dark_theme, target_ratio, max_steps=40):
    for _ in range(max_steps):
        if contrast_ratio(color, bg) >= target_ratio:
            break
        h, s, v = to_hsv(*color)
        v += 0.04 if dark_theme else -0.04
        color = from_hsv(h, s, v)
    return color
```

Text targets 7:1 (WCAG AAA), accents target 4.5:1 (WCAG AA).

### Jitter for Variety

Small random HSV perturbations are applied to accent colors so that extracting the same wallpaper twice gives slightly different results:

```python
def jitter(color, rng, hue_range=0.05, sat_range=0.08, val_range=0.06):
    h, s, v = to_hsv(*color)
    h = (h + rng.uniform(-hue_range, hue_range)) % 1.0
    ...
```

The RNG is seeded from system time, so each run is unique.

### Weighted Hue Matching

For each accent role (blue, red, etc.), the best candidate from the image is selected using a score:

```python
score = hue_dist(candidate_hue, target_hue) - saturation * 0.4
```

Saturation is rewarded (subtracted from score) to prefer vivid colors. The top 3 candidates are picked randomly with inverse-score weighting - so the best match isn't always chosen, adding further variety.

### Random Wallpaper Script

`random-wallpaper.sh`:

1. Lists files in `~/wallpapers/`
2. Picks one randomly with `$RANDOM`
3. Picks a random `awww` transition type from: `fade left right top bottom wipe wave grow center any outer`
4. Launches `awww img ... "$wallpaper"` in the background
5. Runs `extract-palette.py "$wallpaper"` using the conda pywalfox Python environment
6. Writes the output to `~/.config/quickshell/custom-palette`
7. Calls `quickshell ipc -c default call theme setCustom` to trigger `Theme.loadCustomPalette()`

### IPC Trigger

`shell.qml` registers an `IpcHandler` for `target: "theme"` with a `setCustom` function that calls `Theme.loadCustomPalette()`. This lets the shell script notify the running Quickshell instance to reload colors without restarting.

---

[← Theme Engine](theme-engine.html) • [Palettes →](themes.html)
