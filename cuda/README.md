# CUDA

`hrr_kernels.cu` is the GPU implementation of the engine's
arithmetic in double precision: direct circular convolution and
correlation kernels, superposition accumulation, block-reduction
dot products for cleanup, and an FFT convolution path (bit-reversal
kernel plus one butterfly launch per stage, mirroring the CPU FFT).

The host driver in the same file is self-verifying. It checks the
GPU direct convolution against a CPU direct convolution and the
GPU FFT convolution against both, then runs the retrieval
experiment (D = 1024, 16-symbol codebook, 4 superposed bindings)
and prints recovered symbols with cosines, exiting nonzero unless
all bindings are recovered.

Build and run (requires a CUDA toolkit and a GPU):

```bash
make
./hrr_kernels
```

The codebook recipe (double-precision LCG, modulus 2^32,
multiplier 1664525, Box-Muller, unit-normalized columns) matches
the Fortran and MATLAB layers so results are comparable across
implementations. The Makefile targets sm_70, sm_80 and sm_87;
override `ARCH` for other devices.

Execution status: this sandbox has no GPU, so the program is
delivered as complete source; it is compiled with nvcc wherever a
toolkit is available and run on any CUDA device. The CPU layers
(Fortran, Rust+WAT) carry the measured results in
`docs/hydra-results.md`.
