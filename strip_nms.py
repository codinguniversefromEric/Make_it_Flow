import coremltools as ct

m = ct.models.MLModel('Flow_1/models/yolov11s-doclaynet.mlpackage')
spec = m.get_spec()

# Extract the mlProgram model from the pipeline
ml_program = spec.pipeline.models[0]

# Create a new specification with just the mlProgram
new_spec = ct.proto.Model_pb2.Model()
new_spec.CopyFrom(ml_program)

# Save as a new mlpackage
new_m = ct.models.MLModel(new_spec, weights_dir=m.weights_dir)
new_m.save('Flow_1/models/yolov11s-doclaynet-nonms.mlpackage')
print("Saved without NMS")
