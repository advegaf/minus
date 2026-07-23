#!/usr/bin/env python3
"""The minus icon: a bone-white minus bar on obsidian, edges carrying the
prism's RGB split — the brand in one glyph. Writes the 1024pt master into
AppIcon.appiconset."""
from PIL import Image, ImageChops, ImageDraw, ImageFilter
import os

S = 1024
OBSIDIAN = (16, 16, 16)
BONE = (255, 253, 249)

BAR_W, BAR_H = 552, 88
BAR_X = (S - BAR_W) // 2
BAR_Y = (S - BAR_H) // 2


def bar_layer(color, dx, dy):
    layer = Image.new("RGB", (S, S), (0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle([BAR_X + dx, BAR_Y + dy, BAR_X + BAR_W + dx, BAR_Y + BAR_H + dy], fill=color)
    return layer


base = Image.new("RGB", (S, S), OBSIDIAN)

# Additive RGB clones — chromatic light at the edges, softened so it reads as
# dispersion, not misregistration.
glow = Image.new("RGB", (S, S), (0, 0, 0))
glow = ImageChops.add(glow, bar_layer((235, 45, 45), -8, -6))
glow = ImageChops.add(glow, bar_layer((45, 125, 235), 8, 6))
glow = ImageChops.add(glow, bar_layer((45, 225, 45), 0, 9))
glow = glow.filter(ImageFilter.GaussianBlur(5))
base = ImageChops.add(base, glow)

# The bone bar on top hides the clones except at the fringes.
d = ImageDraw.Draw(base)
d.rectangle([BAR_X, BAR_Y, BAR_X + BAR_W, BAR_Y + BAR_H], fill=BONE)

out = os.path.join(
    os.path.dirname(__file__), "..",
    "Minus/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
)
base.save(out)
print("wrote", out)
