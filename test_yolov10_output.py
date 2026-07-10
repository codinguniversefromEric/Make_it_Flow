import coremltools as ct
from PIL import Image
import numpy as np

m = ct.models.MLModel('yolov10s_best.mlpackage')
img = Image.open('sample_page0.png').resize((1024, 1024))
out = m.predict({'image': img})
out_key = list(out.keys())[0]
tensor = out[out_key]
print("Shape:", tensor.shape)
for i in range(5):
    print("Box", i, tensor[0, i, :])
