#!/usr/bin/env python3
"""UltraOS artifact generator (PIL).

Generates, deterministically and idempotently (files are only rewritten when
their bytes change):

  1. src/playbook/playbook.png          - 256x256 playbook icon shown in AME Wizard:
                                          dark background (#0B1220), bold "U" glyph
                                          filled with a violet -> cyan gradient
                                          (#7C3AED -> #06B6D4), rounded corners.
  2. src/playbook/Images/brave.png      - 128x128 rounded letter tile "B",
  3. src/playbook/Images/firefox.png    - 128x128 rounded letter tile "F",
  4. src/playbook/Images/librewolf.png  - 128x128 rounded letter tile "L",
                                          each with a brand-ish gradient.

These files are referenced by playbook.conf (<Icon>brave.png</Icon> ...), so they
must exist before packaging (scripts/build-playbook.sh). No network access and
no optional dependencies beyond Pillow. Falls back to geometric letter shapes
when no TrueType bold font can be found (DejaVu/Liberation ship on this box and
on GitHub ubuntu runners).
"""
from __future__ import annotations

import io
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
PB = ROOT / "src" / "playbook"
IMAGES = PB / "Images"

# Palette (locked by 01-architecture / T3-l tasking)
BG_TOP = (0x0B, 0x12, 0x20)
BG_BOTTOM = (0x0D, 0x15, 0x24)
GLYPH_TOP = (0x7C, 0x3A, 0xED)  # violet
GLYPH_BOTTOM = (0x06, 0xB6, 0xD4)  # cyan

BROWSER_TILES = {
    # name: (letter, gradient top, gradient bottom)
    "brave": ("B", (0xFB, 0x54, 0x2B), (0xD0, 0x39, 0x0F)),  # Brave orange
    "firefox": ("F", (0x05, 0x7D, 0xB6), (0xFF, 0x95, 0x00)),  # blue -> orange
    "librewolf": ("L", (0x05, 0x7D, 0xB6), (0x86, 0xD8, 0xFF)),  # blue -> ice
}

FONT_CANDIDATES = (
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
    "/usr/local/share/fonts/DejaVuSans-Bold.ttf",
)

_FONT_PATH: str | None = None


def _font_path() -> str | None:
    """Return the first existing bold TTF, or None (caller falls back to shapes)."""
    global _FONT_PATH
    if _FONT_PATH is None:
        _FONT_PATH = next((p for p in FONT_CANDIDATES if Path(p).exists()), "")
    return _FONT_PATH or None


def _vertical_gradient(size: tuple[int, int], top, bottom) -> Image.Image:
    """Smooth vertical RGB gradient via 1px column + bilinear resize."""
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        col.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return col.resize((w, h), Image.BILINEAR)


def _geo_letter(letter: str, size: int, thickness: int) -> Image.Image:
    """Geometric fallback glyph (no font available). White-on-black L mask."""
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    t = thickness
    if letter == "U":
        w, h = int(size * 0.58), int(size * 0.62)
        x0, y0 = (size - w) // 2, (size - h) // 2
        x1, y1 = x0 + w, y0 + h
        r = w // 2
        cy = y1 - r
        d.arc([x0, cy - r, x1, cy + r], 0, 180, fill=255, width=t)
        d.rounded_rectangle([x0, y0, x0 + t, cy + t // 2 + 1], radius=t // 2, fill=255)
        d.rounded_rectangle([x1 - t, y0, x1, cy + t // 2 + 1], radius=t // 2, fill=255)
    elif letter == "B":
        w, h = int(size * 0.52), int(size * 0.62)
        x0, y0 = (size - w) // 2, (size - h) // 2
        y1 = y0 + h
        d.rounded_rectangle([x0, y0, x0 + t, y1], radius=t // 2, fill=255)
        rb = (w - t) // 2
        d.arc([x0, y0, x0 + w, y0 + 2 * rb], -90, 90, fill=255, width=t)
        d.arc([x0, y1 - 2 * rb, x0 + w, y1], -90, 90, fill=255, width=t)
    elif letter == "F":
        w, h = int(size * 0.52), int(size * 0.62)
        x0, y0 = (size - w) // 2, (size - h) // 2
        y1 = y0 + h
        d.rounded_rectangle([x0, y0, x0 + t, y1], radius=t // 2, fill=255)
        d.rounded_rectangle([x0, y0, x0 + w, y0 + t], radius=t // 2, fill=255)
        d.rounded_rectangle([x0, (y0 + y1) // 2 - t // 2, x0 + int(w * 0.78), (y0 + y1) // 2 + t // 2], radius=t // 2, fill=255)
    else:  # "L" (and anything else: draw a plain bar)
        w, h = int(size * 0.52), int(size * 0.62)
        x0, y0 = (size - w) // 2, (size - h) // 2
        y1 = y0 + h
        d.rounded_rectangle([x0, y0, x0 + t, y1], radius=t // 2, fill=255)
        d.rounded_rectangle([x0, y1 - t, x0 + w, y1], radius=t // 2, fill=255)
    return mask


def letter_mask(letter: str, canvas: int, target_h: int) -> Image.Image:
    """Optically centered white-on-black mask of a bold capital letter."""
    from PIL import ImageFont

    path = _font_path()
    if path is None:
        return _geo_letter(letter, canvas, max(8, int(canvas * 0.16)))

    fsize = target_h
    font = ImageFont.truetype(path, fsize)
    probe = Image.new("L", (canvas, canvas), 0)
    ImageDraw.Draw(probe).text((canvas // 2, canvas // 2), letter, font=font, fill=255, anchor="mm")
    bbox = probe.getbbox()
    # scale font so the visual bbox height converges on target_h
    for _ in range(4):
        if not bbox:
            fsize = int(fsize * 1.5)
        else:
            bh = bbox[3] - bbox[1]
            if abs(bh - target_h) <= 2:
                break
            fsize = max(8, int(fsize * target_h / max(bh, 1)))
        font = ImageFont.truetype(path, fsize)
        probe = Image.new("L", (canvas, canvas), 0)
        ImageDraw.Draw(probe).text((canvas // 2, canvas // 2), letter, font=font, fill=255, anchor="mm")
        bbox = probe.getbbox()
    if not bbox:  # give up on the font, use shapes
        return _geo_letter(letter, canvas, max(8, int(canvas * 0.16)))
    # re-center on the visual bbox
    dx = canvas // 2 - (bbox[0] + bbox[2]) // 2
    dy = canvas // 2 - (bbox[1] + bbox[3]) // 2
    out = Image.new("L", (canvas, canvas), 0)
    ImageDraw.Draw(out).text((canvas // 2 + dx, canvas // 2 + dy), letter, font=font, fill=255, anchor="mm")
    return out


def make_playbook_icon() -> Image.Image:
    """256x256 app icon: dark rounded square + gradient 'U' glyph."""
    size = 256
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # background: subtle dark vertical gradient, clipped to a rounded square
    bg = _vertical_gradient((size, size), BG_TOP, BG_BOTTOM).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=58, fill=255)
    icon.paste(bg, (0, 0), mask)

    # glyph mask + soft shadow for depth
    glyph = letter_mask("U", size, target_h=150)
    shadow = glyph.filter(ImageFilter.GaussianBlur(5))
    icon.paste(Image.new("RGBA", (size, size), (0, 0, 0, 110)), (0, 3), shadow)

    # violet -> cyan gradient fill through the glyph
    grad = _vertical_gradient((size, size), GLYPH_TOP, GLYPH_BOTTOM).convert("RGBA")
    icon.paste(grad, (0, 0), glyph)

    # faint inner keyline for a modern finish
    d = ImageDraw.Draw(icon)
    d.rounded_rectangle([1, 1, size - 2, size - 2], radius=57, outline=(255, 255, 255, 20), width=2)
    return icon


def make_browser_tile(letter: str, top, bottom) -> Image.Image:
    """128x128 rounded letter tile with a brand-ish gradient background."""
    size = 128
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = _vertical_gradient((size, size), top, bottom).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=30, fill=255)
    tile.paste(grad, (0, 0), mask)

    glyph = letter_mask(letter, size, target_h=76)
    shadow = glyph.filter(ImageFilter.GaussianBlur(3))
    tile.paste(Image.new("RGBA", (size, size), (0, 0, 0, 90)), (0, 3), shadow)
    tile.paste(Image.new("RGBA", (size, size), (255, 255, 255, 255)), (0, 0), glyph)

    # subtle top-edge highlight
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle([1, 1, size - 2, size - 2], radius=29, outline=(255, 255, 255, 45), width=2)
    return tile


def write_if_changed(path: Path, img: Image.Image) -> str:
    """Write PNG only when content differs -> idempotent, mtimes stay stable."""
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    data = buf.getvalue()
    if path.exists() and path.read_bytes() == data:
        return "unchanged"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return "written"


def main() -> int:
    font = _font_path()
    print(f"Bold font: {font or 'none - using geometric fallback glyphs'}")

    results = [("src/playbook/playbook.png", write_if_changed(PB / "playbook.png", make_playbook_icon()))]
    for name, (letter, top, bottom) in BROWSER_TILES.items():
        results.append(
            (f"src/playbook/Images/{name}.png", write_if_changed(IMAGES / f"{name}.png", make_browser_tile(letter, top, bottom)))
        )

    for rel, status in results:
        print(f"  {status:10s} {rel}")

    # sanity: correct dimensions
    checks = [(PB / "playbook.png", (256, 256))] + [(IMAGES / f"{n}.png", (128, 128)) for n in BROWSER_TILES]
    bad = [str(p) for p, want in checks if p.exists() and Image.open(p).size != want]
    if bad:
        print(f"ERROR: wrong dimensions: {', '.join(bad)}", file=sys.stderr)
        return 1
    print("All artifacts generated and size-checked (playbook.png 256x256, tiles 128x128).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
