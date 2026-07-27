#!/usr/bin/env python3
"""App Store screenshots, composed in the app's own language.

Each frame is the obsidian canvas the app itself is: a bone General Sans
headline, a fog subline, and the real screenshot below it, seated in Apple's
own iPhone 17 Pro Max bezel (Design Resources, Deep Blue). No gradients, no
drop shadows, no floating phones at jaunty angles. The product is restraint;
the store page should be the first proof of it.

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

# The app's own token pairs. A frame showing light mode is composed ON paper,
# so the store page demonstrates both appearances instead of describing one.
PAPER = (247, 244, 238)
INK = (16, 16, 16)
FOG_INK = (85, 105, 123)

DARK = {"canvas": OBSIDIAN, "head": BONE, "sub": FOG}
LIGHT = {"canvas": PAPER, "head": INK, "sub": FOG_INK}

MARGIN = 96
HEAD_TOP = 150
DEVICE_W = 980              # framed device width; leaves the type room to breathe

ROOT = os.path.join(os.path.dirname(__file__), "..")
REGULAR = os.path.join(ROOT, "Minus/Resources/Fonts/GeneralSans-Regular.otf")

# Apple's iPhone 17 Pro Max bezel (1470x3000). Its transparent screen window
# sits at (75, 66) and is exactly 1320x2868, so a raw simulator screenshot
# drops in 1:1 with no scaling before the whole device is downsized.
BEZEL = os.path.join(ROOT, "QA/appstore/bezel/iphone-17-pro-max-deep-blue.png")
BEZEL_SCREEN_XY = (75, 66)
BEZEL_SCREEN_SIZE = (1320, 2868)

# The screen's exact silhouette (rounded corners), flood-filled once from the
# bezel's alpha. Without it the raw's square corners poke past the device's
# own rounded corner, where the bezel is transparent, and leak onto the canvas.
SCREEN_MASK = os.path.join(ROOT, "QA/appstore/bezel/screen-mask.png")

# (source file, headline, subline, palette). Headlines carry the app's voice:
# one sentence, sentence case, a full stop. Sublines stay lowercase and
# factual. The typeface frame is composed on paper because it is the one
# showing the app in daylight.
FRAMES = [
    ("shot-widget.png",
     "Your home screen,\nminus everything else.",
     "one widget. the apps you meant.\nnothing you didn’t.",
     DARK),
    ("shot-home.png",
     "Nothing to check.\nOnly things to do.",
     "no badges. no feed.\nno reason to stay.",
     DARK),
    ("shot-typeface.png",
     "It reads how you like.",
     "five typefaces, light or dark.\nyour widgets follow.",
     LIGHT),
    ("shot-focus.png",
     "Focus that\nactually holds.",
     "real screen time shields.\ndeleting minus always lifts them.",
     DARK),
    ("shot-cards.png",
     "Any app you own,\non a card you built.",
     "search hundreds minus already knows,\nor add any name from the app store.",
     DARK),
    ("shot-schedules.png",
     "Set it once.\nIt runs itself.",
     "recurring windows that start\nbefore you think to open anything.",
     DARK),
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


def compose(src_path, headline, subline, palette, out_path):
    canvas = Image.new("RGB", (W, H), palette["canvas"])
    draw = ImageDraw.Draw(canvas)

    head_font = ImageFont.truetype(REGULAR, 104)
    sub_font = ImageFont.truetype(REGULAR, 46)

    y = draw_block(draw, headline, head_font, palette["head"], MARGIN, HEAD_TOP,
                   leading=126, tracking=-2.0)
    y = draw_block(draw, subline, sub_font, palette["sub"], MARGIN, y + 30,
                   leading=62, tracking=0.4)

    # Seat the raw screenshot in the bezel at native size, then downsize the
    # whole device once. The bezel's anti-aliased edge does the separating
    # that the old hairline used to; the island and screen corners are the
    # bezel's own.
    shot = Image.open(src_path).convert("RGBA")
    if shot.size != BEZEL_SCREEN_SIZE:
        raise SystemExit(f"{src_path}: {shot.size}, expected {BEZEL_SCREEN_SIZE}")
    bezel = Image.open(BEZEL).convert("RGBA")
    x0, y0 = BEZEL_SCREEN_XY
    window = Image.open(SCREEN_MASK).convert("L").crop(
        (x0, y0, x0 + shot.width, y0 + shot.height))
    device = Image.new("RGBA", bezel.size, (0, 0, 0, 0))
    device.paste(shot, BEZEL_SCREEN_XY, window)
    device = Image.alpha_composite(device, bezel)

    ratio = DEVICE_W / device.width
    device = device.resize((DEVICE_W, int(device.height * ratio)), Image.LANCZOS)
    x = (W - DEVICE_W) // 2
    top = int(y + 90)
    canvas = canvas.convert("RGBA")
    canvas.alpha_composite(device, (x, top))
    canvas = canvas.convert("RGB")

    canvas.save(out_path)
    return out_path


def main():
    src_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    for index, (name, headline, subline, palette) in enumerate(FRAMES, start=1):
        src = os.path.join(src_dir, name)
        if not os.path.exists(src):
            print(f"  missing {name}, skipped")
            continue
        out = os.path.join(out_dir, f"{index:02d}-{name.replace('shot-', '')}")
        compose(src, headline, subline, palette, out)
        print(f"  {os.path.basename(out)}")


main()
