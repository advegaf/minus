#!/usr/bin/env python3
"""The launch wordmark: "minus" in General Sans on transparent, at the
displaySm size with its tracking. The launch screen paints LaunchBackground
underneath, so the PNG carries type only — no field, no container, nothing
that could disagree with the canvas the app opens into.

Two inks, because the app follows the phone: bone for the void, obsidian for
paper. Bone on a light launch background would be an invisible word, which is
the one place light mode is a bug rather than a taste call.

displaySm rather than headingLg because this word is alone on a whole screen:
at 40pt it read timid in the void, at 64 it holds it. The storyboard then
places it at the optical centre (45% of height), not the geometric one.

Writes 1x/2x/3x into LaunchWordmark.imageset.
"""
from PIL import Image, ImageDraw, ImageFont
import json
import os

WORD = "minus"
PT = 64.0          # MNType.displaySm
TRACKING = -0.02   # em, matching --tracking-display-sm (-2.1px at 105px)
BONE = (255, 253, 249, 255)
INK = (16, 16, 16, 255)

ROOT = os.path.join(os.path.dirname(__file__), "..")
FONT = os.path.join(ROOT, "Minus/Resources/Fonts/GeneralSans-Regular.otf")
OUT = os.path.join(ROOT, "Minus/Resources/Assets.xcassets/LaunchWordmark.imageset")


def render(scale, fill, suffix):
    size = int(round(PT * scale))
    font = ImageFont.truetype(FONT, size)
    spacing = TRACKING * size

    # Measure with tracking applied between glyphs (the last letter carries no
    # trailing space, so the box hugs the word on both sides).
    widths = [font.getlength(ch) for ch in WORD]
    total_w = sum(widths) + spacing * (len(WORD) - 1)

    probe = font.getbbox(WORD)
    pad = int(round(size * 0.25))  # room for descenders and antialiasing
    img = Image.new("RGBA", (int(round(total_w)) + 2 * pad, probe[3] - probe[1] + 2 * pad), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    x = float(pad)
    for ch, w in zip(WORD, widths):
        draw.text((x, pad - probe[1]), ch, font=font, fill=fill)
        x += w + spacing

    path = os.path.join(OUT, f"wordmark{suffix}@{scale}x.png")
    img.save(path)
    return os.path.basename(path)


os.makedirs(OUT, exist_ok=True)
# The unmarked entry is what a light appearance uses, so it carries the ink;
# the dark entry carries the bone. Same word, same metrics, two inks.
images = []
for s in (1, 2, 3):
    images.append({
        "idiom": "universal",
        "scale": f"{s}x",
        "filename": render(s, INK, "-ink"),
    })
    images.append({
        "idiom": "universal",
        "scale": f"{s}x",
        "filename": render(s, BONE, ""),
        "appearances": [{"appearance": "luminosity", "value": "dark"}],
    })
with open(os.path.join(OUT, "Contents.json"), "w") as f:
    json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
print("wrote", OUT)
