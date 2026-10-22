# Research Notes

This directory documents the engineering interpretation of Plate-style HRR and the practical behavior of the implementation.

## Core definitions

The implementation follows the standard HRR operations:

- Binding: circular convolution
- Approximate unbinding: circular correlation
- Memory: superposition of multiple bound pairs
- Retrieval: cue-driven correlation followed by cleanup

## Why this matters

HRR provides a way to encode relationships and distributed structures into a fixed number of components without explicit per-slot indexing. This makes it attractive for associative memory tasks that benefit from compositionality, modest memory load, and approximate retrieval.

However, the system still depends on vector dimensionality and does not remove the need for physical storage or indexing in exact-match workloads.

## Practical limits

- retrieval degrades as the number of superposed associations grows
- partial damage produces noisy reconstruction
- cleanup is necessary to distinguish symbol candidates
- correlation is approximate, not a guaranteed exact inverse

## Benchmark intent

The benchmarking goals are to measure:

- recovery quality as function of dimension
- interference growth under superposition
- corruption tolerance
- direct-vs-FFT numerical agreement
- memory capacity before retrieval fails

These measurements are designed to remain reproducible across runs and architectures.

## Documents in this directory

- `HYDRA.md` — the PROJECT HYDRA design: pipeline, chamber,
  optical model, language architecture, and the honesty contract
  for simulated data.
- `hydra-results.md` — every measured result for the HYDRA
  layers, with the raw logs under `results/`.
- The benchmark measurements themselves live in `benchmarks/`
  (harness) and `results/benchmark.txt` (output).
