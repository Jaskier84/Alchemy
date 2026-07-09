"""Prepare settings gear button PNG with exterior transparency."""
from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/sprites/settings_gear_button.png"


def is_bg(rgb_px: tuple[int, int, int]) -> bool:
	r, g, b = (int(v) for v in rgb_px)
	mx, mn = max(r, g, b), min(r, g, b)
	# Light gray / white background
	if mx - mn < 35 and mn >= 200:
		return True
	if mx - mn < 20 and mn >= 160:
		return True
	return False


def flood_exterior(rgb: np.ndarray) -> np.ndarray:
	height, width = rgb.shape[:2]
	exterior = np.zeros((height, width), dtype=bool)
	queue: deque[tuple[int, int]] = deque()

	def seed(y: int, x: int) -> None:
		if not exterior[y, x] and is_bg(tuple(rgb[y, x])):
			exterior[y, x] = True
			queue.append((y, x))

	for x in range(width):
		seed(0, x)
		seed(height - 1, x)
	for y in range(height):
		seed(y, 0)
		seed(y, width - 1)

	while queue:
		y, x = queue.popleft()
		for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
			ny, nx = y + dy, x + dx
			if (
				0 <= ny < height
				and 0 <= nx < width
				and not exterior[ny, nx]
				and is_bg(tuple(rgb[ny, nx]))
			):
				exterior[ny, nx] = True
				queue.append((ny, nx))
	return exterior


def prepare(src: Path, out: Path) -> None:
	image = Image.open(src).convert("RGBA")
	arr = np.array(image)
	rgb = arr[:, :, :3]
	exterior = flood_exterior(rgb)
	alpha = np.where(exterior, 0, 255).astype(np.uint8)

	ys, xs = np.where(~exterior)
	if ys.size == 0:
		raise RuntimeError("No opaque content found after background removal")

	pad = 24
	height, width = rgb.shape[:2]
	y0 = max(0, int(ys.min()) - pad)
	y1 = min(height, int(ys.max()) + pad + 1)
	x0 = max(0, int(xs.min()) - pad)
	x1 = min(width, int(xs.max()) + pad + 1)

	out_arr = np.dstack([rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1]])
	out_im = Image.fromarray(out_arr, "RGBA").resize((512, 512), Image.Resampling.LANCZOS)
	out.parent.mkdir(parents=True, exist_ok=True)
	out_im.save(out)

	alpha_out = np.array(out_im)[:, :, 3]
	print(
		f"Saved {out.relative_to(ROOT)} size={out_im.size} "
		f"transparent%={int((alpha_out == 0).mean() * 100)} "
		f"corner={out_im.getpixel((0, 0))}"
	)


def main() -> int:
	if len(sys.argv) < 2:
		print("Usage: prepare_settings_gear_button.py <source_image>")
		return 1
	prepare(Path(sys.argv[1]), OUT)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
