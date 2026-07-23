#!/usr/bin/env python3
import sys
import base64
import json
import os
import urllib.request
import urllib.error

KEY_FILE = os.path.expanduser("~/.config/quickshell/anthropic-key")

def auto_tag(image_path):
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key and os.path.exists(KEY_FILE):
        with open(KEY_FILE) as f:
            api_key = f.read().strip()
    if not api_key:
        print("error: no API key — set ANTHROPIC_API_KEY or write it to ~/.config/quickshell/anthropic-key", file=sys.stderr)
        sys.exit(1)

    with open(image_path, "rb") as f:
        data = base64.standard_b64encode(f.read()).decode("utf-8")

    ext = image_path.rsplit(".", 1)[-1].lower()
    mime = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
            "webp": "image/webp", "gif": "image/gif"}.get(ext, "image/jpeg")

    payload = {
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 80,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "image", "source": {"type": "base64", "media_type": mime, "data": data}},
                {"type": "text", "text": (
                    "Give 3-6 short lowercase tags for this desktop wallpaper. "
                    "Consider: subject (nature, city, space, abstract, anime, architecture, portrait, forest, ocean, mountains, sunset, night), "
                    "mood (dark, bright, calm, vibrant, moody, cozy), "
                    "palette (warm, cool, monochrome, colorful, pastel). "
                    "Return ONLY a comma-separated list, nothing else. "
                    "Example: nature,forest,dark,cool"
                )}
            ]
        }]
    }

    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode(),
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        method="POST"
    )

    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read().decode())

    raw = result["content"][0]["text"].strip()
    tags = [t.strip().lower() for t in raw.split(",") if t.strip()]
    print(",".join(tags))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: auto-tag-wallpaper.py <image_path>", file=sys.stderr)
        sys.exit(1)
    auto_tag(sys.argv[1])
