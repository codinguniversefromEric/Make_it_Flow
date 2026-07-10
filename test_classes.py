from ultralytics import YOLO
model = YOLO('yolo_docstructbench_imgsz1024.pt')
print(model.names)
