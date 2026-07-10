from ultralytics import YOLO
import time
import sys

while True:
    try:
        model = YOLO('doclayout_yolo_docstructbench_imgsz1024.pt')
        print(model.names)
        break
    except Exception as e:
        print("Waiting for download to finish...")
        time.sleep(2)
