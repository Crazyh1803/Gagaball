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
PIT_RADIUS = 330.0
PIT_CENTER_Y = 115.0
PIT_VERTICAL_SCALE = 0.36
PIT_PERSPECTIVE_TAPER = 0.13
PIT_SIDES = 8
WALL_THICKNESS = 24.0
WALL_OVERLAP = 8.0
WALL_VISUAL_HEIGHT = 10.0
FRONT_WALL_VISUAL_HEIGHT = 3.0
WALL_VISUAL_THICKNESS = 10.0
FRAME_W, FRAME_H = 32, 44
GROUND_SCALE = 2
FIGHTER_SCALE = 2.4

STAGES = [
    ("Aukamm Elementary", "blacktop", "backdrop_wiesbaden", "8a603d", 3),
    ("Oakridge Middle", "court", "backdrop_topeka", "8b5a32", 3),
    ("Bayou Academy", "blacktop", "backdrop_houston", "4f6657", 3),
    ("Pinecrest Camp", "dirt", "backdrop_maine", "7b4930", 3),
    ("Redwood Charter", "dirt", "backdrop_humboldt", "6d3f32", 3),
    ("Inner Harbor Middle", "blacktop", "backdrop_baltimore", "405a6f", 3),
    ("Desert Oasis High", "sand", "backdrop_phoenix", "a66a3f", 9),
    ("Brickstone Prep", "court", "backdrop_boston", "70413c", 3),
    ("Metro Tech", "steel", "backdrop_chicago", "737b88", 3),
    ("National Championship", "court", "backdrop_orlando", "9a653b", 4),
]
WALL_COLORS = {
    "wood": (122, 79, 44), "dirt": (107, 84, 58), "sand": (169, 140, 86),
    "blacktop": (118, 80, 51), "steel": (141, 148, 166), "court": (128, 89, 54),
}
TEAM_SHEETS = ["character_blue", "character_red", "character_green"]


def tiled(texture, size):
    texture = texture.resize(
        (texture.width * GROUND_SCALE, texture.height * GROUND_SCALE), Image.NEAREST)
    out = Image.new("RGBA", size)
    for y in range(0, size[1], texture.height):
        for x in range(0, size[0], texture.width):
            out.paste(texture, (x, y))
    return out


def octagon_points(center):
    pts = []
    for i in range(PIT_SIDES):
        angle = math.tau * (i + 0.5) / PIT_SIDES
        world_y = math.sin(angle) * PIT_RADIUS
        width_scale = 1.0 + (world_y / PIT_RADIUS) * PIT_PERSPECTIVE_TAPER
        pts.append((center[0] + math.cos(angle) * PIT_RADIUS * width_scale,
                    center[1] + world_y * PIT_VERTICAL_SCALE))
    return pts


def lighten(color, amount):
    return tuple(int(c + (255 - c) * amount) for c in color)


def render(stage_index=0):
    name, floor_theme, backdrop_name, wall_hex, cpu_count = STAGES[stage_index]
    center = (VIEW[0] / 2, VIEW[1] / 2 + PIT_CENTER_Y)

    img = Image.open(os.path.join(BG_DIR, "Stages", f"{backdrop_name}.png"))
    img = img.convert("RGBA").resize(VIEW, Image.NEAREST)

    pts = octagon_points(center)
    floor = tiled(Image.open(os.path.join(BG_DIR, f"floor_{floor_theme}.png")), VIEW)
    mask = Image.new("L", VIEW, 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    floor.putalpha(mask.point(lambda value: int(value * 0.24)))
    img.alpha_composite(floor)

    draw = ImageDraw.Draw(img, "RGBA")
    draw.line(pts + [pts[0]], fill=(15, 13, 23, 165), width=6)

    wall_color = tuple(int(wall_hex[i:i + 2], 16) for i in (0, 2, 4))
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
        half_th = WALL_VISUAL_THICKNESS / 2
        ux, uy = math.cos(angle), math.sin(angle)
        px, py = -uy, ux  # perpendicular

        def corner(sl, st):
            return (pos[0] + ux * half_len * sl + px * half_th * st,
                    pos[1] + uy * half_len * sl + py * half_th * st)

        lower_st = max((-1, 1), key=lambda st: (corner(-1, st)[1] + corner(1, st)[1]) / 2)
        face_start, face_end = corner(-1, lower_st), corner(1, lower_st)
        depth_ratio = max(0.0, min(1.0,
            ((pos[1] - center[1]) / (PIT_RADIUS * PIT_VERTICAL_SCALE) + 1.0) * 0.5))
        visual_height = (WALL_VISUAL_HEIGHT
            + (FRONT_WALL_VISUAL_HEIGHT - WALL_VISUAL_HEIGHT) * depth_ratio)
        face_color = tuple(int(c * (0.72 if mid[1] > center[1] else 0.87))
                           for c in wall_color)
        draw.polygon([face_start, face_end,
                      (face_end[0], face_end[1] - visual_height),
                      (face_start[0], face_start[1] - visual_height)],
                     fill=face_color)
        seam_count = max(1, int((half_len * 2) // 64))
        for seam_index in range(1, seam_count + 1):
            amount = seam_index / (seam_count + 1)
            seam_x = face_start[0] + (face_end[0] - face_start[0]) * amount
            seam_y = face_start[1] + (face_end[1] - face_start[1]) * amount
            draw.line([(seam_x, seam_y), (seam_x, seam_y - visual_height)],
                      fill=(30, 20, 14, 120), width=2)
        draw.polygon([(x, y - visual_height) for x, y in
                      [corner(-1, -1), corner(1, -1), corner(1, 1), corner(-1, 1)]],
                     fill=lighten(wall_color, 0.10))
        # Lit cap on whichever side faces the pit (matches Arena.gd).
        inward = (center[0] - pos[0], center[1] - pos[1])
        inward_local_y = inward[0] * math.sin(-angle) + inward[1] * math.cos(-angle)
        inward_sign = 1 if inward_local_y > 0 else -1
        cap_outer = half_th * inward_sign
        cap_inner = cap_outer - 3.0 * inward_sign

        def cap_corner(sl, dist):
            return (pos[0] + ux * half_len * sl + px * dist,
                    pos[1] + uy * half_len * sl + py * dist)

        draw.polygon([(x, y - visual_height) for x, y in
                      [cap_corner(-1, cap_inner), cap_corner(1, cap_inner),
                       cap_corner(1, cap_outer), cap_corner(-1, cap_outer)]],
                     fill=lighten(wall_color, 0.35))

    # Roster: player at the bottom slot, CPUs evenly around the ring.
    total = cpu_count + 1
    spawn_r = PIT_RADIUS * 0.80
    sheets = [Image.open(os.path.join(SPRITE_DIR, "character_gold.png"))]
    for i in range(cpu_count):
        sheets.append(Image.open(
            os.path.join(SPRITE_DIR, f"{TEAM_SHEETS[i % len(TEAM_SHEETS)]}.png")))

    for i, sheet in enumerate(sheets):
        angle = math.pi / 2 + math.tau * i / total
        world_y = math.sin(angle) * spawn_r
        width_scale = 1.0 + (world_y / PIT_RADIUS) * PIT_PERSPECTIVE_TAPER
        node = (center[0] + math.cos(angle) * spawn_r * width_scale,
                center[1] + world_y * PIT_VERTICAL_SCALE)
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
        frame = frame.resize((int(FRAME_W * FIGHTER_SCALE),
                              int(FRAME_H * FIGHTER_SCALE)), Image.NEAREST)
        # Sprite node sits at (0, -45) with scale 2.4 in the live scene.
        img.alpha_composite(frame, (int(node[0]) - frame.width // 2,
                                    int(node[1]) - 45 - frame.height // 2))

    ball = Image.open(os.path.join(SPRITE_DIR, "ball.png"))
    ball = ball.resize((ball.width * GROUND_SCALE, ball.height * GROUND_SCALE), Image.NEAREST)
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
