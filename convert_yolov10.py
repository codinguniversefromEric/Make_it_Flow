from ultralytics import YOLO
import coremltools as ct
model = YOLO("yolov10s_best.pt")
model.export(format="coreml", imgsz=1024)
