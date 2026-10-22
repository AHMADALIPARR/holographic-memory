NVCC ?= nvcc
ARCH ?= -gencode arch=compute_70,code=sm_70 -gencode arch=compute_80,code=sm_80 -gencode arch=compute_87,code=sm_87
NVCCFLAGS ?= -O3 -std=c++17 $(ARCH)

hrr_kernels: hrr_kernels.cu
	$(NVCC) $(NVCCFLAGS) -o $@ $<

run: hrr_kernels
	./hrr_kernels

clean:
	rm -f hrr_kernels

.PHONY: run clean
