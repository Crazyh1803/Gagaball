"""Extract a generated pixel sprite from a baked checkerboard preview.

The generated masters sometimes render transparency as pale gray checks.
This flood-fills only pale, low-saturation pixels connected to the image edge,
keeps the largest outlined subject, and downsamples it onto a transparent,
ground-aligned game canvas.
"""
from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def is_background(pixel: tuple[int, int, int]) -> bool:
    red, green, blue = pixel
    bright = (red * 299 + green * 587 + blue * 114) / 1000
    saturation = max(pixel) - min(pixel)
    return bright > 148 and saturation < 34


def exterior_background(image: Image.Image) -> bytearray:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    exterior = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def offer(x: int, y: int) -> None:
        index = y * width + x
        if not exterior[index] and is_background(pixels[x, y]):
            exterior[index] = 1
            queue.append((x, y))

    for x in range(width):
        offer(x, 0)
        offer(x, height - 1)
    for y in range(height):
        offer(0, y)
        offer(width - 1, y)
    while queue:
        x, y = queue.popleft()
        if x: offer(x - 1, y)
        if x + 1 < width: offer(x + 1, y)
        if y: offer(x, y - 1)
        if y + 1 < height: offer(x, y + 1)
    return exterior


def largest_subject(image: Image.Image, exterior: bytearray) -> bytearray:
    width, height = image.size
    seen = bytearray(width * height)
    largest: list[int] = []
    for start in range(width * height):
        if exterior[start] or seen[start]:
            continue
        seen[start] = 1
        component: list[int] = []
        queue = deque([start])
        while queue:
            index = queue.popleft()
            component.append(index)
            x, y = index % width, index // width
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    neighbor = ny * width + nx
                    if not exterior[neighbor] and not seen[neighbor]:
                        seen[neighbor] = 1
                        queue.append(neighbor)
        if len(component) > len(largest):
            largest = component
    mask = bytearray(width * height)
    for index in largest:
        mask[index] = 255
    return mask


def prepare(source: Path, destination: Path, canvas: tuple[int, int]) -> None:
    image = Image.open(source).convert("RGB")
    exterior = exterior_background(image)
    mask_data = largest_subject(image, exterior)
    mask = Image.frombytes("L", image.size, bytes(mask_data))
    bounds = mask.getbbox()
    if bounds is None:
        raise RuntimeError(f"No sprite subject found in {source}")
    rgba = image.convert("RGBA")
    rgba.putalpha(mask)
    sprite = rgba.crop(bounds)

    canvas_width, canvas_height = canvas
    scale = min((canvas_width - 4) / sprite.width, (canvas_height - 4) / sprite.height)
    size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
    sprite = sprite.resize(size, Image.Resampling.LANCZOS)
    output = Image.new("RGBA", canvas, (0, 0, 0, 0))
    output.alpha_composite(sprite, ((canvas_width - size[0]) // 2, canvas_height - size[1] - 2))
    destination.parent.mkdir(parents=True, exist_ok=True)
    output.save(destination, optimize=True)
    print(f"Prepared {destination} ({canvas_width}x{canvas_height})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("width", type=int)
    parser.add_argument("height", type=int)
    args = parser.parse_args()
    prepare(args.source, args.destination, (args.width, args.height))


if __name__ == "__main__":
    main()
