"""Darken gear to wooden-button brown and clear the center hole."""
from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/sprites/settings_gear_button.png"
OUT = SRC

# Target palette sampled from wooden_button_background.png
WOOD_DARK = np.array([98.0, 66.0, 40.0], dtype=np.float32)
WOOD_MID = np.array([155.0, 108.0, 70.0], dtype=np.float32)
WOOD_LIGHT = np.array([198.0, 155.0, 108.0], dtype=np.float32)
OUTLINE_LUMA_MAX = 55.0


def luma(rgb: np.ndarray) -> np.ndarray:
	return (
		0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
	).astype(np.float32)


def is_hole_pixel(rgb: np.ndarray, alpha: int) -> bool:
	if alpha < 10:
		return False
	r, g, b = (int(v) for v in rgb)
	mn = min(r, g, b)
	mx = max(r, g, b)
	# Near-white / light-gray fill left in the gear center
	return mn >= 195 and (mx - mn) < 45


def flood_center_hole(arr: np.ndarray) -> np.ndarray:
	height, width = arr.shape[:2]
	hole = np.zeros((height, width), dtype=bool)
	queue: deque[tuple[int, int]] = deque()
	cx, cy = width // 2, height // 2

	def try_seed(y: int, x: int) -> None:
		if hole[y, x]:
			return
		if is_hole_pixel(arr[y, x, :3], int(arr[y, x, 3])):
			hole[y, x] = True
			queue.append((y, x))

	# Seed a small disk at the geometric center
	for dy in range(-48, 49):
		for dx in range(-48, 49):
			if dx * dx + dy * dy > 48 * 48:
				continue
			y, x = cy + dy, cx + dx
			if 0 <= y < height and 0 <= x < width:
				try_seed(y, x)

	while queue:
		y, x = queue.popleft()
		for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
			ny, nx = y + dy, x + dx
			if 0 <= ny < height and 0 <= nx < width and not hole[ny, nx]:
				if is_hole_pixel(arr[ny, nx, :3], int(arr[ny, nx, 3])):
					hole[ny, nx] = True
					queue.append((ny, nx))
	return hole


def recolor_wood(arr: np.ndarray, body_mask: np.ndarray) -> np.ndarray:
	out = arr.copy()
	if not body_mask.any():
		return out

	rgb = arr[:, :, :3].astype(np.float32)
	gray = luma(rgb)
	body_gray = gray[body_mask]
	g_min = float(np.percentile(body_gray, 5))
	g_max = float(np.percentile(body_gray, 95))
	span = max(1.0, g_max - g_min)

	ys, xs = np.where(body_mask)
	for y, x in zip(ys, xs):
		g = float(gray[y, x])
		# Preserve thick black outline
		if g <= OUTLINE_LUMA_MAX:
			out[y, x, 0] = min(out[y, x, 0], 28)
			out[y, x, 1] = min(out[y, x, 1], 22)
			out[y, x, 2] = min(out[y, x, 2], 16)
			continue
		t = np.clip((g - g_min) / span, 0.0, 1.0)
		# Bias midtones toward mid wood so overall reads darker/browner
		t = float(t ** 1.15)
		if t < 0.5:
			u = t / 0.5
			color = WOOD_DARK * (1.0 - u) + WOOD_MID * u
		else:
			u = (t - 0.5) / 0.5
			color = WOOD_MID * (1.0 - u) + WOOD_LIGHT * u
		out[y, x, 0] = int(np.clip(color[0], 0, 255))
		out[y, x, 1] = int(np.clip(color[1], 0, 255))
		out[y, x, 2] = int(np.clip(color[2], 0, 255))
	return out


def main() -> int:
	arr = np.array(Image.open(SRC).convert("RGBA"))
	hole = flood_center_hole(arr)
	opaque = arr[:, :, 3] > 10
	body = opaque & ~hole

	arr = recolor_wood(arr, body)
	arr[hole, 3] = 0
	# Soften hole edge slightly (avoid harsh white ring)
	# Any remaining near-white on body near hole becomes transparent
	for y in range(arr.shape[0]):
		for x in range(arr.shape[1]):
			if arr[y, x, 3] < 10:
				continue
			if is_hole_pixel(arr[y, x, :3], int(arr[y, x, 3])):
				arr[y, x, 3] = 0

	Image.fromarray(arr, "RGBA").save(OUT)
	h, w = arr.shape[:2]
	print(
		f"Saved {OUT.relative_to(ROOT)} hole={int(hole.sum())} "
		f"center={tuple(arr[h // 2, w // 2])} "
		f"body_mean={arr[body][:, :3].mean(axis=0) if body.any() else None}"
	)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
