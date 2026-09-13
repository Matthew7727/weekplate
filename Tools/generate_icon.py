from PIL import Image, ImageDraw
from pathlib import Path

asset = Path(__file__).resolve().parent.parent / "Weekplate" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
asset.mkdir(parents=True, exist_ok=True)

def make_icon(background, base, filename):
    image = Image.new("RGB", (size, size), background)
    draw = ImageDraw.Draw(image)
    # Seven hard-edged bars represent the days of a planned week. Two accent
    # bars make the mark recognisable at small sizes without illustration.
    bars = [base, (20, 56, 196), base, (222, 20, 63), base, base, base]
    left, right = 150, 874
    # Keep the mark optically centred in the square icon.
    top, bar_height, gap = 110, 78, 42
    for index, colour in enumerate(bars):
        y = top + index * (bar_height + gap)
        draw.rectangle((left, y, right, y + bar_height), fill=colour)
    image.save(asset / filename)

size = 1024
make_icon((247, 243, 231), (18, 27, 48), "AppIcon.png")
make_icon((9, 15, 32), (239, 241, 246), "AppIcon-dark.png")
