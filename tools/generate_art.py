#!/usr/bin/env python3
"""Generates the game's original late-1980s street-sports pixel art.

Sprites are drawn from blocky primitives rather than hand-painted, so poses
and team colors are parameters instead of duplicated files -- palette swaps
are how the NES did team colors anyway. Re-run after editing:

    python3 tools/generate_art.py

Outputs (all committed, the game loads these directly):
    Assets/Sprites/character_<team>.png   8x3 sheet, 32x40 frames
    Assets/Sprites/ball.png
    Assets/Backgrounds/floor_<theme>.png    tileable pit floor
    Assets/Backgrounds/surround_<theme>.png tileable ground outside the pit
"""

import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITE_DIR = os.path.join(ROOT, "Assets", "Sprites")
BG_DIR = os.path.join(ROOT, "Assets", "Backgrounds")

FRAME_W, FRAME_H = 32, 44
COLS, ROWS = 8, 3

# Vertical budget for a frame, leaving a pixel of margin for the outline pass.
HEAD_TOP = 2
HEAD_BOTTOM = 19
TORSO_TOP = 21
TORSO_BOTTOM = 30
SHORTS_BOTTOM = 34
LEG_BOTTOM = 40
SHOE_BOTTOM = 42

OUTLINE = (26, 18, 32, 255)
SKIN = (240, 196, 148, 255)
SKIN_DARK = (198, 142, 96, 255)
HAIR = (74, 44, 20, 255)
HAIR_DARK = (48, 28, 12, 255)
SHORTS = (42, 42, 62, 255)
SHOE = (232, 232, 240, 255)
EYE_WHITE = (255, 255, 255, 255)
EYE_DARK = (30, 24, 40, 255)
MOUTH = (140, 50, 50, 255)

TEAMS = {
    "gold": ((242, 184, 48, 255), (184, 128, 26, 255), (74, 44, 20, 255)),
    "blue": ((74, 125, 201, 255), (44, 77, 128, 255), (36, 26, 18, 255)),
    "red": ((217, 72, 63, 255), (143, 42, 36, 255), (24, 18, 14, 255)),
    "green": ((74, 168, 90, 255), (44, 107, 56, 255), (96, 62, 24, 255)),
}

# Poses laid out per row: cols 0-3 are the walk cycle (0 and 2 are the
# neutral contact frames), then charge, slap, victory, out.
POSES = ["idle", "walk_a", "idle", "walk_b", "charge", "slap", "victory", "out"]
FACINGS = ["front", "side", "back"]


class Canvas:
    """Tiny pixel canvas; every helper takes inclusive pixel coordinates."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[(0, 0, 0, 0)] * w for _ in range(h)]

    def dot(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = color

    def rect(self, x0, y0, x1, y1, color):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.dot(x, y, color)

    def outline(self, color=OUTLINE):
        """Wrap the silhouette in a 1px border, NES-style."""
        edges = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.px[ny][nx][3]:
                        edges.append((x, y))
                        break
        for x, y in edges:
            self.dot(x, y, color)

    def to_image(self):
        img = Image.new("RGBA", (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                img.putpixel((x, y), self.px[y][x])
        return img


def draw_face(c, facing, expression, hair, dy=0):
    """Oversized head with a readable expression, per the PRD's art direction."""
    if facing == "side":
        hx0, hx1 = 8, 25
    else:
        hx0, hx1 = 7, 24
    hy0, hy1 = HEAD_TOP + dy, HEAD_BOTTOM + dy

    c.rect(hx0, hy0, hx1, hy1, SKIN)
    # Knock the corners off so the head reads as round, not a brick.
    for cx, cy in ((hx0, hy0), (hx1, hy0), (hx0, hy1), (hx1, hy1)):
        c.dot(cx, cy, (0, 0, 0, 0))
    c.rect(hx0 + 1, hy1, hx1 - 1, hy1, SKIN_DARK)  # jaw shading

    # Hair: cap on top, sideburns down the sides.
    c.rect(hx0, hy0, hx1, hy0 + 4, hair)
    c.rect(hx0, hy0 + 5, hx0 + 1, hy0 + 7, hair)
    c.rect(hx1 - 1, hy0 + 5, hx1, hy0 + 7, hair)
    for cx in (hx0, hx1):
        c.dot(cx, hy0, (0, 0, 0, 0))

    if facing == "back":
        c.rect(hx0, hy0, hx1, hy1 - 2, hair)
        c.rect(hx0 + 1, hy1 - 3, hx1 - 1, hy1 - 2, HAIR_DARK)
        for cx in (hx0, hx1):
            c.dot(cx, hy0, (0, 0, 0, 0))
        c.rect(hx0 + 4, hy1 - 1, hx1 - 4, hy1, SKIN_DARK)  # nape
        return

    eye_y = hy0 + 9
    if facing == "side":
        c.rect(hx1 - 4, hy0 + 1, hx1, hy0 + 6, hair)  # fringe over the brow
        c.dot(hx1 + 1, eye_y + 1, SKIN)  # nose bump
        c.dot(hx1 + 1, eye_y + 2, SKIN_DARK)
        c.rect(hx0 + 3, eye_y + 1, hx0 + 4, eye_y + 2, SKIN_DARK)  # ear
        eyes = [(hx1 - 5, eye_y)]
        mouth_x = hx1 - 6
    else:
        eyes = [(hx0 + 3, eye_y), (hx1 - 5, eye_y)]
        mouth_x = (hx0 + hx1) // 2 - 1

    for ex, ey in eyes:
        if expression == "dizzy":
            c.dot(ex, ey, EYE_DARK)
            c.dot(ex + 2, ey, EYE_DARK)
            c.dot(ex + 1, ey + 1, EYE_DARK)
            c.dot(ex, ey + 2, EYE_DARK)
            c.dot(ex + 2, ey + 2, EYE_DARK)
        elif expression == "happy":
            c.rect(ex, ey + 1, ex + 2, ey + 1, EYE_DARK)
            c.dot(ex + 1, ey, EYE_DARK)
        else:
            c.rect(ex, ey, ex + 2, ey + 2, EYE_WHITE)
            pupil_y = ey + 1 if expression != "focused" else ey
            c.rect(ex + 1, pupil_y, ex + 2, pupil_y + 1, EYE_DARK)
            if expression == "focused":
                c.rect(ex, ey - 2, ex + 2, ey - 2, HAIR_DARK)  # angry brow

    mouth_y = hy0 + 14
    if expression == "happy":
        c.rect(mouth_x - 1, mouth_y, mouth_x + 2, mouth_y + 1, MOUTH)
        c.rect(mouth_x, mouth_y - 1, mouth_x + 1, mouth_y - 1, MOUTH)
    elif expression == "dizzy":
        c.rect(mouth_x, mouth_y, mouth_x + 1, mouth_y + 1, MOUTH)
    elif expression == "focused":
        c.rect(mouth_x - 1, mouth_y, mouth_x + 2, mouth_y, MOUTH)
    else:
        c.rect(mouth_x, mouth_y, mouth_x + 1, mouth_y, MOUTH)


def draw_leg(c, x0, x1, top, bottom, shoe_dir=0):
    c.rect(x0, top, x1, bottom, SKIN)
    c.rect(x0, bottom - 1, x1, bottom, SKIN_DARK)
    # Sneaker sticks out a pixel in the direction of travel.
    sx0 = x0 - 1 if shoe_dir < 0 else x0
    sx1 = x1 + 1 if shoe_dir > 0 else x1
    c.rect(sx0, bottom + 1, sx1, bottom + 2, SHOE)


def draw_character(facing, pose, team):
    jersey, jersey_dark, hair = TEAMS[team]
    c = Canvas(FRAME_W, FRAME_H)

    expression = {"charge": "focused", "victory": "happy", "out": "dizzy"}.get(
        pose, "normal"
    )
    # One offset moves the entire figure, so nothing detaches: a knocked-out
    # fighter sags to the floor, a charging one crouches into the wind-up, and
    # walk frames bob.
    dy = {"out": 6, "charge": 2, "walk_a": -1, "walk_b": -1}.get(pose, 0)

    torso_x0, torso_x1 = 10, 21
    torso_y0, torso_y1 = TORSO_TOP + dy, TORSO_BOTTOM + dy
    shorts_y1 = SHORTS_BOTTOM + dy
    leg_top = shorts_y1 + 1
    leg_bottom = LEG_BOTTOM
    arm_y0 = torso_y0 + 1

    # Legs first, so the torso and shorts overlap their tops cleanly.
    if pose == "walk_a":
        draw_leg(c, 10, 13, leg_top, leg_bottom, shoe_dir=-1)
        draw_leg(c, 17, 20, leg_top, leg_bottom - 3)
    elif pose == "walk_b":
        draw_leg(c, 11, 14, leg_top, leg_bottom - 3)
        draw_leg(c, 18, 21, leg_top, leg_bottom, shoe_dir=1)
    elif pose == "out":
        # Splayed flat on the floor.
        draw_leg(c, 5, 12, leg_top, leg_bottom - 3, shoe_dir=-1)
        draw_leg(c, 19, 26, leg_top, leg_bottom - 3, shoe_dir=1)
    else:
        draw_leg(c, 11, 14, leg_top, leg_bottom)
        draw_leg(c, 17, 20, leg_top, leg_bottom)

    c.rect(torso_x0, torso_y0, torso_x1, torso_y1, jersey)
    c.rect(torso_x0, torso_y1 - 1, torso_x1, torso_y1, jersey_dark)
    c.rect(torso_x0, torso_y1 + 1, torso_x1, shorts_y1, SHORTS)

    # Every palette is an individual outfit, not a team uniform. Bold,
    # asymmetric street-sports details make fighters identifiable in motion.
    if team == "gold":
        c.rect(torso_x0 + 2, torso_y0 + 3, torso_x0 + 3, torso_y1 - 2, (255, 226, 105, 255))
    elif team == "blue":
        c.rect(torso_x0, torso_y0 + 4, torso_x1, torso_y0 + 5, (118, 183, 238, 255))
    elif team == "red":
        for stripe in range(3):
            c.dot(torso_x0 + 3 + stripe, torso_y0 + 3 + stripe, (255, 154, 105, 255))
            c.dot(torso_x0 + 7 + stripe, torso_y0 + 3 + stripe, (255, 154, 105, 255))
    elif team == "green":
        c.rect(torso_x0 + 5, torso_y0 + 2, torso_x0 + 6, torso_y1 - 2, (151, 220, 112, 255))
    if facing != "back":
        c.rect(torso_x0 + 4, torso_y0, torso_x0 + 7, torso_y0 + 1, jersey_dark)  # collar

    # Arms: the slap throws one forward, the charge cocks both back, the
    # victory pose throws both up.
    if pose == "slap":
        if facing == "side":
            c.rect(22, arm_y0 + 1, 29, arm_y0 + 4, SKIN)
            c.rect(7, arm_y0 + 3, 9, arm_y0 + 7, SKIN)
        elif facing == "back":
            c.rect(3, arm_y0, 9, arm_y0 + 3, SKIN)
            c.rect(22, arm_y0, 28, arm_y0 + 3, SKIN)
        else:
            c.rect(22, arm_y0 + 2, 29, arm_y0 + 5, SKIN)
            c.rect(6, arm_y0 + 3, 9, arm_y0 + 7, SKIN)
    elif pose == "charge":
        c.rect(4, arm_y0 + 4, 9, arm_y0 + 7, SKIN)
        c.rect(22, arm_y0 + 4, 27, arm_y0 + 7, SKIN)
    elif pose == "victory":
        c.rect(6, arm_y0 - 7, 9, arm_y0 + 3, SKIN)
        c.rect(22, arm_y0 - 7, 25, arm_y0 + 3, SKIN)
    elif pose == "out":
        c.rect(3, arm_y0 + 5, 9, arm_y0 + 7, SKIN)
        c.rect(22, arm_y0 + 5, 28, arm_y0 + 7, SKIN)
    else:
        swing = 2 if pose == "walk_a" else (-2 if pose == "walk_b" else 0)
        c.rect(7, arm_y0 + swing, 9, arm_y0 + 7 + swing, SKIN)
        c.rect(22, arm_y0 - swing, 24, arm_y0 + 7 - swing, SKIN)

    draw_face(c, facing, expression, hair, dy)

    if pose == "out":  # dizzy stars orbiting the head
        for sx, sy in ((3, 6), (27, 4), (9, 1)):
            for px, py in ((sx, sy), (sx - 1, sy + 1), (sx + 1, sy + 1), (sx, sy + 2)):
                c.dot(px, py, (255, 240, 120, 255))

    c.outline()

    # Contact shadow, added after the outline pass so it doesn't get traced.
    shadow = (0, 0, 0, 70)
    for x in range(9, 23):
        inset = 2 if x in (9, 10, 21, 22) else 0
        for y in range(SHOE_BOTTOM - 1 + inset, SHOE_BOTTOM + 1):
            if not c.px[y][x][3]:
                c.dot(x, y, shadow)
    return c.to_image()


def build_character_sheet(team):
    sheet = Image.new("RGBA", (FRAME_W * COLS, FRAME_H * ROWS))
    for row, facing in enumerate(FACINGS):
        for col, pose in enumerate(POSES):
            sheet.paste(draw_character(facing, pose, team), (col * FRAME_W, row * FRAME_H))
    return sheet


def build_ball():
    """16px canvas. Everything renders at 2x in-game, so this is a 32px ball
    on screen against a 64px-wide character -- roughly gaga proportions."""
    size, center, radius = 16, 7.5, 6.6
    c = Canvas(size, size)
    body = (242, 163, 60, 255)
    shade = (196, 116, 30, 255)
    light = (255, 217, 160, 255)
    for y in range(size):
        for x in range(size):
            dx, dy = x - center, y - center
            d = (dx * dx + dy * dy) ** 0.5
            if d <= radius:
                c.dot(x, y, shade if d > radius * 0.72 and (dx + dy) > 2 else body)
    c.rect(4, 3, 5, 4, light)  # specular highlight
    c.dot(3, 5, light)
    # Seam, so spin reads even without rotation frames.
    for y in range(2, 14):
        offset = 3.0 * ((1 - ((y - center) / (radius + 0.5)) ** 2) ** 0.5)
        c.dot(int(center + offset), y, shade)
    c.outline()
    return c.to_image()


def _noise_tile(size, base, specks, seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            img.putpixel((x, y), rng.choice(specks) if rng.random() < 0.22 else base)
    return img


def build_floor(theme):
    """Tileable 32x32 pit floor. Tiles seamlessly: no edge-only detail."""
    size = 32
    if theme == "wood":
        img = Image.new("RGBA", (size, size), (176, 124, 74, 255))
        rng = random.Random(11)
        for y in range(size):
            for x in range(size):
                if y % 8 in (0, 7):
                    img.putpixel((x, y), (140, 94, 52, 255))
                elif rng.random() < 0.12:
                    img.putpixel((x, y), (188, 138, 88, 255))
        for y in range(size):  # plank ends, staggered per row
            pass
        for row, x in ((0, 5), (8, 21), (16, 13), (24, 29)):
            for y in range(row, row + 8):
                img.putpixel((x % size, y), (140, 94, 52, 255))
    elif theme == "dirt":
        img = _noise_tile(size, (150, 112, 74, 255),
                          [(134, 98, 62, 255), (166, 128, 88, 255), (120, 88, 56, 255)], 3)
    elif theme == "sand":
        img = _noise_tile(size, (222, 194, 132, 255),
                          [(206, 176, 116, 255), (236, 210, 152, 255)], 7)
    elif theme == "blacktop":
        img = _noise_tile(size, (76, 76, 88, 255),
                          [(66, 66, 78, 255), (88, 88, 100, 255)], 5)
    elif theme == "steel":
        img = Image.new("RGBA", (size, size), (118, 124, 138, 255))
        for y in range(size):
            for x in range(size):
                if (x + y) % 16 in (0, 1):
                    img.putpixel((x, y), (142, 148, 162, 255))
                elif (x - y) % 16 in (0, 1):
                    img.putpixel((x, y), (96, 102, 116, 255))
        for cx in (7, 23):  # rivets
            for cy in (7, 23):
                for dx in range(-1, 2):
                    for dy in range(-1, 2):
                        img.putpixel(((cx + dx) % size, (cy + dy) % size), (156, 162, 176, 255))
    else:  # court -- the championship pit
        img = Image.new("RGBA", (size, size), (198, 146, 88, 255))
        rng = random.Random(13)
        for y in range(size):
            for x in range(size):
                if y % 16 in (0,) or x % 16 in (0,):
                    img.putpixel((x, y), (176, 126, 72, 255))
                elif rng.random() < 0.08:
                    img.putpixel((x, y), (210, 160, 100, 255))
    return img


def build_surround(theme):
    """Tileable 32x32 ground outside the pit walls."""
    size = 32
    if theme == "grass":
        img = _noise_tile(size, (74, 132, 66, 255),
                          [(62, 116, 56, 255), (88, 148, 76, 255), (54, 104, 50, 255)], 2)
    elif theme == "gym":
        # Deliberately darker than any pit floor so the arena edge reads at a
        # glance -- contrast here is gameplay readability, not decoration.
        img = Image.new("RGBA", (size, size), (98, 66, 38, 255))
        rng = random.Random(21)
        for y in range(size):
            for x in range(size):
                if y % 16 in (0, 15):
                    img.putpixel((x, y), (78, 50, 28, 255))
                elif rng.random() < 0.10:
                    img.putpixel((x, y), (110, 76, 46, 255))
        for y in range(size):
            img.putpixel((6, y), (78, 50, 28, 255))
    elif theme == "desert":
        img = _noise_tile(size, (198, 160, 104, 255),
                          [(182, 144, 92, 255), (212, 176, 120, 255)], 9)
    elif theme == "city":
        img = Image.new("RGBA", (size, size), (104, 104, 116, 255))
        for y in range(size):
            for x in range(size):
                if x % 16 == 0 or y % 16 == 0:
                    img.putpixel((x, y), (84, 84, 96, 255))
    elif theme == "industrial":
        img = _noise_tile(size, (72, 74, 84, 255),
                          [(62, 64, 74, 255), (86, 88, 98, 255)], 4)
    else:  # arena crowd-dark surround
        img = _noise_tile(size, (46, 40, 66, 255),
                          [(38, 34, 58, 255), (58, 50, 82, 255)], 6)
    return img


def build_contact_sheet(scale=5):
    """Dev-only preview: every team sheet stacked and upscaled for eyeballing."""
    teams = list(TEAMS)
    w = FRAME_W * COLS
    h = FRAME_H * ROWS * len(teams)
    sheet = Image.new("RGBA", (w, h), (24, 24, 34, 255))
    for i, team in enumerate(teams):
        sheet.paste(build_character_sheet(team), (0, i * FRAME_H * ROWS), build_character_sheet(team))
    return sheet.resize((w * scale, h * scale), Image.NEAREST)


FLOOR_THEMES = ["wood", "dirt", "sand", "blacktop", "steel", "court"]
SURROUND_THEMES = ["gym", "grass", "desert", "city", "industrial", "arena"]


def main():
    os.makedirs(SPRITE_DIR, exist_ok=True)
    os.makedirs(BG_DIR, exist_ok=True)

    for team in TEAMS:
        build_character_sheet(team).save(os.path.join(SPRITE_DIR, f"character_{team}.png"))
    build_ball().save(os.path.join(SPRITE_DIR, "ball.png"))
    for theme in FLOOR_THEMES:
        build_floor(theme).save(os.path.join(BG_DIR, f"floor_{theme}.png"))
    for theme in SURROUND_THEMES:
        build_surround(theme).save(os.path.join(BG_DIR, f"surround_{theme}.png"))
    print("art written to Assets/Sprites and Assets/Backgrounds")


if __name__ == "__main__":
    main()
