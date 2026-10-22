# Benchmarking Notes

This directory is intended for measurement harnesses, timing logs, and result artifacts.

## Planned measurements

1. Direct convolution versus FFT convolution
2. Retrieval quality versus vector dimension
3. Cleanup quality against corruption ratio
4. Capacity sweep under increasing memory load
5. Optional hardware metadata collection

## Recommended output format

Each benchmark should log:

- dimension
- binding count
- corruption ratio
- retrieval accuracy
- average cosine similarity
- runtime in milliseconds
- direct/FFT delta

The implementation in the core Rust crate is intended to be benchmarkable without external Python dependencies.
