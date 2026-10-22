# Benchmarks

`bench_driver.f90` is the benchmark harness. It runs against the
shipped Fortran kernels (`fortran/hydra_kernels.f90`) and uses the
same codebook recipe as `fortran/hydra_driver.f90`. Timing is
`cpu_time`, median of 5 repetitions.

Build and run (from the repository root):

```bash
gfortran-13 -O2 -o /tmp/hydra_bench fortran/hydra_kernels.f90 benchmarks/bench_driver.f90 /lib/x86_64-linux-gnu/libblas.so.3 /lib/x86_64-linux-gnu/liblapack.so.3
/tmp/hydra_bench
```

Measured output is kept in `results/benchmark.txt`. The harness
covers:

1. Direct O(n^2) convolution versus the chirp-z `hrr_bind`
   (at n = 4096: 27.3 ms direct, 0.76 ms chirp-z).
2. Capacity sweep at D = 10000: every binding recovered up to 32
   superposed bindings; mean cleanup cosine decays from 0.449 at
   4 bindings to 0.175 at 32, tracking the 1/sqrt(bindings) law.
3. Corruption sweep at D = 1024 with 4 bindings: cleanup still
   recovers 4/4 with 75% of the trace zeroed. The 100% row is the
   degenerate zero-trace case (recovered 0; the -2.0 cosine is
   cleanup_search's no-signal sentinel).
