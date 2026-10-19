#!/usr/bin/env python3
"""Regenerate the logo, Android launcher icons and web icons. Needs Pillow:  python tools/make_brand.py"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
DARK, MID, TEAL, WHITE = (11, 60, 93), (29, 111, 165), (20, 184, 166), (255, 255, 255)
SS = 4  # supersampling for smooth edges


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def bezier(p0, p1, p2, p3, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append((u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
                    u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]))
    return out


def shield_points(size, margin=0.0):
    s = size * (1 - 2 * margin)
    o = size * margin
    def P(x, y):
        return (o + x * s, o + y * s)
    right = [P(0.5, 0.04)] + [P(*p) for p in bezier((0.5, 0.04), (0.62, 0.13), (0.78, 0.17), (0.90, 0.17))[1:]]
    right += [P(*p) for p in bezier((0.90, 0.17), (0.90, 0.55), (0.78, 0.80), (0.5, 0.97))[1:]]
    left = [(2 * (size / 2) - x, y) for x, y in reversed(right)]
    return right + left[1:]


def shield(size, scale=1.0, fill_gradient=True, color=None):
    """RGBA image of a shield with a white check mark."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    mask = Image.new("L", (big, big), 0)
    pts = shield_points(big, margin=(1 - scale) / 2)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    if fill_gradient:
        grad = Image.new("RGBA", (big, big))
        gd = ImageDraw.Draw(grad)
        for y in range(big):
            gd.line([(0, y), (big, y)], fill=lerp(DARK, MID, y / big) + (255,))
        img.paste(grad, (0, 0), mask)
    else:
        img.paste(Image.new("RGBA", (big, big), color + (255,)), (0, 0), mask)
    d = ImageDraw.Draw(img)
    s, o = big * scale, big * (1 - scale) / 2
    w = int(s * 0.095)
    chk = [(o + s * 0.30, o + s * 0.50), (o + s * 0.44, o + s * 0.65), (o + s * 0.71, o + s * 0.34)]
    chk_color = WHITE if fill_gradient else DARK
    d.line(chk, fill=chk_color + (255,), width=w, joint="curve")
    for x, y in (chk[0], chk[2]):
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=chk_color + (255,))
    # a small teal dot: the "saathi" next to you
    r = s * 0.065
    cx, cy = o + s * 0.76, o + s * 0.70
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=TEAL + (255,), outline=WHITE + (255,), width=int(r * 0.35))
    return img.resize((size, size), Image.LANCZOS)


def app_icon(size, maskable=False):
    """Rounded-square launcher icon: gradient background, white shield, dark check."""
    big = size * SS
    bg = Image.new("RGBA", (big, big))
    d = ImageDraw.Draw(bg)
    for y in range(big):
        d.line([(0, y), (big, y)], fill=lerp(DARK, MID, y / big) + (255,))
    if not maskable:
        m = Image.new("L", (big, big), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * 0.22), fill=255)
        out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        out.paste(bg, (0, 0), m)
        bg = out
    inner = shield(big, scale=0.52 if maskable else 0.62, fill_gradient=False, color=WHITE)
    bg.alpha_composite(inner)
    return bg.resize((size, size), Image.LANCZOS)


def main():
    logo = shield(512)
    (ROOT / "app/assets").mkdir(exist_ok=True)
    logo.save(ROOT / "app/assets/logo.png")
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        app_icon(px).save(ROOT / f"app/android/app/src/main/res/mipmap-{folder}/ic_launcher.png")
    web = ROOT / "app/web"
    app_icon(192).save(web / "icons/Icon-192.png")
    app_icon(512).save(web / "icons/Icon-512.png")
    app_icon(192, maskable=True).save(web / "icons/Icon-maskable-192.png")
    app_icon(512, maskable=True).save(web / "icons/Icon-maskable-512.png")
    app_icon(64).save(web / "favicon.png")
    app_icon(1024).save(ROOT / "docs/images/app-icon.png") if (ROOT / "docs/images").exists() else None
    print("brand assets written")


if __name__ == "__main__":
    main()
