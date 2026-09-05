from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024


def gradient(c1, c2):
    img = Image.new("RGB", (SIZE, SIZE), c1)
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x + y) / (2 * (SIZE - 1))
            px[x, y] = tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3))
    return img


def rounded_mask(radius=210):
    m = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle((30, 30, SIZE-30, SIZE-30), radius=radius, fill=255)
    return m


def save_screen_bridge(path: Path):
    base = gradient((8, 19, 70), (40, 40, 220))
    mask = rounded_mask()
    canvas = Image.new("RGB", (SIZE, SIZE), (3, 7, 28))
    canvas.paste(base, mask=mask)
    glow = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    g = ImageDraw.Draw(glow)
    g.rounded_rectangle((175, 225, 850, 730), radius=70, outline=(180,220,255,255), width=22)
    g.arc((225, 520, 800, 920), 205, 335, fill=(90,235,255,255), width=34)
    g.ellipse((220, 675, 300, 755), fill=(110,245,255,255))
    g.ellipse((725, 675, 805, 755), fill=(190,150,255,255))
    cx, cy = 512, 480
    star = [(cx, cy-95),(cx+28,cy-28),(cx+95,cy),(cx+28,cy+28),(cx,cy+95),(cx-28,cy+28),(cx-95,cy),(cx-28,cy-28)]
    g.polygon(star, fill=(245,250,255,255))
    blur = glow.filter(ImageFilter.GaussianBlur(22))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), blur)
    canvas = Image.alpha_composite(canvas, glow)
    canvas.convert("RGB").save(path, "PNG", optimize=True)


def save_layout(path: Path):
    base = gradient((5, 36, 110), (0, 210, 220))
    mask = rounded_mask()
    canvas = Image.new("RGB", (SIZE, SIZE), (3, 10, 35))
    canvas.paste(base, mask=mask)
    layer = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    d = ImageDraw.Draw(layer)
    panels = [
        (190, 220, 525, 505),
        (565, 220, 810, 505),
        (190, 545, 405, 790),
        (445, 545, 810, 790),
    ]
    for i, rect in enumerate(panels):
        fill = (165,225,255,205) if i == 1 else (175,205,235,150)
        outline = (210,255,255,255) if i == 1 else (215,235,255,190)
        d.rounded_rectangle(rect, radius=42, fill=fill, outline=outline, width=10)
    glow = layer.filter(ImageFilter.GaussianBlur(22))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), glow)
    canvas = Image.alpha_composite(canvas, layer)
    canvas.convert("RGB").save(path, "PNG", optimize=True)


screen = ROOT / "companions/ScreenBridge/App/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png"
layout = ROOT / "companions/LayoutManager/App/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png"
screen.parent.mkdir(parents=True, exist_ok=True)
layout.parent.mkdir(parents=True, exist_ok=True)
save_screen_bridge(screen)
save_layout(layout)
print(screen)
print(layout)
