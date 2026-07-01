from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "design" / "icons" / "evoly" / "generated"


def rounded_rectangle_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def vertical_gradient(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    stops = [
        (0.0, (242, 245, 255, 255)),
        (0.35, (142, 160, 255, 255)),
        (1.0, (74, 87, 216, 255)),
    ]

    for y in range(size):
        t = y / max(size - 1, 1)
        for index in range(len(stops) - 1):
            left_t, left_color = stops[index]
            right_t, right_color = stops[index + 1]
            if left_t <= t <= right_t:
                local = (t - left_t) / (right_t - left_t)
                color = tuple(
                    round(left_color[channel] * (1 - local) + right_color[channel] * local)
                    for channel in range(4)
                )
                break
        else:
            color = stops[-1][1]

        for x in range(size):
            highlight = max(0, 1 - math.hypot((x / size) - 0.22, (y / size) - 0.16) * 2.2)
            adjusted = (
                min(255, round(color[0] + 34 * highlight)),
                min(255, round(color[1] + 34 * highlight)),
                min(255, round(color[2] + 30 * highlight)),
                color[3],
            )
            pixels[x, y] = adjusted

    return image


def draw_icon(size: int) -> Image.Image:
    scale = size / 1024
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    background = vertical_gradient(size)
    mask = rounded_rectangle_mask(size, round(228 * scale))
    canvas.alpha_composite(Image.composite(background, Image.new("RGBA", (size, size), 0), mask))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.line(
        [(262 * scale, 694 * scale), (762 * scale, 555 * scale)],
        fill=(28, 36, 118, 82),
        width=round(84 * scale),
        joint="curve",
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(12 * scale)))
    canvas.alpha_composite(shadow)

    draw = ImageDraw.Draw(canvas)

    path_points = [
        (262 * scale, 682 * scale),
        (350 * scale, 609 * scale),
        (421 * scale, 610 * scale),
        (490 * scale, 643 * scale),
        (567 * scale, 680 * scale),
        (644 * scale, 681 * scale),
        (762 * scale, 543 * scale),
    ]
    draw_rounded_polyline(
        draw,
        path_points,
        fill=(255, 255, 255, 245),
        width=round(74 * scale),
    )
    draw_rounded_polyline(
        draw,
        [(621 * scale, 544 * scale), (762 * scale, 543 * scale), (762 * scale, 685 * scale)],
        fill=(255, 255, 255, 245),
        width=round(74 * scale),
    )

    draw_rounded_polyline(
        draw,
        [(293 * scale, 776 * scale), (758 * scale, 776 * scale)],
        fill=(255, 255, 255, 78),
        width=round(38 * scale),
    )

    draw.ellipse(
        (
            (318 - 73) * scale,
            (353 - 73) * scale,
            (318 + 73) * scale,
            (353 + 73) * scale,
        ),
        fill=(167, 243, 208, 255),
    )
    draw.ellipse(
        (
            (512 - 97) * scale,
            (303 - 97) * scale,
            (512 + 97) * scale,
            (303 + 97) * scale,
        ),
        fill=(255, 255, 255, 58),
    )
    draw_rounded_polyline(
        draw,
        [(470 * scale, 302 * scale), (503 * scale, 336 * scale), (561 * scale, 267 * scale)],
        fill=(255, 255, 255, 250),
        width=round(38 * scale),
    )

    return canvas


def draw_rounded_polyline(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: tuple[int, int, int, int],
    width: int,
) -> None:
    draw.line(points, fill=fill, width=width, joint="curve")
    radius = width / 2
    for x, y in points:
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill)


def save_android_icons(source: Image.Image) -> None:
    targets = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, size in targets.items():
        out_path = ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        source.resize((size, size), Image.Resampling.LANCZOS).save(out_path)


def save_windows_icon(source: Image.Image) -> None:
    out_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sizes = [16, 24, 32, 48, 64, 128, 256]
    images = [source.resize((size, size), Image.Resampling.LANCZOS) for size in sizes]
    images[-1].save(out_path, sizes=[(size, size) for size in sizes], append_images=images[:-1])


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    source = draw_icon(1024)
    source_path = OUT_DIR / "evoly-app-icon-trajectory-1024.png"
    source.save(source_path)
    save_android_icons(source)
    save_windows_icon(source)
    print(f"Generated source: {source_path}")
    print("Updated Android launcher icons.")
    print("Updated Windows app icon.")


if __name__ == "__main__":
    main()
