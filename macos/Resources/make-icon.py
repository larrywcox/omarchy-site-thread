#!/usr/bin/env python3
"""Regenerates AppIcon.iconset.

The mark is a hub with three threaded sites — the app's own, not Ubiquiti's
logo — drawn in UniFi's visual idiom: a dark navy squircle and a bright blue
network motif.

The PNGs are committed because macOS ships no SVG rasteriser, so a build does
not need Python or Pillow. Run this only when changing the artwork:

    pip install Pillow
    python3 macos/Resources/make-icon.py
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

NAVY_TOP = (13, 37, 74)
NAVY_BOTTOM = (5, 12, 26)
BLUE = (46, 155, 255)
BLUE_DIM = (46, 155, 255, 90)
WHITE = (255, 255, 255)

# (file name, pixel size, size in points). The point size decides how much
# detail is drawn, so an @2x file matches its @1x sibling instead of gaining a
# ring the smaller one lacks.
VARIANTS = [
    ("icon_16x16.png", 16, 16),
    ("icon_16x16@2x.png", 32, 16),
    ("icon_32x32.png", 32, 32),
    ("icon_32x32@2x.png", 64, 32),
    ("icon_128x128.png", 128, 128),
    ("icon_128x128@2x.png", 256, 128),
    ("icon_256x256.png", 256, 256),
    ("icon_256x256@2x.png", 512, 256),
    ("icon_512x512.png", 512, 512),
    ("icon_512x512@2x.png", 1024, 512),
]


def draw(pixels: int, points: int | None = None) -> Image.Image:
    """Render the icon at `pixels` square, detailed for a `points` display."""
    points = points or pixels
    supersample = 8 if pixels <= 128 else 4
    n = pixels * supersample
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))

    inset = n * 0.09
    side = n - 2 * inset
    radius = side * 0.2237

    gradient = Image.new("RGBA", (1, n))
    for y in range(n):
        t = y / max(1, n - 1)
        gradient.putpixel((0, y), tuple(
            int(NAVY_TOP[i] + (NAVY_BOTTOM[i] - NAVY_TOP[i]) * t) for i in range(3)
        ) + (255,))

    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [inset, inset, n - inset, n - inset], radius=radius, fill=255
    )
    img.paste(gradient.resize((n, n)), (0, 0), mask)

    canvas = ImageDraw.Draw(img, "RGBA")
    cx = cy = n / 2
    # Below 64pt the ring turns to mush, so the mark simplifies.
    simple = points < 64

    if not simple:
        ring = side * 0.355
        canvas.ellipse(
            [cx - ring, cy - ring, cx + ring, cy + ring],
            outline=BLUE_DIM, width=max(1, int(side * 0.016)),
        )

    orbit = side * 0.245
    hub_r = side * (0.105 if simple else 0.088)
    sat_r = side * (0.072 if simple else 0.058)
    sites = [
        (cx + orbit * math.cos(math.radians(a)), cy + orbit * math.sin(math.radians(a)))
        for a in (-90, 30, 150)
    ]

    for x, y in sites:
        canvas.line([cx, cy, x, y], fill=BLUE, width=max(1, int(side * 0.032)))
    for x, y in sites:
        canvas.ellipse([x - sat_r, y - sat_r, x + sat_r, y + sat_r], fill=BLUE)
    canvas.ellipse([cx - hub_r, cy - hub_r, cx + hub_r, cy + hub_r], fill=WHITE)

    return img.resize((pixels, pixels), Image.LANCZOS)


def main() -> None:
    target = Path(__file__).resolve().parent / "AppIcon.iconset"
    target.mkdir(exist_ok=True)
    for name, pixels, points in VARIANTS:
        draw(pixels, points).save(target / name)
        print(f"  {name} ({pixels}px)")
    print(f"wrote {len(VARIANTS)} files to {target}")


if __name__ == "__main__":
    main()
