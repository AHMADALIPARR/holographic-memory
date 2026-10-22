# Holographic Memory Engine

A native Rust implementation of a holographic reduced representation (HRR) engine for associative memory experiments, cleanup, and reproducible demos.

## Overview

This project models compact fixed-width associative memory using:

- circular convolution for binding
- circular correlation for approximate unbinding
- superposition for storage
- nearest-neighbor cosine cleanup for retrieval

## Build

```bash
cargo build --release
cargo run --release
```

## Repository structure

```text
holographic-memory/
├── Cargo.toml
├── README.md
├── src/
│   ├── lib.rs
│   ├── main.rs
│   ├── vector.rs
│   ├── convolution.rs
│   ├── correlation.rs
│   ├── superposition.rs
│   ├── cleanup.rs
│   ├── encoder.rs
│   └── memory.rs
├── formal/
│   └── Convolution.lean
├── reference/
│   └── hrr_reference.f90
├── docs/
│   └── results.md
└── examples/
    └── demo.txt
```

## Notes

This is a research-oriented prototype for fixed-width symbolic memory. It demonstrates approximate retrieval under moderate load and includes explicit measurement-style outputs, but it is not intended to replace conventional index-based systems for arbitrary workloads.
