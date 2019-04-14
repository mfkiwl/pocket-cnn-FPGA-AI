# configure variables for cpu/gpu use
GPU=1
if ((GPU == 1)); then
	PRE=optirun
	GPU_NR=--gpu=0
else
	PRE=""
	GPU_NR=""
fi

DEBUG=0

# root directories of used programs
CAFFE_RISTRETTO_ROOT=/home/prog/caffe_ristretto
COCOTB_ROOT=/home/prog/cocotb

# cnn framework (caffe or pytorch)
CNN_FW=caffe

# root directory of the cnn model
CNN_DIR=/home/workspace/opencnn/cnn_models/tests/test_net_1

# root directory of the CNN VHDL files
VHDL_DIR="$PWD/VHDL/src"
TEST_FILES="$PWD/../test_images/*.p*"

# finds latest file that matches pattern $1
function find_latest {
	unset -v latest
	for file in $1; do
		[[ $file -nt $latest ]] && latest="$file"
	done
}

# TODO: should this be moved to the config?
if [ "$CNN_FW" = "caffe" ]; then
	# TODO: run caffe(-ristretto) training from python script
	# https://stackoverflow.com/questions/32379878/cheat-sheet-for-caffe-pycaffe
	# would simplify first workflow steps
	# full precision
	MODEL_FULL="$CNN_DIR/caffe/train_val.prototxt"
	find_latest "$CNN_DIR/caffe/*.caffemodel"
	WEIGHTS_FULL="$latest"
	# quantized
	MODEL_QUANT="$CNN_DIR/caffe_ristretto/ristretto_quantized.prototxt"
	SOLVER_QUANT="$CNN_DIR/caffe_ristretto/ristretto_solver.prototxt"
	find_latest "$CNN_DIR/caffe_ristretto/finetune/*.caffemodel"
	WEIGHTS_QUANT="$latest"
elif [ "$CNN_FW" = "pytorch" ]; then
	# full precision
	MODEL_FULL="$CNN_DIR/pytorch/train.pt"
	WEIGHTS_FULL="$CNN_DIR/pytorch/train.pt"
	# quantized
	MODEL_QUANT="$CNN_DIR/pytorch/quant.pt"
	SOLVER_QUANT="$CNN_DIR/pytorch/quant.pt"
	WEIGHTS_QUANT="$CNN_DIR/pytorch/quant.pt"
fi