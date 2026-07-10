import fitz # PyMuPDF
from ultralytics import YOLO

doc = fitz.open("sample.pdf")
page = doc.load_page(0)
pix = page.get_pixmap()
pix.save("sample_page0.png")

model = YOLO("yolov10s_best.pt")
results = model("sample_page0.png")
for r in results:
    for box in r.boxes:
        print(f"Class: {r.names[int(box.cls)]}, Conf: {box.conf.item():.2f}")
