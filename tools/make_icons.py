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
    d.rounded_rectangle((30, 30, SIZE - 30, SIZE - 30), radius=radius, fill=255)
    return m


def icon_canvas(c1, c2):
    base = gradient(c1, c2)
    mask = rounded_mask()
    canvas = Image.new("RGB", (SIZE, SIZE), (3, 7, 28))
    canvas.paste(base, mask=mask)
    return canvas.convert("RGBA")


def save_screen_bridge(path: Path):
    canvas = icon_canvas((8, 19, 70), (40, 40, 220))
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.rounded_rectangle((175, 225, 850, 730), radius=70, outline=(180, 220, 255, 255), width=22)
    g.arc((225, 520, 800, 920), 205, 335, fill=(90, 235, 255, 255), width=34)
    g.ellipse((220, 675, 300, 755), fill=(110, 245, 255, 255))
    g.ellipse((725, 675, 805, 755), fill=(190, 150, 255, 255))
    cx, cy = 512, 480
    star = [(cx, cy - 95), (cx + 28, cy - 28), (cx + 95, cy), (cx + 28, cy + 28),
            (cx, cy + 95), (cx - 28, cy + 28), (cx - 95, cy), (cx - 28, cy - 28)]
    g.polygon(star, fill=(245, 250, 255, 255))
    canvas = Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(22)))
    canvas = Image.alpha_composite(canvas, glow)
    canvas.convert("RGB").save(path, "PNG", optimize=True)


def save_layout(path: Path):
    canvas = icon_canvas((5, 36, 110), (0, 210, 220))
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    panels = [
        (190, 220, 525, 505),
        (565, 220, 810, 505),
        (190, 545, 405, 790),
        (445, 545, 810, 790),
    ]
    for i, rect in enumerate(panels):
        fill = (165, 225, 255, 205) if i == 1 else (175, 205, 235, 150)
        outline = (210, 255, 255, 255) if i == 1 else (215, 235, 255, 190)
        d.rounded_rectangle(rect, radius=42, fill=fill, outline=outline, width=10)
    canvas = Image.alpha_composite(canvas, layer.filter(ImageFilter.GaussianBlur(22)))
    canvas = Image.alpha_composite(canvas, layer)
    canvas.convert("RGB").save(path, "PNG", optimize=True)


def save_observer(path: Path):
    canvas = icon_canvas((10, 16, 54), (72, 20, 150))
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # Eye / observer symbol
    d.arc((175, 245, 849, 720), 205, 335, fill=(175, 235, 255, 255), width=30)
    d.arc((175, 245, 849, 720), 25, 155, fill=(175, 235, 255, 255), width=30)
    d.ellipse((390, 365, 634, 609), fill=(70, 210, 255, 235), outline=(235, 250, 255, 255), width=18)
    d.ellipse((465, 440, 559, 534), fill=(12, 24, 70, 255))
    d.ellipse((492, 462, 524, 494), fill=(255, 255, 255, 245))

    # Activity pulse and tiny text bars to hint at local pattern learning
    d.line((245, 760, 350, 760, 400, 700, 465, 820, 535, 735, 590, 760, 790, 760),
           fill=(120, 255, 220, 255), width=22, joint="curve")
    for y, w in [(180, 220), (820, 180)]:
        d.rounded_rectangle((402, y, 402 + w, y + 18), radius=9, fill=(210, 205, 255, 180))

    glow = layer.filter(ImageFilter.GaussianBlur(28))
    canvas = Image.alpha_composite(canvas, glow)
    canvas = Image.alpha_composite(canvas, layer)
    canvas.convert("RGB").save(path, "PNG", optimize=True)


screen = ROOT / "companions/ScreenBridge/App/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png"
layout = ROOT / "companions/LayoutManager/App/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png"
observer = ROOT / "companions/Observer/App/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png"
for target in (screen, layout, observer):
    target.parent.mkdir(parents=True, exist_ok=True)

save_screen_bridge(screen)
save_layout(layout)
save_observer(observer)
print(screen)
print(layout)
print(observer)
