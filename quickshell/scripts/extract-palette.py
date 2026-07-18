#!/usr/bin/env python3
"""Extract a color palette from an image for Qaskade theming.
Outputs 11 hex colors on one line: base surface border text subtext blue green red yellow teal purple
"""

import sys
import random
import colorsys
from PIL import Image


def luminance(r, g, b):
    return 0.299 * r + 0.587 * g + 0.114 * b

def rel_luminance(r, g, b):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)

def contrast_ratio(c1, c2):
    l1 = rel_luminance(*c1) + 0.05
    l2 = rel_luminance(*c2) + 0.05
    return max(l1, l2) / min(l1, l2)

def to_hsv(r, g, b):
    return colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)

def from_hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0.0, min(1.0, s)), max(0.0, min(1.0, v)))
    return (int(r * 255), int(g * 255), int(b * 255))

def to_hex(r, g, b):
    return '#%02x%02x%02x' % (int(r), int(g), int(b))

def hue_dist(a, b):
    d = abs(a - b)
    return min(d, 1.0 - d)

def blend(c1, c2, t=0.5):
    return tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3))

def derive(color, dv=0.04, ds=-0.03):
    """Derive a slightly lighter/different shade of a color."""
    h, s, v = to_hsv(*color)
    return from_hsv(h, s + ds, v + dv)

def push_toward_readable(color, bg, dark_theme, target_ratio, max_steps=40):
    """Iteratively lighten or darken `color` until it meets contrast target vs bg."""
    r, g, b = color
    for _ in range(max_steps):
        if contrast_ratio((r, g, b), bg) >= target_ratio:
            break
        h, s, v = to_hsv(r, g, b)
        v += 0.04 if dark_theme else -0.04
        r, g, b = from_hsv(h, s, v)
    return (r, g, b)

def jitter(color, rng, hue_range=0.05, sat_range=0.08, val_range=0.06):
    """Apply small random HSV jitter for variety across runs."""
    h, s, v = to_hsv(*color)
    h = (h + rng.uniform(-hue_range, hue_range)) % 1.0
    s = max(0.0, min(1.0, s + rng.uniform(-sat_range, sat_range)))
    v = max(0.0, min(1.0, v + rng.uniform(-val_range, val_range)))
    return from_hsv(h, s, v)

def weighted_choice(candidates, rng):
    """Pick randomly from candidates weighted inversely by score (lower = better)."""
    weights = [1.0 / (s + 0.01) for s, _, _ in candidates]
    total = sum(weights)
    r = rng.random() * total
    for w, _, c in zip(weights, range(len(candidates)), [x[2] for x in candidates]):
        r -= w
        if r <= 0:
            return c
    return candidates[-1][2]


rng = random.Random()  # seeded from system time — different every run

img = Image.open(sys.argv[1]).convert('RGB')
img = img.resize((200, 200), Image.LANCZOS)

# Randomize quantization count slightly so different runs yield different clusters
n_colors = rng.randint(14, 20)
q = img.quantize(colors=n_colors, method=Image.Quantize.MEDIANCUT, dither=0)
raw = q.getpalette()[:n_colors * 3]
colors = [(raw[i], raw[i+1], raw[i+2]) for i in range(0, len(raw), 3)]
colors.sort(key=lambda c: luminance(*c))

# Detect dark vs light image by median luminance
dark_theme = luminance(*colors[len(colors) // 2]) < 128

if dark_theme:
    bg_pool       = colors[:max(5, len(colors) // 3 + 2)]
    fg_candidates = list(reversed(colors[len(colors) * 2 // 3:]))
else:
    # Light image → always produce a dark palette.
    # Derive dark backgrounds by crushing the value of the image's dominant hue,
    # then flip dark_theme so all subsequent logic (text contrast, accent brightness)
    # runs in dark mode.
    dark_theme = True
    sorted_by_sat = sorted(colors, key=lambda c: to_hsv(*c)[1], reverse=True)
    h0, s0, _ = to_hsv(*sorted_by_sat[0]) if sorted_by_sat else (0.63, 0.3, 0.5)
    bg_pool = [
        from_hsv(h0, min(s0 * 0.50, 0.25), 0.12),
        from_hsv(h0, min(s0 * 0.40, 0.20), 0.17),
        from_hsv(h0, min(s0 * 0.35, 0.17), 0.23),
        from_hsv(h0, min(s0 * 0.45, 0.22), 0.09),
        from_hsv(h0, min(s0 * 0.30, 0.15), 0.20),
    ]
    # Near-white text with a subtle tint toward the image's dominant hue
    fg_candidates = [
        from_hsv(h0, 0.05, 0.90),
        from_hsv(h0, 0.08, 0.60),
    ]

# ── Backgrounds — randomly pick 3 from the pool, heavier weight toward extremes ──
pool_size = len(bg_pool)
weights   = [1.0 / (i + 1) for i in range(pool_size)]
chosen    = []
remaining = list(range(pool_size))
for _ in range(min(3, pool_size)):
    total  = sum(weights[i] for i in remaining)
    r      = rng.random() * total
    cumul  = 0.0
    picked = remaining[-1]
    for i in remaining:
        cumul += weights[i]
        if r <= cumul:
            picked = i
            break
    chosen.append(bg_pool[picked])
    remaining.remove(picked)

while len(chosen) < 3:
    chosen.append(derive(chosen[-1], dv=0.04))

# Sort so base is always darkest, border always least dark
chosen.sort(key=lambda c: luminance(*c), reverse=not dark_theme)
base, surface, border = chosen

# ── Foregrounds — enforce WCAG AA contrast ─────────────────────────────────────
raw_text    = fg_candidates[0] if fg_candidates else (from_hsv(0, 0, 0.9) if dark_theme else from_hsv(0, 0, 0.1))
raw_subtext = fg_candidates[1] if len(fg_candidates) > 1 else blend(raw_text, base, 0.45)

text    = push_toward_readable(raw_text,    base, dark_theme, target_ratio=7.0)
subtext = push_toward_readable(raw_subtext, base, dark_theme, target_ratio=4.5)

# ── Accent colors — hue-targeted with randomness ───────────────────────────────
bg_set = set(id(c) for c in chosen)
fg_set = set(id(c) for c in [raw_text, raw_subtext])
mid = [c for c in colors if id(c) not in bg_set and id(c) not in fg_set]
mid.sort(key=lambda c: to_hsv(*c)[1], reverse=True)  # most saturated first

targets = [
    ('red',    0.00),
    ('yellow', 0.14),
    ('green',  0.33),
    ('teal',   0.50),
    ('blue',   0.63),
    ('purple', 0.80),
]

pool = [(to_hsv(*c)[0], to_hsv(*c)[1], c) for c in mid]
used = set()
accents = {}

for name, target_hue in targets:
    candidates = sorted(
        [(hue_dist(h, target_hue) - s * 0.4, i, c) for i, (h, s, c) in enumerate(pool) if i not in used],
        key=lambda x: x[0]
    )
    if not candidates:
        # Derive a fallback from base with the target hue
        h, s, v = to_hsv(*base)
        fallback = from_hsv(target_hue, max(0.4, s + 0.2), min(1.0, v + 0.25) if dark_theme else max(0.0, v - 0.25))
        accents[name] = fallback
        continue

    top = candidates[:3]
    chosen_c = weighted_choice(top, rng)
    chosen_i = next(i for _, i, c in top if c is chosen_c)
    used.add(chosen_i)
    accents[name] = jitter(chosen_c, rng)

# ── Readability pass on accents ────────────────────────────────────────────────
for name in accents:
    accents[name] = push_toward_readable(accents[name], base, dark_theme, target_ratio=4.5)

order = ['base', 'surface', 'border', 'text', 'subtext', 'blue', 'green', 'red', 'yellow', 'teal', 'purple']
result = {
    'base': base, 'surface': surface, 'border': border,
    'text': text, 'subtext': subtext,
    **{k: accents[k] for k in ('blue', 'green', 'red', 'yellow', 'teal', 'purple')},
}
print(' '.join(to_hex(*result[k]) for k in order))
