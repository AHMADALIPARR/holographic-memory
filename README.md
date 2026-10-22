# Holographic Memory Engine

A native Rust implementation of a Plate-style holographic reduced representation (HRR) engine for associative memory experiments, cleanup, and reference correctness checks.

## Overview

This project implements a compact associative memory system built from high-dimensional vectors. The engine uses:

- circular convolution for binding
- circular correlation for approximate unbinding
- superposition to store multiple bindings in one memory vector
- cosine-based cleanup to recover the nearest symbol
- deterministic symbol generation for reproducible experiments

The implementation is native Rust and does not depend on Python, NumPy, or any JavaScript runtime.

## Build

```bash
cargo build --release
cargo run --release
```

## Tests

```bash
cargo test -- --nocapture
```

## Repository layout

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
│   ├── Convolution.lean
│   ├── Correlation.lean
│   └── MemoryLaws.lean
├── reference/
│   └── hrr_reference.f90
├── cuda/
│   └── README.md
├── benchmarks/
│   └── README.md
├── tests/
│   ├── README.md
│   └── hrr_core.rs
├── examples/
│   └── README.md
├── docs/
│   └── README.md
└── .gitignore
```

## Design notes

This engine is a focused research prototype. It demonstrates distributed associative encoding, approximate retrieval, and cleanup under moderate load. It is intentionally not presented as a universal replacement for conventional indexing systems, physical-address memory, or exact storage.

The central point is the tradeoff: fixed-width distributed representations are compositional and efficient to manipulate, but retrieval quality depends on dimensionality, noise, and the number of superimposed associations.
