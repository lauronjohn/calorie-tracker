#!/usr/bin/env python3
"""Generate the app icon.

Kept as a script so the icon stays editable without design software — tweak the
constants below and re-run. Writes the single 1024x1024 PNG that Xcode 15+ needs;
iOS applies the rounded-corner mask itself, so the artwork is a full square with
no transparency.

    python3 Tools/make_app_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

# Drawn large and downsampled — PIL has no antialiasing on arcs or rectangles.
SUPERSAMPLE = 4
FINAL = 1024
S = FINAL * SUPERSAMPLE

BG_TOP = (30, 22, 17)
BG_BOTTOM = (12, 9, 7)
TRACK = (58, 47, 39)
RING_START = (255, 122, 24)   # warm orange
RING_END = (255, 197, 61)     # amber
CUTLERY = (245, 239, 230)

RING_RADIUS = 0.325           # fraction of the canvas
RING_WIDTH = 0.082
RING_SWEEP = 268              # degrees; deliberately not a full circle

OUTPUT = Path(__file__).resolve().parents[1] / (
    "Sources/CalorieTracker/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def draw_background(draw):
    for y in range(S):
        draw.line([(0, y), (S, y)], fill=lerp(BG_TOP, BG_BOTTOM, y / S))


def draw_ring(draw):
    cx = cy = S / 2
    radius = S * RING_RADIUS
    width = S * RING_WIDTH
    box = [cx - radius, cy - radius, cx + radius, cy + radius]

    # Unfilled remainder of the goal, so the ring reads as progress.
    draw.ellipse(box, outline=TRACK, width=round(width))

    # Segment-wise so the arc can carry a gradient.
    start = -90
    steps = 180
    for i in range(steps):
        a0 = start + RING_SWEEP * i / steps
        a1 = start + RING_SWEEP * (i + 1) / steps + 0.6  # overlap hides seams
        draw.arc(box, a0, a1, fill=lerp(RING_START, RING_END, i / steps), width=round(width))

    _round_cap(draw, cx, cy, radius, width, start, RING_START)
    _round_cap(draw, cx, cy, radius, width, start + RING_SWEEP, RING_END)


def _round_cap(draw, cx, cy, radius, width, angle_deg, colour):
    from math import cos, radians, sin

    x = cx + radius * cos(radians(angle_deg))
    y = cy + radius * sin(radians(angle_deg))
    r = width / 2
    draw.ellipse([x - r, y - r, x + r, y + r], fill=colour)


def draw_fork(draw):
    """A minimal fork, so the mark reads as food rather than generic fitness."""
    cx = S / 2
    total_h = S * 0.300
    top = S / 2 - total_h / 2

    tine_w = S * 0.028
    tine_h = S * 0.108
    gap = S * 0.050
    radius = tine_w / 2

    for offset in (-gap, 0.0, gap):
        x = cx + offset
        draw.rounded_rectangle(
            [x - tine_w / 2, top, x + tine_w / 2, top + tine_h],
            radius=radius,
            fill=CUTLERY,
        )

    head_h = S * 0.034
    head_w = 2 * gap + tine_w
    head_top = top + tine_h - head_h * 0.35
    draw.rounded_rectangle(
        [cx - head_w / 2, head_top, cx + head_w / 2, head_top + head_h],
        radius=head_h / 2,
        fill=CUTLERY,
    )

    stem_w = S * 0.032
    draw.rounded_rectangle(
        [cx - stem_w / 2, head_top + head_h * 0.4, cx + stem_w / 2, top + total_h],
        radius=stem_w / 2,
        fill=CUTLERY,
    )


def main():
    image = Image.new("RGB", (S, S), BG_BOTTOM)
    draw = ImageDraw.Draw(image)

    draw_background(draw)
    draw_ring(draw)
    draw_fork(draw)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.resize((FINAL, FINAL), Image.LANCZOS).save(OUTPUT, "PNG")
    print(f"wrote {OUTPUT.relative_to(Path(__file__).resolve().parents[1])} ({FINAL}x{FINAL})")


if __name__ == "__main__":
    main()
