from PIL import Image, ImageDraw
from math import cos, sin, pi
from pathlib import Path

size = 1024
image = Image.new("RGB", (size, size), (16, 20, 29))
draw = ImageDraw.Draw(image)

# A seven-point plate on a warm coral field echoes the weekly rhythm.
draw.rounded_rectangle((48, 48, 976, 976), radius=235, fill=(255, 99, 74))
draw.ellipse((180, 180, 844, 844), fill=(19, 25, 36))
draw.ellipse((248, 248, 776, 776), fill=(202, 240, 92))
for index in range(7):
    angle = -pi / 2 + index * 2 * pi / 7
    x = 512 + 205 * cos(angle)
    y = 512 + 205 * sin(angle)
    draw.ellipse((x - 20, y - 20, x + 20, y + 20), fill=(19, 25, 36))
draw.rounded_rectangle((462, 340, 562, 684), radius=48, fill=(19, 25, 36))
draw.ellipse((406, 306, 618, 490), fill=(19, 25, 36))

asset = Path(__file__).resolve().parent.parent / "Weekplate" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
asset.mkdir(parents=True, exist_ok=True)
image.save(asset / "AppIcon.png")
