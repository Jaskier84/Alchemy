"""Copy session outpaints into assets as 1024x768 tall backgrounds."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SESSIONS = Path.home() / ".grok" / "sessions"

# Parallel generation order: brew, run_prep, shop, main_menu
MAP = {
	"6.jpg": ("assets/brew/brew_background_tall.png", "PNG"),
	"7.jpg": ("assets/run_prep/run_prep_background_tall.jpg", "JPEG"),
	"8.jpg": ("assets/shop/shop_background_tall.jpg", "JPEG"),
	"9.jpg": ("assets/main_menu/main_menu_background_tall.jpg", "JPEG"),
}


def find_session_images() -> Path:
	matches = sorted(
		SESSIONS.rglob("019f4442-dfa5-7220-a7b5-8f31dd95e475/images"),
		key=lambda p: p.stat().st_mtime,
		reverse=True,
	)
	if not matches:
		raise FileNotFoundError("Could not find session images folder")
	return matches[0]


def main() -> int:
	session = find_session_images()
	print("session", session)
	for src_name, (dst_rel, fmt) in MAP.items():
		src = session / src_name
		if not src.exists():
			print("missing", src)
			return 1
		im = Image.open(src).convert("RGB")
		im = im.resize((1024, 768), Image.Resampling.LANCZOS)
		dst = ROOT / dst_rel
		dst.parent.mkdir(parents=True, exist_ok=True)
		if fmt == "PNG":
			im.save(dst, "PNG", optimize=True)
		else:
			im.save(dst, "JPEG", quality=90, optimize=True)
		print(f"saved {dst_rel} {im.size}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
