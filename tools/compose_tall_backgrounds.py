"""Build tall 4:3 backgrounds by keeping the original 16:9 center unscaled.

Top/bottom bands are filled from the existing tall outpaint (cropped edges),
or by reflecting edge pixels if needed — the original center frame is copied
pixel-for-pixel so UI alignment (cauldron, etc.) stays correct.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
W, H16, H_TALL = 1024, 576, 768
Y0 = (H_TALL - H16) // 2  # 96


def compose(original: Path, tall_outpaint: Path, dest: Path, fmt: str) -> None:
	src = Image.open(original).convert("RGB")
	if src.size != (W, H16):
		src = src.resize((W, H16), Image.Resampling.LANCZOS)

	# Prefer outpaint for the extra bands (already generated).
	if tall_outpaint.exists():
		tall = Image.open(tall_outpaint).convert("RGB")
		if tall.size != (W, H_TALL):
			tall = tall.resize((W, H_TALL), Image.Resampling.LANCZOS)
	else:
		tall = Image.new("RGB", (W, H_TALL), (0, 0, 0))
		# Reflect edge strips as a fallback.
		top = src.crop((0, 0, W, Y0)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
		bot = src.crop((0, H16 - Y0, W, H16)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
		tall.paste(top, (0, 0))
		tall.paste(bot, (0, Y0 + H16))

	# Force original 16:9 frame into the vertical center — no stretch of gameplay art.
	tall.paste(src, (0, Y0))
	dest.parent.mkdir(parents=True, exist_ok=True)
	if fmt == "PNG":
		tall.save(dest, "PNG", optimize=True)
	else:
		tall.save(dest, "JPEG", quality=92, optimize=True)
	print(f"composed {dest.relative_to(ROOT)} center={W}x{H16} @ y={Y0}")


def main() -> int:
	jobs = [
		(
			ROOT / "assets/main_menu/main_menu_background.jpg",
			ROOT / "assets/main_menu/main_menu_background_tall.jpg",
			ROOT / "assets/main_menu/main_menu_background_tall.jpg",
			"JPEG",
		),
		(
			ROOT / "assets/brew/brew_background.png",
			ROOT / "assets/brew/brew_background_tall.png",
			ROOT / "assets/brew/brew_background_tall.png",
			"PNG",
		),
		(
			ROOT / "assets/shop/shop_background.jpg",
			ROOT / "assets/shop/shop_background_tall.jpg",
			ROOT / "assets/shop/shop_background_tall.jpg",
			"JPEG",
		),
		(
			ROOT / "assets/run_prep/run_prep_background.jpg",
			ROOT / "assets/run_prep/run_prep_background_tall.jpg",
			ROOT / "assets/run_prep/run_prep_background_tall.jpg",
			"JPEG",
		),
	]
	for original, tall_src, dest, fmt in jobs:
		if not original.exists():
			print("missing original", original)
			return 1
		compose(original, tall_src, dest, fmt)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
