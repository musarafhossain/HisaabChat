"""Draws the HisaabChat mark and writes every app icon and launch image.

The mark: a white chat bubble holding a ₹ sign on a teal rounded square,
the same shapes as `lib/core/widgets/app_logo.dart` and the web loading
screen in `web/index.html`.

Run from the app folder (needs Pillow):

    python tool/branding/generate_branding.py

Writes:
- android/app/src/main/res: launcher icons (legacy + adaptive + themed
  monochrome), launch screen images for Android 5–11 and the Android 12+
  splash icon
- windows/runner/resources/app_icon.ico (16–256 px)
- web/favicon.png and web/icons/* (normal + maskable)
- assets/branding/*.png: the 1024 px masters
"""

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

TEAL = (0x00, 0x89, 0x7B, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)
SS = 4  # supersampling for smooth edges

APP = Path(__file__).resolve().parents[2]
FONT = Path(os.environ.get('FLUTTER_ROOT', 'C:/flutter')) / 'bin/cache/artifacts/material_fonts/roboto-black.ttf'


def bubble(size: int, rupee_cutout: bool = False, rupee_color=TEAL) -> Image.Image:
    """The white bubble (with tail) and ₹, in a size×size transparent box."""
    s = size * SS
    img = Image.new('RGBA', (s, s), CLEAR)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, s - 1, s * 0.84], radius=s * 0.3, fill=WHITE)
    d.polygon([(s * 0.2, s * 0.7), (s * 0.12, s - 1), (s * 0.46, s * 0.8)], fill=WHITE)

    font = ImageFont.truetype(str(FONT), int(s * 0.52))
    left, top, right, bottom = d.textbbox((0, 0), '₹', font=font)
    cx, cy = s * 0.5, s * 0.42  # optical center of the bubble body
    x = cx - (left + right) / 2
    y = cy - (top + bottom) / 2
    if rupee_cutout:
        mask = Image.new('L', (s, s), 0)
        ImageDraw.Draw(mask).text((x, y), '₹', font=font, fill=255)
        img.paste(Image.new('RGBA', (s, s), CLEAR), (0, 0), mask)
    else:
        d.text((x, y), '₹', font=font, fill=rupee_color)
    return img.resize((size, size), Image.LANCZOS)


def canvas(size: int, background=CLEAR, radius: float | None = None) -> Image.Image:
    """A square: transparent, filled, or a filled rounded square."""
    s = size * SS
    img = Image.new('RGBA', (s, s), CLEAR)
    if background != CLEAR:
        d = ImageDraw.Draw(img)
        if radius is None:
            d.rectangle([0, 0, s, s], fill=background)
        else:
            d.rounded_rectangle([0, 0, s - 1, s - 1], radius=s * radius, fill=background)
    return img.resize((size, size), Image.LANCZOS)


def with_mark(size: int, mark_fraction: float, background=CLEAR, radius=None, **kw) -> Image.Image:
    img = canvas(size, background, radius)
    m = round(size * mark_fraction)
    mark = bubble(m, **kw)
    # Bubble boxes are a little bottom-heavy (tail); nudge up to look centered.
    img.alpha_composite(mark, ((size - m) // 2, (size - m) // 2 - round(m * 0.02)))
    return img


def logo(size: int) -> Image.Image:
    """App logo: teal rounded square (radius 28%) with the mark at 62%."""
    return with_mark(size, 0.62, TEAL, radius=0.28)


def save(img: Image.Image, path: str):
    out = APP / path
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    print('wrote', path)


def main():
    # Masters.
    save(logo(1024), 'assets/branding/logo.png')
    save(with_mark(1024, 0.40), 'assets/branding/adaptive_foreground.png')

    res = 'android/app/src/main/res'
    densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    for name, scale in densities.items():
        # Legacy launcher icon (48 dp), round variant too.
        save(logo(round(48 * scale)), f'{res}/mipmap-{name}/ic_launcher.png')
        # Adaptive icon layers are 108 dp; the mark stays inside the 66 dp safe circle.
        save(with_mark(round(108 * scale), 0.40), f'{res}/mipmap-{name}/ic_launcher_foreground.png')
        save(with_mark(round(108 * scale), 0.40, rupee_cutout=True), f'{res}/mipmap-{name}/ic_launcher_monochrome.png')
        # Launch screen (Android 5–11): the 88 dp logo, like the in-app splash.
        save(logo(round(88 * scale)), f'{res}/drawable-{name}/splash_logo.png')
        # Android 12+ splash icon: 288 dp canvas, icon shown in a 192 dp circle.
        save(with_mark(round(288 * scale), 0.36), f'{res}/drawable-{name}/splash_icon.png')

    # Windows: one .ico with every common size.
    ico = logo(256)
    out = APP / 'windows/runner/resources/app_icon.ico'
    ico.save(out, sizes=[(16, 16), (20, 20), (24, 24), (32, 32), (40, 40), (48, 48), (64, 64), (128, 128), (256, 256)])
    print('wrote windows/runner/resources/app_icon.ico')

    # Web.
    save(logo(32), 'web/favicon.png')
    save(logo(192), 'web/icons/Icon-192.png')
    save(logo(512), 'web/icons/Icon-512.png')
    # Maskable: full-bleed teal, mark inside the 80% safe zone.
    save(with_mark(192, 0.48, TEAL), 'web/icons/Icon-maskable-192.png')
    save(with_mark(512, 0.48, TEAL), 'web/icons/Icon-maskable-512.png')


if __name__ == '__main__':
    main()
