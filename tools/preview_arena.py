#!/usr/bin/env python3
"""Renders a mock-up of the arena using the same geometry Arena.gd uses.

There is no way to eyeball the real thing without opening Godot, so this
composes the generated art at true game scale to sanity-check readability
(contrast between pit and surround, sprite size vs pit size, wall rim).

    python3 tools/preview_arena.py [stage_index] [out.png]
"""

import math
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BG_DIR = os.path.join(ROOT, "Assets", "Backgrounds")
SPRITE_DIR = os.path.join(ROOT, "Assets", "Sprites")

# Mirrors Arena.gd's exports and GameState's stage table.
VIEW = (1280, 720)
PIT_RADIUS = 300.0
PIT_SIDES = 8
WALL_THICKNESS = 24.0
WALL_OVERLAP = 8.0
FRAME_W, FRAME_H = 32, 44
ART_SCALE = 2  # sprites and ground tiles all render at 2x in-game

STAGES = [
    ("Wayside Elementary", "wood", "gym", 3),
    ("Oakridge Middle", "court", "gym", 3),
    ("Bayou Academy", "blacktop", "grass", 3),
    ("Pinecrest Camp", "dirt", "grass", 3),
    ("Redwood Charter", "dirt", "grass", 3),
    ("Inner Harbor Middle", "blacktop", "city", 3),
    ("Desert Oasis High", "sand", "desert", 9),
    ("Brickstone Prep", "court", "city", 3),
    ("Metro Tech", "steel", "industrial", 3),
    ("National Championship", "court", "arena", 4),
]
WALL_COLORS = {
    "wood": (122, 79, 44), "dirt": (107, 84, 58), "sand": (169, 140, 86),
    "blacktop": (63, 68, 80), "steel": (141, 148, 166), "court": (140, 90, 48),
}
TEAM_SHEETS = ["character_blue", "character_red", "character_green"]


def tiled(texture, size):
    texture = texture.resize(
        (texture.width * ART_SCALE, texture.height * ART_SCALE), Image.NEAREST)
    out = Image.new("RGBA", size)
    for y in range(0, size[1], texture.height):
        for x in range(0, size[0], texture.width):
            out.paste(texture, (x, y))
    return out


def octagon_points(center):
    pts = []
    for i in range(PIT_SIDES):
        angle = math.tau * (i + 0.5) / PIT_SIDES
        pts.append((center[0] + math.cos(angle) * PIT_RADIUS,
                    center[1] + math.sin(angle) * PIT_RADIUS))
    return pts


def lighten(color, amount):
    return tuple(int(c + (255 - c) * amount) for c in color)


def render(stage_index=0):
    name, floor_theme, surround_theme, cpu_count = STAGES[stage_index]
    center = (VIEW[0] / 2, VIEW[1] / 2)

    img = tiled(Image.open(os.path.join(BG_DIR, f"surround_{surround_theme}.png")), VIEW)

    pts = octagon_points(center)
    floor = tiled(Image.open(os.path.join(BG_DIR, f"floor_{floor_theme}.png")), VIEW)
    mask = Image.new("L", VIEW, 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    img.paste(floor, (0, 0), mask)

    draw = ImageDraw.Draw(img, "RGBA")
    draw.line(pts + [pts[0]], fill=(15, 13, 23, 165), width=6)

    wall_color = WALL_COLORS[floor_theme]
    for i in range(PIT_SIDES):
        a, b = pts[i], pts[(i + 1) % PIT_SIDES]
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        outward = (mid[0] - center[0], mid[1] - center[1])
        norm = math.hypot(*outward)
        outward = (outward[0] / norm, outward[1] / norm)
        pos = (mid[0] + outward[0] * WALL_THICKNESS / 2,
               mid[1] + outward[1] * WALL_THICKNESS / 2)
        angle = math.atan2(b[1] - a[1], b[0] - a[0])
        half_len = (math.dist(a, b) + WALL_OVERLAP) / 2
        half_th = WALL_THICKNESS / 2
        ux, uy = math.cos(angle), math.sin(angle)
        px, py = -uy, ux  # perpendicular

        def corner(sl, st):
            return (pos[0] + ux * half_len * sl + px * half_th * st,
                    pos[1] + uy * half_len * sl + py * half_th * st)

        draw.polygon([corner(-1, -1), corner(1, -1), corner(1, 1), corner(-1, 1)],
                     fill=wall_color)
        # Lit cap on whichever side faces the pit (matches Arena.gd).
        inward = (-pos[0], -pos[1])
        inward_local_y = inward[0] * math.sin(-angle) + inward[1] * math.cos(-angle)
        inward_sign = 1 if inward_local_y > 0 else -1
        cap_outer = half_th * inward_sign
        cap_inner = cap_outer - 5.0 * inward_sign

        def cap_corner(sl, dist):
            return (pos[0] + ux * half_len * sl + px * dist,
                    pos[1] + uy * half_len * sl + py * dist)

        draw.polygon([cap_corner(-1, cap_inner), cap_corner(1, cap_inner),
                      cap_corner(1, cap_outer), cap_corner(-1, cap_outer)],
                     fill=lighten(wall_color, 0.35))

    # Roster: player at the bottom slot, CPUs evenly around the ring.
    total = cpu_count + 1
    spawn_r = PIT_RADIUS * 0.65
    sheets = [Image.open(os.path.join(SPRITE_DIR, "character_gold.png"))]
    for i in range(cpu_count):
        sheets.append(Image.open(
            os.path.join(SPRITE_DIR, f"{TEAM_SHEETS[i % len(TEAM_SHEETS)]}.png")))

    for i, sheet in enumerate(sheets):
        angle = math.pi / 2 + math.tau * i / total
        node = (center[0] + math.cos(angle) * spawn_r,
                center[1] + math.sin(angle) * spawn_r)
        # Face roughly toward the middle, mirroring Character._facing_row().
        fx, fy = center[0] - node[0], center[1] - node[1]
        if abs(fx) > abs(fy):
            row, flip = 1, fx < 0
        else:
            row, flip = (2, False) if fy < 0 else (0, False)
        col = 0 if i % 2 else 1  # mix idle and mid-stride
        frame = sheet.crop((col * FRAME_W, row * FRAME_H,
                            (col + 1) * FRAME_W, (row + 1) * FRAME_H))
        if flip:
            frame = frame.transpose(Image.FLIP_LEFT_RIGHT)
        frame = frame.resize((FRAME_W * ART_SCALE, FRAME_H * ART_SCALE), Image.NEAREST)
        # Sprite node sits at (0, -32) with scale 2, so its center is 32px up.
        img.alpha_composite(frame, (int(node[0]) - frame.width // 2,
                                    int(node[1]) - 32 - frame.height // 2))

    ball = Image.open(os.path.join(SPRITE_DIR, "ball.png"))
    ball = ball.resize((ball.width * ART_SCALE, ball.height * ART_SCALE), Image.NEAREST)
    img.alpha_composite(ball, (int(center[0]) - ball.width // 2,
                               int(center[1]) - ball.height // 2))
    return name, img


def main():
    index = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    out = sys.argv[2] if len(sys.argv) > 2 else "arena_preview.png"
    name, img = render(index)
    img.convert("RGB").save(out)
    print(f"{name} -> {out}")


if __name__ == "__main__":
    main()
