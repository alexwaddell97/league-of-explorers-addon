"""League of Explorers: CurseForge banner (1600 x 500) and icon (400 x 400).

Made from the author's own Forever screenshot (a study with candles and
books, cropped clear of the interface) and drawn shapes: tooled leather,
gold rules and a compass star, like the cover of the book in the addon.
Lettering is Trajan Pro and Adobe Garamond Pro from Windows' fonts.

    python make_brand.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SHOT = r"C:/Games/World of Warcraft/_forever_/Screenshots/WoWScrnShot_111126_162006.jpg"
CROP = (1720, 430, 2560, 1150)          # candles and books, no interface
TRAJAN = "C:/Windows/Fonts/TrajanPro-Bold.otf"
TRAJAN_R = "C:/Windows/Fonts/TrajanPro-Regular.otf"
GARAMOND_I = "C:/Windows/Fonts/AGaramondPro-Italic.otf"

LEATHER = np.array([40, 26, 19], dtype=np.float32)
GOLD_TOP, GOLD_BOT = (250, 222, 158), (178, 124, 54)
GOLD = (222, 178, 102)
GOLD_DARK = (150, 102, 44)
CREAM = (238, 226, 200)
SS = 4  # shapes drawn at four times the size, then shrunk, for smooth edges

rng = np.random.default_rng(7)


def leather(w, h):
    """Dark leather: fine grain, a slow mottle, darker toward the edges."""
    grain = rng.normal(0, 1, (h, w)).astype(np.float32)
    grain = np.array(Image.fromarray(((grain * 18) + 128).clip(0, 255).astype(np.uint8))
                     .filter(ImageFilter.GaussianBlur(0.8)), dtype=np.float32) / 128 - 1
    mot = rng.normal(0, 1, (h // 16 + 1, w // 16 + 1)).astype(np.float32)
    mot = np.array(Image.fromarray(((mot * 40) + 128).clip(0, 255).astype(np.uint8))
                   .resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(18)), dtype=np.float32) / 128 - 1
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = (xs / w - 0.5) * 2, (ys / h - 0.5) * 2
    vig = 1 - 0.45 * np.clip(dx * dx * 0.6 + dy * dy, 0, 1.4) / 1.4
    top = 1 + 0.10 * (1 - ys / h)  # a little lighter toward the top
    k = (1 + grain * 0.10 + mot * 0.10) * vig * top
    img = LEATHER[None, None, :] * k[..., None]
    return Image.fromarray(img.clip(0, 255).astype(np.uint8)).convert("RGBA")


def gold_text(size, text, font_path, tracking=0, shadow=6):
    """Gold-gradient lettering on a clear layer, with a soft shadow."""
    f = ImageFont.truetype(font_path, size * 2)
    # Letter by letter, to space them out.
    widths = [f.getlength(ch) for ch in text]
    total = sum(widths) + tracking * 2 * (len(text) - 1)
    l, t, r, b = f.getbbox(text)
    pad = 30 * 2
    w, h = int(total) + pad * 2, b - t + pad * 2
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    x = pad
    for ch, cw in zip(text, widths):
        d.text((x, pad - t), ch, font=f, fill=255)
        x += cw + tracking * 2
    ys = np.linspace(0, 1, h)[:, None]
    k = np.clip((ys - pad / h) / ((h - 2 * pad) / h), 0, 1)
    grad = np.zeros((h, w, 3), dtype=np.float32)
    for i in range(3):
        grad[..., i] = GOLD_TOP[i] + (GOLD_BOT[i] - GOLD_TOP[i]) * k
    face = Image.fromarray(grad.astype(np.uint8)).convert("RGBA")
    face.putalpha(mask)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh.putalpha(mask.filter(ImageFilter.GaussianBlur(shadow * 2)).point(lambda v: int(v * 0.9)))
    out.alpha_composite(sh, (0, 4))
    out = Image.alpha_composite(out, face)
    return out.resize((w // 2, h // 2), Image.LANCZOS), pad // 2


def plain_text(size, text, color, font_path, shadow=4):
    f = ImageFont.truetype(font_path, size * 2)
    l, t, r, b = f.getbbox(text)
    pad = 20 * 2
    w, h = r - l + pad * 2, b - t + pad * 2
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((pad - l, pad - t), text, font=f, fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh.putalpha(mask.filter(ImageFilter.GaussianBlur(shadow * 2)).point(lambda v: int(v * 0.95)))
    out.alpha_composite(sh, (0, 3))
    face = Image.new("RGBA", (w, h), color + (255,))
    face.putalpha(mask)
    out = Image.alpha_composite(out, face)
    return out.resize((w // 2, h // 2), Image.LANCZOS), pad // 2


def emblem(diam):
    """The compass star in a gold ring, as on the addon's book cover."""
    S = diam * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = S / 2
    R = S / 2

    def pt(a, r):
        return (c + np.sin(a) * r, c - np.cos(a) * r)

    # The star behind the ring: long points to the compass directions,
    # short ones between; each point lit on one side, shaded on the other.
    for k in range(8):
        a = k * np.pi / 4
        long = k % 2 == 0
        tip = pt(a, R * (0.98 if long else 0.80))
        w = R * (0.13 if long else 0.10)
        base = R * 0.30
        left = (c + np.sin(a) * base - np.cos(a) * w, c - np.cos(a) * base - np.sin(a) * w)
        right = (c + np.sin(a) * base + np.cos(a) * w, c - np.cos(a) * base + np.sin(a) * w)
        hi = GOLD_TOP if long else GOLD
        lo = GOLD_DARK if long else (122, 84, 38)
        d.polygon([(c, c), tip, left], fill=hi + (255,))
        d.polygon([(c, c), tip, right], fill=lo + (255,))
    # The ring: gold, a dark groove, gold again, and leather inside.
    for r, col in ((0.56, GOLD), (0.52, (60, 40, 22)), (0.50, GOLD_TOP), (0.46, tuple(LEATHER.astype(int)))):
        rr = R * r
        d.ellipse((c - rr, c - rr, c + rr, c + rr), fill=col + (255,))
    # Inside: a small star and a centre stud.
    for k in range(4):
        a = k * np.pi / 2
        tip = pt(a, R * 0.38)
        w = R * 0.07
        left = (c - np.cos(a) * w, c - np.sin(a) * w)
        right = (c + np.cos(a) * w, c + np.sin(a) * w)
        d.polygon([(c, c), tip, left], fill=GOLD_TOP + (255,))
        d.polygon([(c, c), tip, right], fill=GOLD_DARK + (255,))
    rr = R * 0.07
    d.ellipse((c - rr, c - rr, c + rr, c + rr), fill=GOLD_TOP + (255,))
    im = im.resize((diam, diam), Image.LANCZOS)
    # A soft shadow under it, as if pressed into the leather.
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sh.putalpha(im.getchannel("A").filter(ImageFilter.GaussianBlur(diam / 60)).point(lambda v: int(v * 0.8)))
    out = Image.new("RGBA", (diam, diam), (0, 0, 0, 0))
    out.alpha_composite(sh, (0, max(1, diam // 120)))
    return Image.alpha_composite(out, im)


def diamond(d, x, y, r, col):
    d.polygon([(x, y - r), (x + r, y), (x, y + r), (x - r, y)], fill=col)


def tooled_frame(img, inset, inner=8, corner=6):
    """A gold rule with a fine rule inside it, and diamonds at the corners."""
    w, h = img.size
    big = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    a = inset * 2
    d.rectangle((a, a, w * 2 - a, h * 2 - a), outline=GOLD + (235,), width=4)
    b = (inset + inner) * 2
    d.rectangle((b, b, w * 2 - b, h * 2 - b), outline=GOLD + (140,), width=2)
    for x, y in ((a, a), (w * 2 - a, a), (a, h * 2 - a), (w * 2 - a, h * 2 - a)):
        diamond(d, x, y, corner * 2, GOLD_TOP + (255,))
    img.alpha_composite(big.resize((w, h), Image.LANCZOS))


def banner():
    W, H = 1600, 500
    img = leather(W, H)

    # The study on the right, fading into the leather.
    photo = Image.open(SHOT).convert("RGB").crop(CROP)
    pw = 760
    ph = int(photo.height * pw / photo.width)
    photo = photo.resize((pw, ph), Image.LANCZOS)
    top = 46
    photo = photo.crop((0, top, pw, top + H)).convert("RGBA")
    arr = np.array(photo, dtype=np.float32)
    arr[..., :3] *= 0.92
    fade = np.clip(np.linspace(-0.25, 1.6, pw), 0, 1)[None, :] ** 1.3
    arr[..., 3] = 255 * fade
    photo = Image.fromarray(arr.clip(0, 255).astype(np.uint8))
    img.alpha_composite(photo, (W - pw, 0))

    # Emblem, then the title beside it.
    em = emblem(250)
    img.alpha_composite(em, (70, (H - 250) // 2))
    x0 = 352
    line1, p1 = gold_text(34, "LEAGUE OF", TRAJAN_R, tracking=6)
    line2, p2 = gold_text(78, "EXPLORERS", TRAJAN, tracking=3)
    img.alpha_composite(line1, (x0 - p1, 128 - p1))
    img.alpha_composite(line2, (x0 - p2, 170 - p2))
    d = ImageDraw.Draw(img)
    ry = 284
    d.line((x0, ry, x0 + 210, ry), fill=GOLD + (170,), width=1)
    diamond(d, x0 + 226, ry, 6, GOLD_TOP + (255,))
    d.line((x0 + 242, ry, x0 + 452, ry), fill=GOLD + (170,), width=1)
    sub, ps = plain_text(30, "Exploration, rares and weekly hunts", CREAM, GARAMOND_I)
    img.alpha_composite(sub, (x0 - ps, 306 - ps))
    sub2, ps2 = plain_text(30, "for your guild or on your own", CREAM, GARAMOND_I)
    img.alpha_composite(sub2, (x0 - ps2, 344 - ps2))

    tooled_frame(img, 16)
    img.convert("RGB").save(os.path.join(HERE, "banner.jpg"), quality=92)


def icon():
    S = 400
    img = leather(S, S)
    tooled_frame(img, 14, inner=7, corner=5)
    em = emblem(330)
    img.alpha_composite(em, ((S - 330) // 2, (S - 330) // 2))
    img.convert("RGB").save(os.path.join(HERE, "icon.png"))


if __name__ == "__main__":
    banner()
    icon()
    print("banner.jpg, icon.png")
