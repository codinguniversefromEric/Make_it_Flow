from huggingface_hub import hf_hub_download
from ultralytics import YOLO
import shutil

print("Downloading model...")
model_path = hf_hub_download(repo_id="hantian/yolo-doclaynet", filename="yolov11s-doclaynet.pt")

print("Loading model...")
model = YOLO(model_path)

print("Exporting to CoreML...")
# export to coreml
model.export(format="coreml", nms=True, imgsz=1024)

print("Moving to models directory...")
import glob
import os
exported_model = glob.glob(os.path.dirname(model_path) + "/*.mlpackage")
if exported_model:
    shutil.copytree(exported_model[0], "Flow_1/models/yolov11s-doclaynet.mlpackage", dirs_exist_ok=True)
    print("Done!")
else:
    print("Failed to find exported .mlpackage")
