from ultralytics import YOLO
model = YOLO("yolov10s_best.pt")
results = model("test_img.png")
for r in results:
    for box in r.boxes:
        print(f"Class: {r.names[int(box.cls)]}, Conf: {box.conf.item():.2f}, Box: {box.xyxy.tolist()}")
