# TODO

- Resolve the TODOs in the source code.
- Add an example of ressource usage and accuracy/loss for one example model.

## Testing

- Fix the failing models, which are commented in `code/vhdl/sim/vunit/top/run.py`.
- Use a second simulator, f. e. modelsim or nvc.
- Use jenkins or similar CI.
- Add more tests.
- add code coverage
- add ci
  - ./run_static_checks.sh
  - cd /home/workspace/picocnn/code/vhdl/sim/vunit && ./run_all.py -p4
  - fix "NUMERIC_STD.TO_SIGNED: vector truncated" warnings
  - consider generics as namedtuple/dataclass
- onnxruntime:
  - Extend the software inference by onnxruntime. This allows to have another sanity check. Currently INT activations and UINT weigths are not supported, which makes onnxruntime not usable. See also <https://github.com/microsoft/onnxruntime/issues/2964>. Fast check can be done with: `python3 -c 'import onnxruntime as rt; import numpy as np; sess = rt.InferenceSession("cnn_model.onnx"); input_name = sess.get_inputs()[0].name; test = np.ones((1, 1, 6, 6)); pred_onnx = sess.run(None, {input_name: test.astype(np.float32)})[0]; print(pred_onnx)'`.
  - Inspect if the existing tooling is useful: <https://github.com/microsoft/onnxruntime/blob/master/onnxruntime/python/tools/quantization/README.md>

## HDL

- Document the communication protocol (get, rdy, valid). Consider using fixed latencies instead.
- Add more layers:
  - fully connected layer
  - fc
  - fire layer (squeezenet)
  - flatten
  - 2x2 avg pool (local, global)
  - softmax
  - tanh activation
  - 5x5 convolution
  - batchnorm
  - stem, inception, resnet
- try to focus on a "bigger" net, like lenet/squeezenet/mobilenet
- Check if CE is correctly implemented and useful at all. See <http://arantxa.ii.uam.es/~ivan/spl12-clock-gating.pdf>.
- document used and possibly useful parallelism:
  - inter kernel parallelism -> not possible, because kernel have to be applied pixel by pixel
  - inter layer parallelism -> implemented as a pipeline
  - inter output parallelism -> implemented; apply multiple kernel to the same roi (also used at maximum pooling)
  - intra kernel parallelism -> implemented; calculate all kernel multiplications at the same time (C_PARALLEL=1: all mult; C_PARALLEL=0: only all mult of one channel)
- consider redesign of the toplevel generics, requirements:
  - readability (layerwise structure?)
  - compatibility to json for vunit tests
  - compatibility to vhdl wrapper for synth

## CNN Frameworks

- Add an example, which contains the full workflow:
  - Pytorch/Tensorflow/... training
  - Exporting to ONNX
  - Modifying/quantizing the model according to the HDL requirements
  - Generating the hardware description with picocnn
- Add a script, which converts an ONNX model to an ONNX model, which can be synthesized:
  - Document the requirements/limitations:
    - bitwidth/scale: limit to 2^x values or extend vhdl framework?
    - add support of offset?