# Holographic Memory Engine

A native Rust implementation of Plate-style HRR for distributed associative memory.

## Overview

The project provides a compact, native HRR engine with:

- fixed-width vector representation
- circular convolution for binding
- circular correlation for approximate unbinding
- superposition memory
- nearest-neighbor cleanup using cosine similarity
- role-filler encoded associations and ordered sequences
- deterministic vector generation for reproducible experiments
- FFT convolution validation and direct convolution comparison

This implementation is written in native Rust and does not depend on Python, NumPy, Node.js, or other runtime ecosystems.

## Build and run

```bash
cargo build --release
cargo run --release
```

## Test

```bash
cargo test -- --nocapture
```

## Research framing

This implementation follows the core HRR idea: information is distributed across vector components rather than stored in explicit locations. The engine demonstrates approximate recovery under noise and interference, which is a key property of distributed memory models.

It does not claim universal invertibility or superiority over conventional exact indexing systems. Instead, it provides a deterministic, measurable implementation suitable for studying associative retrieval under controlled conditions.

## Structure

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

## Typical runtime output

```text
4 bindings stored in dim=1024; cleaned retrievals return the highest-similarity symbols (interference visible, as expected).
Recovered bindings: [("symbol_0", 0.9721), ...]
25% component zeroing: recovery cosine ≈ 0.678.
Capacity probe: 10 bindings in dim=512 → 10/10 correct after cleanup.
Direct and FFT-path convolutions agree within 1.0e-10.
```

The exact scores vary slightly with deterministic generation and vector size, but the qualitative behavior is stable: retrieval works under moderate load, interference rises with storage pressure, and cleanup recovers the most likely symbol.
