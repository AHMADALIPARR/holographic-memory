# Holographic Memory Engine

Plate-style holographic reduced representations (HRR) for
distributed associative memory, plus PROJECT HYDRA: a
water-modulated holographic cryptography pipeline built on the
same algebra. Design and honesty contract for HYDRA are in
`docs/HYDRA.md`; every measured number is in
`docs/hydra-results.md` with raw logs under `results/`.

## The engine

The Rust crate is the functor layer: `Vector` over f64, the
operations `bind_role_filler`, `approximate_unbind`,
`superimpose`, `encode_sequence`, nearest-neighbor `cleanup`,
deterministic codebook generation, and `Memory` (store/retrieve).
All bulk arithmetic — circular convolution, circular correlation,
the FFT convolution path, dot products, accumulation — lives in a
hand-written WebAssembly text module, `wasm/hrr_kernels.wat`
(247 lines, 1,382 bytes compiled), embedded in the crate and run
by a wasmi host. The WAT mirrors the original Rust kernels
operation for operation; the demo output is bit-identical to the
pure-Rust version it replaced.

```bash
cargo build --release
cargo test --release            # 5 tests, all passing
cargo run --release             # experiment harness
cargo run --release --example assoc_memory
```

Typical harness output (measured, this code):

```text
4 bindings stored in dim=1024
Recovered bindings: [(symbol_1, 0.4164), (symbol_2, 0.4606),
                     (symbol_1, 0.4505), (symbol_2, 0.4493)]
25% component zeroing: recovery cosine 0.675
Capacity probe: 10 bindings in dim=512, 5/10 after cleanup
Direct and FFT-path convolutions agree within 2.05e-12
```

## HYDRA layers

- `fortran/` — Fortran 2018 kernels (chirp-z convolution at
  D = 10000, 8/8 bindings recovered; angular-spectrum propagation
  conserving intensity) with BLAS/LAPACK, the full cryptographic
  protocol (SHA-256, HKDF, ChaCha20-Poly1305; all published test
  vectors pass; replay and tamper rejected), and an entropy
  assessment of simulated optical sessions against a CSPRNG
  baseline. Drivers print their results; logs in `results/`.
- `matlab/` — the holographic watermark: a 32-bit payload embedded
  globally in a simulated detector frame. Measured BER 0.000
  clean, 0.000 after the frame is cut in half, 0.000 after
  16-level requantization, 0.062 under noise. All files are
  functions; run `hydra_wm_demo()` in MATLAB or Octave.
- `idl/` — the optical pipeline (phase screen, propagation,
  session experiment) in IDL, executed under GDL 1.0.4 with the
  same conservation results as the Fortran path.
- `ada/` — the bounded session-control logic in Ada/SPARK style
  with contracts enforced at runtime (GNAT, `-gnata`): fresh
  challenge accepted, replay rejected, nonce exhaustion forces
  rekey. No counter wrap.
- `formal/` — Lean 4 formalization. `formal/hydra/HydraSpec.lean`
  is core-only and kernel-checked (no `sorry`);
  `Convolution.lean`, `Correlation.lean` and `MemoryLaws.lean`
  carry the Mathlib-based algebra: corrected modular indexing,
  distributivity, delta identities, commutativity and
  associativity of circular convolution, the correlation
  involution law, and the superposition laws.
- `cuda/` — the GPU implementation (double precision, direct and
  FFT convolution, self-verifying driver). Complete source;
  requires a CUDA device to run.
- `benchmarks/` — a Fortran harness (direct vs chirp-z timing,
  capacity sweep to 32 bindings at D = 10000, corruption sweep);
  measured output in `results/benchmark.txt`.
- `reference/` — the original Fortran reference implementation.

## Research framing

This implementation follows the core HRR idea: information is
distributed across vector components rather than stored in
explicit locations. The engine demonstrates approximate recovery
under noise and interference, which is a key property of
distributed memory models.

It does not claim universal invertibility or superiority over
conventional exact indexing systems. Instead, it provides a
deterministic, measurable implementation suitable for studying
associative retrieval under controlled conditions. HYDRA's
optical data is simulated and labeled as such wherever it
appears; the documents state plainly what is demonstrated and
what is not.

## License

Dual licensed: AGPL-3.0-only (`LICENSE`) and the SnapKitty
Opaque Source License v1.0 (`SNAPKITTY_OPAQUE_LICENSE.md`).
