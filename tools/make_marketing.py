#!/usr/bin/env python3
"""Compose README images and the demo GIF from the screenshots.
    tools/make_screenshots.sh /tmp/scamsaathi-shots && python tools/make_marketing.py /tmp/scamsaathi-shots
Needs Pillow."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "images"
DARK, MID, TEAL = (11, 60, 93), (29, 111, 165), (20, 184, 166)
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def gradient(w, h, a=DARK, b=MID):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for x in range(w):
        t = x / max(1, w - 1)
        d.line([(x, 0), (x, h)], fill=tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)))
    return img


def phone(shot, height=1080, scale=1.0):
    """Crop a screenshot to phone height, round the corners, add a bezel and a soft shadow."""
    im = shot.convert("RGB").crop((0, 0, shot.width, height))
    w, h = im.size
    pad = 14
    framed = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(framed)
    d.rounded_rectangle([0, 0, framed.width - 1, framed.height - 1], radius=48, fill=(18, 24, 30, 255))
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=36, fill=255)
    framed.paste(im, (pad, pad), mask)
    if scale != 1.0:
        framed = framed.resize((int(framed.width * scale), int(framed.height * scale)), Image.LANCZOS)
    shadow = Image.new("RGBA", (framed.width + 80, framed.height + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([40, 52, 40 + framed.width, 52 + framed.height], radius=48, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    shadow.alpha_composite(framed, (40, 40))
    return shadow


def social(shots):
    W, H = 1280, 640
    img = gradient(W, H).convert("RGBA")
    d = ImageDraw.Draw(img)
    logo = Image.open(ROOT / "docs/images/app-icon.png").resize((120, 120), Image.LANCZOS)
    img.alpha_composite(logo, (70, 80))
    d.text((210, 98), "ScamSaathi", font=font(BOLD, 54), fill="white")
    d.text((212, 170), "Open-source scam shield", font=font(REG, 26), fill=(200, 225, 240))
    lines = ["Check a message, link or app", "offline, in Hindi and English", "and bring someone you trust in."]
    for i, t in enumerate(lines):
        d.text((72, 270 + i * 46), t, font=font(BOLD, 30), fill="white")
    for i, t in enumerate(["Private by default", "Explains every warning", "Signed rule updates"]):
        x = 72 + i * 0
        d.rounded_rectangle([x, 470 + i * 46, x + 22, 470 + i * 46 + 22], radius=11, fill=TEAL)
        d.text((x + 36, 466 + i * 46), t, font=font(REG, 25), fill=(220, 235, 245))
    p1 = phone(shots["kyc-hi"], height=1180, scale=0.56)
    p2 = phone(shots["apk-en"], height=1180, scale=0.56)
    img.alpha_composite(p2, (960, 30))
    img.alpha_composite(p1, (730, 80))
    return img.convert("RGB")


def strip(shots):
    names = [("home", "Paste or try an example"), ("kyc-hi", "Clear verdict in Hindi"),
             ("apk-en", "Why, in plain words"), ("ok-hi", "Never claims 'safe'")]
    pw = 330
    gap = 40
    W = len(names) * pw + (len(names) + 1) * gap
    H = 900
    img = gradient(W, H, (236, 243, 248), (222, 234, 244)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for i, (key, caption) in enumerate(names):
        p = phone(shots[key], height=1100, scale=0.66)
        x = gap + i * (pw + gap) + (pw - p.width) // 2
        img.alpha_composite(p, (x, 20))
        tw = d.textlength(caption, font=font(BOLD, 24))
        d.text((gap + i * (pw + gap) + (pw - tw) / 2, 825), caption, font=font(BOLD, 24), fill=DARK)
    return img.convert("RGB")


def demo_gif(shots):
    frames = []
    seq = [("home", "Paste a message, or try an example", 1800), ("kyc-hi", "Verdict in Hindi, with reasons", 2600),
           ("apk-en", "Or English: a fake government app", 2600), ("ok-hi", "A normal message: no warning signs", 2200)]
    durations = []
    for key, caption, ms in seq:
        shot = shots[key].convert("RGB").crop((0, 0, 430, 1100))
        canvas = Image.new("RGB", (430, 1100 + 70), (255, 255, 255))
        canvas.paste(shot, (0, 0))
        d = ImageDraw.Draw(canvas)
        d.rectangle([0, 1100, 430, 1170], fill=DARK)
        f = font(BOLD, 19)
        d.text(((430 - d.textlength(caption, font=f)) / 2, 1121), caption, font=f, fill="white")
        frames.append(canvas.resize((344, 936), Image.LANCZOS).quantize(colors=128, method=Image.MEDIANCUT))
        durations.append(ms)
    frames[0].save(OUT / "demo.gif", save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=True)


def main():
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/scamsaathi-shots")
    shots = {p.stem: Image.open(p) for p in src.glob("*.png")}
    OUT.mkdir(parents=True, exist_ok=True)
    for key in ("home", "kyc-hi", "apk-en", "upi-en", "ok-hi", "kyc-dark"):
        shots[key].convert("RGB").crop((0, 0, 430, 1480)).save(OUT / f"screenshot-{key}.png", optimize=True)
    social(shots).save(OUT / "social-preview.png", optimize=True)
    strip(shots).save(OUT / "screens.png", optimize=True)
    demo_gif(shots)
    print("images written to", OUT)


if __name__ == "__main__":
    main()
