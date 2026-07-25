#!/usr/bin/env python3
"""App Store screenshots, composed in the app's own language.

Each frame is the obsidian canvas the app itself is: a bone General Sans
headline, a fog subline, and the real screenshot below it. No device bezels,
no gradients, no drop shadows, no floating phones at jaunty angles. The
product is restraint; the store page should be the first proof of it.

Source screenshots are captured from the iOS 27 iPhone 17 Pro Max simulator at
1320x2868, which is the App Store's 6.9" size, so the inset is a straight
downscale with no cropping or letterboxing.

Usage: python3 scripts/make_appstore_shots.py <source-dir> <out-dir>
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 1320, 2868           # App Store 6.9"
OBSIDIAN = (16, 16, 16)
BONE = (255, 253, 249)
FOG = (111, 135, 156)
ASH = (64, 63, 63)

MARGIN = 96
HEAD_TOP = 150
SHOT_W = 940                # leaves the type room to breathe
CORNER = 118                # the device's own screen radius, scaled

ROOT = os.path.join(os.path.dirname(__file__), "..")
REGULAR = os.path.join(ROOT, "Minus/Resources/Fonts/GeneralSans-Regular.otf")

# (source file, headline, subline). Headlines carry the app's voice: one
# sentence, sentence case, a full stop. Sublines stay lowercase and factual.
FRAMES = [
    ("shot-widget.png",
     "Your home screen,\nminus everything else.",
     "one widget. the apps you meant.\nnothing you didn’t."),
    ("shot-home.png",
     "A clock, a goal,\nand a short list.",
     "no badges. no feed.\nno reason to stay."),
    ("shot-focus.png",
     "Focus that\nactually holds.",
     "real screen time shields.\ndeleting minus always lifts them."),
    ("shot-cards.png",
     "Any app you own,\non a card you built.",
     "search hundreds minus already knows,\nor add any name from the app store."),
    ("shot-schedules.png",
     "Set it once.\nIt runs itself.",
     "recurring windows that start\nbefore you think to open anything."),
]


def draw_block(draw, text, font, fill, x, y, leading, tracking):
    """Per-character drawing so tracking matches the app's type tokens."""
    for line in text.split("\n"):
        cursor = float(x)
        for char in line:
            draw.text((cursor, y), char, font=font, fill=fill)
            cursor += font.getlength(char) + tracking
        y += leading
    return y


def compose(src_path, headline, subline, out_path):
    canvas = Image.new("RGB", (W, H), OBSIDIAN)
    draw = ImageDraw.Draw(canvas)

    head_font = ImageFont.truetype(REGULAR, 104)
    sub_font = ImageFont.truetype(REGULAR, 46)

    y = draw_block(draw, headline, head_font, BONE, MARGIN, HEAD_TOP,
                   leading=126, tracking=-2.0)
    y = draw_block(draw, subline, sub_font, FOG, MARGIN, y + 30,
                   leading=62, tracking=0.4)

    shot = Image.open(src_path).convert("RGB")
    ratio = SHOT_W / shot.width
    shot = shot.resize((SHOT_W, int(shot.height * ratio)), Image.LANCZOS)

    # Rounded corners, so the inset reads as a screen rather than a pasted
    # rectangle. Drawn as a mask; the canvas shows through.
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width - 1, shot.height - 1],
                                           radius=CORNER, fill=255)
    x = (W - SHOT_W) // 2
    top = int(y + 90)
    canvas.paste(shot, (x, top), mask)

    # A single hairline at 10% bone: enough to separate a black screenshot
    # from a black canvas, invisible enough not to become a border.
    edge = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [x, top, x + shot.width - 1, top + shot.height - 1],
        radius=CORNER, outline=BONE + (26,), width=2)
    canvas = Image.alpha_composite(canvas.convert("RGBA"), edge).convert("RGB")

    canvas.save(out_path)
    return out_path


def main():
    src_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    for index, (name, headline, subline) in enumerate(FRAMES, start=1):
        src = os.path.join(src_dir, name)
        if not os.path.exists(src):
            print(f"  missing {name}, skipped")
            continue
        out = os.path.join(out_dir, f"{index:02d}-{name.replace('shot-', '')}")
        compose(src, headline, subline, out)
        print(f"  {os.path.basename(out)}")


main()
