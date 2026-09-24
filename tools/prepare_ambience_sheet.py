"""Turn a generated horizontal pose strip into a deterministic game sprite sheet.

Image generation may return either real alpha or a baked pale checkerboard.  Each
source cell is isolated independently, then all poses are scaled by one common
factor and registered to a fixed-size transparent cell.  This prevents animated
actors from changing size or drifting as their frame advances.
"""
from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image

from prepare_ambience_sprite import largest_subject


def keyed_subject_mask(rgb: Image.Image) -> Image.Image:
	"""Reject generated gray checker texture while retaining outlined artwork."""
	pixels = rgb.load()
	width, height = rgb.size
	background = bytearray(width * height)
	for y in range(height):
		for x in range(width):
			red, green, blue = pixels[x, y]
			brightness = (red * 299 + green * 587 + blue * 114) / 1000
			saturation = max(red, green, blue) - min(red, green, blue)
			# The baked transparency preview is neutral gray.  Dark outlines and
			# genuinely colored sprite pixels become the connected foreground seed.
			if saturation <= 24 and brightness >= 130:
				background[y * width + x] = 1
	mask_data = largest_subject(rgb, background)

	# Restore pale details enclosed by the colored/dark outline (white throat,
	# collar hairs, eye highlights) without restoring exterior checker tiles.
	exterior_zero = bytearray(width * height)
	queue: deque[tuple[int, int]] = deque()
	def offer(x: int, y: int) -> None:
		index = y * width + x
		if not mask_data[index] and not exterior_zero[index]:
			exterior_zero[index] = 1
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
	for index in range(width * height):
		if not exterior_zero[index]:
			mask_data[index] = 255
	return Image.frombytes("L", rgb.size, bytes(mask_data))


def subject(cell: Image.Image) -> Image.Image:
	cell = cell.convert("RGBA")
	alpha = cell.getchannel("A")
	if alpha.getextrema()[0] < 250:
		# Generated alpha can still contain stray detached flecks. Keep only the
		# main connected sprite, just as the checkerboard-keyed path does.
		background = bytearray(1 if value <= 8 else 0 for value in alpha.getdata())
		mask = Image.frombytes("L", cell.size,
			bytes(largest_subject(cell.convert("RGB"), background)))
	else:
		rgb = cell.convert("RGB")
		mask = keyed_subject_mask(rgb)
	bounds = mask.getbbox()
	if bounds is None:
		raise RuntimeError("No sprite subject found in generated frame")
	cell.putalpha(mask)
	return cell.crop(bounds)


def prepare(source: Path, destination: Path, frame_count: int,
		cell_size: tuple[int, int], ground_aligned: bool) -> None:
	image = Image.open(source).convert("RGBA")
	frames: list[Image.Image] = []
	for index in range(frame_count):
		left = round(index * image.width / frame_count)
		right = round((index + 1) * image.width / frame_count)
		frames.append(subject(image.crop((left, 0, right, image.height))))

	cell_width, cell_height = cell_size
	max_width = max(frame.width for frame in frames)
	max_height = max(frame.height for frame in frames)
	scale = min((cell_width - 4) / max_width, (cell_height - 4) / max_height)
	output = Image.new("RGBA", (cell_width * frame_count, cell_height), (0, 0, 0, 0))
	for index, frame in enumerate(frames):
		size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
		frame = frame.resize(size, Image.Resampling.LANCZOS)
		x = index * cell_width + (cell_width - size[0]) // 2
		y = cell_height - size[1] - 2 if ground_aligned else (cell_height - size[1]) // 2
		output.alpha_composite(frame, (x, y))

	destination.parent.mkdir(parents=True, exist_ok=True)
	output.save(destination, optimize=True)
	print(f"Prepared {destination} ({frame_count} frames, {cell_width}x{cell_height} each)")


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("source", type=Path)
	parser.add_argument("destination", type=Path)
	parser.add_argument("width", type=int)
	parser.add_argument("height", type=int)
	parser.add_argument("--frames", type=int, default=4)
	parser.add_argument("--center", action="store_true")
	args = parser.parse_args()
	prepare(args.source, args.destination, args.frames, (args.width, args.height), not args.center)


if __name__ == "__main__":
	main()
