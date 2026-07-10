from ultralytics import YOLO
model = YOLO("yolov11s-doclaynet.pt")
model.export(format="coreml", nms=False, imgsz=1024)
