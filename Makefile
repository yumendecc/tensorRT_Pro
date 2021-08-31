
cpp_srcs := $(shell find src -name "*.cpp")
cpp_objs := $(cpp_srcs:.cpp=.o)
cpp_objs := $(cpp_objs:src/%=objs/%)
cpp_mk   := $(cpp_objs:.o=.mk)

cu_srcs := $(shell find src -name "*.cu")
cu_objs := $(cu_srcs:.cu=.cuo)
cu_objs := $(cu_objs:src/%=objs/%)
cu_mk   := $(cu_objs:.cuo=.cumk)

# 配置你的库路径
# 1. onnx-tensorrt（项目集成了，不需要配置，下面地址是下载位置）
#    https://github.com/onnx/onnx-tensorrt/tree/release/8.0
# 2. protobuf（请自行下载编译）
#    https://github.com/protocolbuffers/protobuf/tree/v3.11.4
# 3. cudnn8.2.2.26（请自行下载）
#    runtime的tar包，runtime中包含了lib、so文件
#    develop的tar包，develop中包含了include、h等文件
# 4. tensorRT-8.0.1.6-cuda10.2（请自行下载）
#    tensorRT下载GA版本（通用版、稳定版），EA（尝鲜版本）不要
# 5. cuda10.2，也可以是11.x看搭配（请自行下载安装）

lean_protobuf  := /data/sxai/lean/protobuf3.11.4
lean_tensor_rt := /data/sxai/lean/TensorRT-8.0.1.6
lean_cudnn     := /data/sxai/lean/cudnn8.2.2.26
lean_opencv    := /data/sxai/lean/opencv4.2.0
lean_cuda      := /data/sxai/lean/cuda10.2
lean_python    := /data/datav/newbb/lean/anaconda3/envs/torch1.8
use_python     := false

include_paths := src        \
			src/application \
			src/tensorRT	\
			src/tensorRT/common  \
			$(lean_protobuf)/include \
			$(lean_opencv)/include/opencv4 \
			$(lean_tensor_rt)/include \
			$(lean_cuda)/include  \
			$(lean_cudnn)/include 

library_paths := $(lean_protobuf)/lib \
			$(lean_opencv)/lib    \
			$(lean_tensor_rt)/lib \
			$(lean_cuda)/lib  \
			$(lean_cudnn)/lib 

link_librarys := opencv_core opencv_imgproc opencv_videoio opencv_imgcodecs \
			nvinfer nvinfer_plugin nvparsers \
			cuda curand cublas cudart cudnn \
			stdc++ protobuf dl


# 如果要支持FP16的插件推理（非插件不需要），请在编译选项上加-DHAS_CUDA_HALF，CPP和CU都加
# 这种特殊的宏可以在.vscode/c_cpp_properties.json文件中configurations下的defines中也加进去，使得看代码的时候
# 效果与编译一致
# HAS_PYTHON表示是否编译python支持
# support_define    := -DHAS_CUDA_HALF
support_define    := -DHAS_CUDA_HALF

ifeq ($(use_python), true) 
include_paths  += $(lean_python)/include/python3.9
library_paths  += $(lean_python)/lib
link_librarys  += python3.9
support_define += -DHAS_PYTHON
endif

run_paths     := $(foreach item,$(library_paths),-Wl,-rpath=$(item))
include_paths := $(foreach item,$(include_paths),-I$(item))
library_paths := $(foreach item,$(library_paths),-L$(item))
link_librarys := $(foreach item,$(link_librarys),-l$(item))

cpp_compile_flags := -std=c++11 -fPIC -m64 -g -fopenmp -w -O0 $(support_define)
cu_compile_flags  := -std=c++11 -m64 -Xcompiler -fPIC -g -w -gencode=arch=compute_75,code=sm_75 -O0 $(support_define)
link_flags        := -pthread -fopenmp

cpp_compile_flags += $(include_paths)
cu_compile_flags  += $(include_paths)
link_flags 		  += $(library_paths) $(link_librarys) $(run_paths)

ifneq ($(MAKECMDGOALS), clean)
-include $(cpp_mk) $(cu_mk)
endif

pro    : workspace/pro
trtpyc : python/trtpy/trtpyc.so

workspace/pro : $(cpp_objs) $(cu_objs)
	@echo Link $@
	@mkdir -p $(dir $@)
	@g++ $^ -o $@ $(link_flags)

python/trtpy/trtpyc.so : $(cpp_objs) $(cu_objs)
	@echo Link $@
	@mkdir -p $(dir $@)
	@g++ -shared $^ -o $@ $(link_flags)

objs/%.o : src/%.cpp
	@echo Compile CXX $<
	@mkdir -p $(dir $@)
	@g++ -c $< -o $@ $(cpp_compile_flags)

objs/%.cuo : src/%.cu
	@echo Compile CUDA $<
	@mkdir -p $(dir $@)
	@nvcc -c $< -o $@ $(cu_compile_flags)

objs/%.mk : src/%.cpp
	@echo Compile depends CXX $<
	@mkdir -p $(dir $@)
	@g++ -M $< -MF $@ -MT $(@:.mk=.o) $(cpp_compile_flags)
	
objs/%.cumk : src/%.cu
	@echo Compile depends CUDA $<
	@mkdir -p $(dir $@)
	@nvcc -M $< -MF $@ -MT $(@:.cumk=.o) $(cu_compile_flags)

run_yolo : workspace/pro
	@cd workspace && ./pro yolo

run_alphapose : workspace/pro
	@cd workspace && ./pro alphapose

run_fall : workspace/pro
	@cd workspace && ./pro fall_recognize

run_retinaface : workspace/pro
	@cd workspace && ./pro retinaface

run_arcface    : workspace/pro
	@cd workspace && ./pro arcface

run_arcface_video    : workspace/pro
	@cd workspace && ./pro arcface_video

run_arcface_tracker    : workspace/pro
	@cd workspace && ./pro arcface_tracker

run_test_all : workspace/pro
	@cd workspace && ./pro test_all

run_scrfd : workspace/pro
	@cd workspace && ./pro scrfd

run_pytorch : trtpyc
	@cd python && python test_torch.py

run_pyscrfd : trtpyc
	@cd python && python test_scrfd.py

run_pyretinaface : trtpyc
	@cd python && python test_retinaface.py

run_pyyolov5 : trtpyc
	@cd python && python test_yolov5.py

run_pyyolox : trtpyc
	@cd python && python test_yolox.py

debug :
	@echo $(includes)

clean :
	@rm -rf objs workspace/pro python/trtpy/trtpyc.so

.PHONY : clean run_yolo run_alphapose run_fall debug