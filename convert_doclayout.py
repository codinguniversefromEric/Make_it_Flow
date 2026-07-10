from ultralytics import YOLO
model = YOLO("doclayout_yolo_docstructbench_imgsz1024.pt")
model.export(format="coreml", imgsz=1024)
