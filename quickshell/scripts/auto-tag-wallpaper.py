#!/usr/bin/env python3
import sys, base64, json, os, argparse, urllib.request

OLLAMA    = "http://localhost:11434"
WP_DIR    = os.path.expanduser("~/wallpapers")
TAGS_FILE = os.path.join(WP_DIR, ".tags")
HINTS_FILE = os.path.join(WP_DIR, ".tag-hints")
EXTS      = {".jpg", ".jpeg", ".png", ".webp", ".gif"}

STANDARD_TAGS = (
    "nature, city, space, abstract, anime, architecture, portrait, "
    "forest, ocean, mountains, sunset, night, animals, fantasy, scifi, minimal"
)

def _post(path, payload):
    req = urllib.request.Request(
        OLLAMA + path,
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=90) as resp:
        return json.loads(resp.read().decode())

def load_hints():
    try:
        with open(HINTS_FILE) as f:
            return [t.strip().lower() for t in f.read().split(",") if t.strip()]
    except Exception:
        return []

def tag_image(image_path, hints, vision_model, text_model):
    with open(image_path, "rb") as f:
        data = base64.standard_b64encode(f.read()).decode()

    desc = _post("/api/chat", {
        "model":    vision_model,
        "messages": [{"role": "user", "content": "Describe this image in one or two sentences.", "images": [data]}],
        "stream":   False,
    })["message"]["content"].strip()

    if not desc:
        return None

    hint_line = (
        f"Prioritise these tags if they fit: {', '.join(hints)}.\n"
        if hints else ""
    )

    raw = _post("/api/generate", {
        "model":  text_model,
        "prompt": (
            f"Image description: {desc}\n\n"
            f"{hint_line}"
            f"Also pick from these if applicable: {STANDARD_TAGS}.\n"
            "Mood tags: dark, bright, calm, vibrant, moody, cozy, dramatic.\n"
            "Palette tags: warm, cool, monochrome, colorful, pastel.\n"
            "Return 3-8 tags total as a comma-separated list, nothing else."
        ),
        "stream": False,
    })["response"].strip()

    return [t.strip().lower() for t in raw.split(",") if t.strip()]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--min-cat", type=int, default=1,
                        help="remove tags that appear on fewer than N wallpapers after tagging")
    parser.add_argument("--vision-model", default="moondream",
                        help="Ollama model to use for image description")
    parser.add_argument("--text-model", default="qwen2.5-coder:7b",
                        help="Ollama model to use for tag extraction")
    parser.add_argument("--retag", action="store_true",
                        help="clear all existing tags and retag from scratch")
    args = parser.parse_args()

    all_files = sorted(
        f for f in os.listdir(WP_DIR)
        if os.path.splitext(f)[1].lower() in EXTS
    )

    if args.retag:
        tags = {}
        print("retagging from scratch", file=sys.stderr, flush=True)
    else:
        try:
            with open(TAGS_FILE) as f:
                tags = json.load(f)
        except Exception:
            tags = {}

    hints = load_hints()
    if hints:
        print(f"hints: {', '.join(hints)}", file=sys.stderr, flush=True)

    untagged = [f for f in all_files if f not in tags]
    total = len(untagged)
    print(f"{total} untagged", file=sys.stderr, flush=True)

    for i, filename in enumerate(untagged, 1):
        path = os.path.join(WP_DIR, filename)
        print(f"[{i}/{total}] {filename}", file=sys.stderr, flush=True)
        try:
            new_tags = tag_image(path, hints, args.vision_model, args.text_model)
            if new_tags:
                existing = tags.get(filename, [])
                tags[filename] = list(dict.fromkeys(existing + new_tags))
                with open(TAGS_FILE, "w") as f:
                    json.dump(tags, f)
        except Exception as e:
            print(f"  error: {e}", file=sys.stderr, flush=True)

    # Strip tags that don't meet the minimum category size
    if args.min_cat > 1:
        from collections import Counter
        counts = Counter(tag for ts in tags.values() for tag in ts)
        rare   = {tag for tag, n in counts.items() if n < args.min_cat}
        if rare:
            print(f"pruning rare tags (<{args.min_cat}): {', '.join(sorted(rare))}", file=sys.stderr, flush=True)
            for filename in list(tags):
                tags[filename] = [t for t in tags[filename] if t not in rare]
                if not tags[filename]:
                    del tags[filename]
            with open(TAGS_FILE, "w") as f:
                json.dump(tags, f)

if __name__ == "__main__":
    main()
