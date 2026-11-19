"""Create 16:9 and 4:3 pastel marketing covers for 汐."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import cv2
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "promo" / "out" / "covers"
ICON = ROOT / "app.png"
PORTRAIT = ROOT / "promo" / "cover-assets" / "ushio-portrait.png"
TYPE_SOURCE = ROOT / "sample" / "cover.png"
SCALE = 2

LAYOUTS = {
    "16:9": {
        "size": (1920, 1080),
        "portrait": (1010, 205, 910),
        "icon": (124, 74, 72),
        "brand": (216, 84),
        "category": (220, 152, 430),
        "headline_lines": (
            ((120, 288), 850, (810, 1030, 1444, 1200)),
            ((120, 556), 640, (1445, 1085, 1870, 1200)),
            ((120, 828), 620, (1871, 1085, 2285, 1200)),
        ),
        "foreground_limit": 985,
    },
    "4:3": {
        "size": (1600, 1200),
        "portrait": (790, 430, 810),
        "icon": (108, 88, 72),
        "brand": (200, 98),
        "category": (204, 166, 430),
        "headline_lines": (
            ((104, 366), 680, (810, 1030, 1444, 1200)),
            ((104, 696), 530, (1445, 1085, 1870, 1200)),
            ((104, 1026), 520, (1871, 1085, 2285, 1200)),
        ),
        "foreground_limit": 835,
    },
}

TYPE_CROPS = {
    "brand": (825, 520, 1100, 800),
    "category": (1185, 875, 1940, 960),
}
HEADLINE = "以个性化为“卖点”的MD编辑器"
HEADLINE_LINES = ("以个性化为", "“卖点”的", "MD编辑器")


def units(value: int | float) -> int:
    return round(value * SCALE)


def soft_background(width: int, height: int) -> Image.Image:
    x = np.linspace(-1, 1, width, dtype=np.float32)[None, :]
    y = np.linspace(-1, 1, height, dtype=np.float32)[:, None]
    light = 249.0 - 3.8 * (x * x + y * y) - 0.7 * y
    pink = np.exp(-((x - 0.35) ** 2 / 0.55 + (y + 0.65) ** 2 / 1.2))
    lavender = np.exp(-((x - 0.72) ** 2 / 0.8 + (y - 0.25) ** 2 / 1.1))
    rgb = np.stack((light + 5 * pink, light - 2 * pink, light + 6 * lavender), axis=-1)
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def load_character(size: int) -> Image.Image:
    source = Image.open(PORTRAIT).convert("RGB")
    rgb = np.asarray(source, dtype=np.float32)
    near_white = np.min(rgb, axis=2) >= 245
    labels = cv2.connectedComponents(near_white.astype(np.uint8), connectivity=8)[1]
    border_labels = set(labels[0, :]) | set(labels[-1, :]) | set(labels[:, 0]) | set(labels[:, -1])
    background_labels = border_labels - {0}
    alpha = np.where(np.isin(labels, list(background_labels)), 0, 255).astype(np.uint8)
    alpha = cv2.GaussianBlur(alpha, (3, 3), 0)

    pastel = np.array((250.0, 247.0, 252.0), dtype=np.float32)
    coverage = alpha.astype(np.float32)[:, :, None] / 255.0
    cleaned = pastel + (rgb - pastel) * coverage
    portrait = Image.fromarray(
        np.dstack((np.clip(cleaned, 0, 255), alpha)).astype(np.uint8), "RGBA"
    )
    portrait = portrait.resize((units(size), units(size)), Image.Resampling.LANCZOS)
    alpha = portrait.getchannel("A").point(lambda value: round(value * 0.95))
    portrait.putalpha(alpha)
    return portrait


def add_character(canvas: Image.Image, layout: dict[str, tuple[int, ...]], portrait: Image.Image) -> None:
    x, y, _ = layout["portrait"]
    canvas.alpha_composite(portrait, (units(x), units(y)))

    width, height = canvas.size
    x_values = np.linspace(0, 1, width, dtype=np.float32)[None, :]
    protection = np.clip((0.66 - x_values) / 0.42, 0, 1)
    veil_alpha = np.broadcast_to((protection * 125).astype(np.uint8), (height, width))
    veil = Image.new("RGBA", canvas.size, (252, 249, 253, 0))
    veil.putalpha(Image.fromarray(veil_alpha))
    canvas.alpha_composite(veil)


def make_mask(source: Image.Image, box: tuple[int, int, int, int]) -> tuple[Image.Image, Image.Image | None]:
    rgb = np.asarray(source.crop(box).convert("RGB"), dtype=np.uint8)
    alpha = np.max(rgb, axis=2)
    accent = (
        (rgb[:, :, 1] > rgb[:, :, 0] * 1.15)
        & (rgb[:, :, 2] > rgb[:, :, 0] * 1.15)
        & (rgb[:, :, 1] > 90)
        & (rgb[:, :, 2] > 110)
    )
    base_alpha = alpha.copy()
    base_alpha[accent] = 0
    accent_alpha = np.zeros_like(alpha)
    accent_alpha[accent] = alpha[accent]
    return Image.fromarray(base_alpha), Image.fromarray(accent_alpha)


def paste_mask(
    canvas: Image.Image,
    mask: Image.Image,
    point: tuple[int, int],
    width: int,
    color: tuple[int, int, int],
) -> tuple[int, int, int, int]:
    height = round(mask.height * width / mask.width)
    resized = mask.resize((units(width), units(height)), Image.Resampling.LANCZOS)
    layer = Image.new("RGBA", resized.size, (*color, 0))
    layer.putalpha(resized)
    xy = (units(point[0]), units(point[1]))
    canvas.alpha_composite(layer, xy)
    return xy[0], xy[1], xy[0] + layer.width, xy[1] + layer.height


def add_type(canvas: Image.Image, layout: dict[str, tuple[int, ...]], source: Image.Image) -> list[tuple[int, int, int, int]]:
    brand_mask, _ = make_mask(source, TYPE_CROPS["brand"])
    category_mask, _ = make_mask(source, TYPE_CROPS["category"])
    bounds = []

    icon_x, icon_y, icon_size = layout["icon"]
    icon = Image.open(ICON).convert("RGBA").resize(
        (units(icon_size), units(icon_size)), Image.Resampling.LANCZOS
    )
    canvas.alpha_composite(icon, (units(icon_x), units(icon_y)))

    brand_point = layout["brand"]
    bounds.append(paste_mask(canvas, brand_mask, brand_point, 62, (205, 96, 132)))

    category_x, category_y, category_width = layout["category"]
    bounds.append(paste_mask(canvas, category_mask, (category_x, category_y), category_width, (124, 128, 137)))

    for point, width, crop in layout["headline_lines"]:
        line_mask, accent_mask = make_mask(source, crop)
        bounds.append(paste_mask(canvas, line_mask, point, width, (58, 61, 70)))
        bounds.append(paste_mask(canvas, accent_mask, point, width, (197, 91, 130)))
    return bounds


def create(aspect: str, type_source: Image.Image) -> dict[str, object]:
    layout = LAYOUTS[aspect]
    width, height = layout["size"]
    canvas = soft_background(units(width), units(height)).convert("RGBA")
    character_x, character_y, character_size = layout["portrait"]
    portrait = load_character(character_size)
    add_character(canvas, layout, portrait)
    type_bounds = add_type(canvas, layout, type_source)
    character_bounds = (
        units(character_x),
        units(character_y),
        units(character_x) + portrait.width,
        units(character_y) + portrait.height,
    )

    if any(x1 < 0 or y1 < 0 or x2 > canvas.width or y2 > canvas.height for x1, y1, x2, y2 in type_bounds):
        raise RuntimeError(f"Cover text is outside the {aspect} safe area")
    if any(value < 0 for value in character_bounds[:2]) or character_bounds[2] > canvas.width or character_bounds[1] >= canvas.height:
        raise RuntimeError(f"Character is outside the {aspect} safe area")
    if any(bounds[2] > units(layout["foreground_limit"]) for bounds in type_bounds):
        raise RuntimeError(f"Cover text obstructs the character in the {aspect} layout")
    if any(bounds[3] + units(24) > character_bounds[0] for bounds in type_bounds if bounds[2] > character_bounds[0]):
        raise RuntimeError(f"Cover text overlaps the character in the {aspect} layout")

    display = canvas.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)
    thumbnail = display.resize((320, round(320 * height / width)), Image.Resampling.LANCZOS)
    aspect_slug = "16比9" if aspect == "16:9" else "4比3"
    filename = f"汐-宣传封面-{aspect_slug}"
    high_path = OUTPUT / f"{filename}-高清.png"
    png_path = OUTPUT / f"{filename}.png"
    jpg_path = OUTPUT / f"{filename}.jpg"
    thumb_path = OUTPUT / f"{filename}-缩略图.jpg"

    canvas.save(high_path, optimize=True)
    display.save(png_path, optimize=True)
    display.save(jpg_path, quality=96, subsampling=0, optimize=True)
    thumbnail.save(thumb_path, quality=95, subsampling=0, optimize=True)

    return {
        "aspect": aspect,
        "size": [width, height],
        "master_size": [canvas.width, canvas.height],
        "headline": HEADLINE,
        "headline_lines": list(HEADLINE_LINES),
        "brand": "汐",
        "category": "Markdown Editor",
        "style": "pastel pink/lavender, supplied saluting character on the right, large three-line headline on the left",
        "sources": ["promo/cover-assets/ushio-portrait.png", "sample/cover.png", "app.png"],
        "character_bounds_at_master_size": list(character_bounds),
        "type_bounds_at_master_size": [list(bounds) for bounds in type_bounds],
        "outputs": [png_path.name, jpg_path.name, high_path.name, thumb_path.name],
    }


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    type_source = Image.open(TYPE_SOURCE).convert("RGB")
    layouts = [create(aspect, type_source) for aspect in LAYOUTS]
    (OUTPUT / "cover-layout.json").write_text(
        json.dumps({"covers": layouts}, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print("Created 1920x1080 and 1600x1200 covers with 4K/HD masters.")
    print("PASS: single-line text and supplied character remain inside their safe areas.")


if __name__ == "__main__":
    main()
