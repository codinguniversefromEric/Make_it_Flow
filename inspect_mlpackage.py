import coremltools as ct
model1 = ct.models.MLModel("Flow_1/models/best_conf0.1.mlpackage")
print("best_conf0.1:")
print("Inputs:", model1.input_description)
print("Outputs:", model1.output_description)

model2 = ct.models.MLModel("Flow_1/models/yolov11s-doclaynet.mlpackage")
print("\nyolov11s-doclaynet:")
print("Inputs:", model2.input_description)
print("Outputs:", model2.output_description)
