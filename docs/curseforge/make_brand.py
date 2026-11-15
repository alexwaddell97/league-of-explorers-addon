"""League of Explorers: CurseForge banner (1600 x 500) and icon (400 x 400).

The picture is the author's own Forever screenshot (source.webp: a camp
lit under a great tree at night, interface hidden), used full width. The
title sits in the dark forest on the left, in the game's own font (Friz
Quadrata), under the six bookmark ribbons from the addon's book, in the
addon's colours.

    python make_brand.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SHOT = os.path.join(HERE, "source.webp")
CLEAN = (0, 0, 1656, 928)  # a thin grey strip runs along the bottom and right edges
TOP = 330                  # where the banner's strip starts, in the scaled picture
FRIZ = "C:/Windows/Fonts/FrizQuadrata-BT-Roman.ttf"

PANEL = (23, 18, 15)
PAPER = (241, 233, 215)       # the addon's page colour
MUTED = (150, 132, 108)
# The bookmark colours from UI/Theme.lua, in page order.
RIBBONS = [
    (140, 41, 36),    # Guild
    (46, 102, 77),    # My Journal
    (51, 77, 133),    # Bestiary
    (158, 107, 31),   # Expeditions
    (107, 56, 122),   # Leaders
    (77, 87, 97),     # Submissions
]
SS = 4


def ribbon(w, h, color):
    """A cloth bookmark: a strip with a notched end and stitched edges."""
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    notch = int(W * 0.45)
    d.polygon([(0, 0), (W, 0), (W, H), (W // 2, H - notch), (0, H)], fill=color + (255,))
    # Light from above: a touch lighter at the top.
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for y in range(H):
        a = int(40 * (1 - y / H))
        sd.line((0, y, W, y), fill=(255, 255, 255, a))
    mask = im.getchannel("A")
    shade.putalpha(Image.composite(shade.getchannel("A"), Image.new("L", (W, H), 0), mask))
    im = Image.alpha_composite(im, shade)
    d = ImageDraw.Draw(im)
    # Stitching down each side.
    st = 3 * SS
    for x in (st, W - st - SS):
        for y in range(0, H - notch - 4 * SS, 6 * SS):
            d.line((x, y + SS, x, y + 4 * SS), fill=(255, 255, 255, 70), width=SS)
    return im.resize((w, h), Image.LANCZOS)


def text(img, xy, s, size, color, tracking=0):
    f = ImageFont.truetype(FRIZ, size * 2)
    l, t, r, b = f.getbbox(s)
    widths = [f.getlength(ch) for ch in s]
    w = int(sum(widths) + tracking * 2 * (len(s) - 1)) + 8
    h = b - t + 8
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x = 4
    for ch, cw in zip(s, widths):
        d.text((x, 4 - t), ch, font=f, fill=color + (255,))
        x += cw + tracking * 2
    layer = layer.resize((w // 2, h // 2), Image.LANCZOS)
    img.alpha_composite(layer, (xy[0] - 2, xy[1] - 2))
    return layer.size


def banner():
    W, H = 1600, 500
    photo = Image.open(SHOT).convert("RGB").crop(CLEAN)
    photo = photo.resize((W, round(photo.height * W / photo.width)), Image.LANCZOS)
    img = photo.crop((0, TOP, W, TOP + H)).convert("RGBA")
    # Darker toward the left, so the title reads over the forest.
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for x in range(540):
        sd.line((x, 0, x, H), fill=PANEL + (int(140 * (1 - x / 540) ** 1.4),))
    img = Image.alpha_composite(img, shade)

    # The bookmarks, hanging from the top edge.
    x = 84
    for i, c in enumerate(RIBBONS):
        h = (118, 96, 132, 104, 88, 112)[i]
        r = ribbon(34, h, c)
        img.alpha_composite(r, (x, 0))
        x += 34 + 10

    # In the dark to the left of the camp: two lines, so it stays clear of it.
    text(img, (84, 196), "League of", 54, PAPER)
    text(img, (84, 258), "Explorers", 54, PAPER)
    text(img, (86, 344), "AN EXPLORATION ADDON", 14, MUTED, tracking=3)
    text(img, (86, 368), "FOR WOW FOREVER", 14, MUTED, tracking=3)

    img.convert("RGB").save(os.path.join(HERE, "banner.jpg"), quality=93)


def icon():
    S = 400
    img = Image.new("RGBA", (S, S), PANEL + (255,))
    # The book's pages along the top, and the six bookmarks out of them.
    top = 64
    w, gap = 46, 10
    x = (S - (6 * w + 5 * gap)) // 2
    for i, c in enumerate(RIBBONS):
        h = (316, 280, 340, 298, 268, 306)[i]
        img.alpha_composite(ribbon(w, h, c), (x, top - 20))
        x += w + gap
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, S, top), fill=PAPER + (255,))
    # The page block's edge: fine lines along the bottom of the pages.
    for k, y in enumerate((top - 14, top - 9, top - 4)):
        d.line((0, y, S, y), fill=(196, 180, 150, 255), width=1)
    d.line((0, top, S, top), fill=(120, 98, 72, 255), width=2)
    img.convert("RGB").save(os.path.join(HERE, "icon.png"))


if __name__ == "__main__":
    banner()
    icon()
    print("banner.jpg, icon.png")
