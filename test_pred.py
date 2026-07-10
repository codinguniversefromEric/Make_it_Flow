from ultralytics import YOLO
model = YOLO("Flow_1/models/yolov11s-doclaynet.mlpackage")
from PIL import Image, ImageDraw, ImageFont
img = Image.new('RGB', (1024, 1024), color='white')
d = ImageDraw.Draw(img)
d.text((100, 100), "This is a big title that should be detected as text or title", fill=(0,0,0))
d.text((100, 150), "Here is a paragraph of text. " * 20, fill=(0,0,0))
img.save("test_img.png")

results = model("test_img.png", imgsz=1024)
for r in results:
    print("Boxes:", r.boxes.xyxy)
    print("Confs:", r.boxes.conf)
    print("Cls:", r.boxes.cls)
