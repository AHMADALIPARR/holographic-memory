# HYDRA — Measured Results

All runs executed on the build VM (2 cores, 7 GB RAM) on 2026-10-22.
All optical data is SIMULATED (see docs/HYDRA.md for the honesty
contract). Raw logs are in `results/`.

## 1. HRR engine (Rust functor layer + WAT arithmetic kernels)

The crate's arithmetic now lives in `wasm/hrr_kernels.wat`,
executed by a wasmi host; the Rust layer keeps the functors and
f64 plumbing (owner's direction: assembly takes over, Rust keeps
the functors and f64). Verification that the takeover changed
nothing numerically: `cargo test --release` 5 passed, 0 failed,
and the demo output below is bit-identical to the pure-Rust run
(same 16 significant digits on every recovered binding; the FFT
agreement figure is unchanged at 2.05e-12).
`cargo run --release` (excerpt, full log in results/engine_run.txt):

```
4 bindings stored in dim=1024
Recovered bindings: [(symbol_1, 0.4164), (symbol_2, 0.4606),
                     (symbol_1, 0.4505), (symbol_2, 0.4493)]
25% component zeroing: recovery cosine 0.675
Capacity probe: 10 bindings in dim=512 -> 5/10 correct after cleanup
Direct and FFT-path convolutions agree within 2.05e-12
Role/filler binding similarity: 0.7208
```

Repairs (each labeled in source): missing rand trait import;
usize underflow in circular_convolution (wrong for non-power-of-two
dimensions); circular_correlation index convention plus two call
sites. Post-repair demo values match the pre-repair run to 13
decimals wherever the old code was correct.

## 2. Fortran kernels + BLAS/LAPACK (gfortran 13.3.0)

Log: results/fortran_run.txt.

- Reference check vs the repo's own reference/hrr_reference.f90:
  max_abs 30.2156140 (kernels, real64) vs 30.2156239 (reference,
  real32) — agreement to reference precision.
- HRR at D = 10000 (chirp-z circular convolution), 16-symbol
  codebook, 8 superposed bindings (DAXPY), cleanup by DGEMV:
  **8/8 fillers recovered**, cosine 0.326–0.344 (theory: ~1/sqrt(8)).
- Angular-spectrum propagation conserves mean intensity (1.00000)
  across sessions, as a unitary propagator must.

## 3. Fortran cryptography + protocol (gfortran 13.3.0)

Log: results/protocol_run.txt. Self-tests, all PASS:
SHA-256 (FIPS 180-4 "abc"), HKDF (RFC 5869 case 1), ChaCha20 block
(RFC 8439 A.1), Poly1305 (RFC 8439 2.5.2), AEAD tag + ciphertext +
round trip (RFC 8439 2.8.2).

Entropy assessment (24 simulated sessions, 24,576 quantized bytes;
identical statistics code for both rows):

```
optical(sim)  min-entropy/byte 7.642   lag-1 -0.0030   max bias 0.0011
CSPRNG        min-entropy/byte 7.642   lag-1 +0.0006   max bias 0.0011
```

These numbers describe the simulation pipeline only. The simulated
source is a deterministic generator: against an attacker who knows
the seed its entropy is zero, and no conditioning can change that.
The conditioning path (SHA-256 extract, HKDF, AEAD) is hygiene that
a physical source would still require.

Challenge–response: fresh challenge accepted and verified; replayed
challenge rejected; bit-flipped ciphertext rejected.

## 4. Holographic watermark (MATLAB, run under GNU Octave 10.3)

Log: results/watermark_matlab.txt. Simulated 128x128 host, 32-bit
payload, band 4,928 coefficients, embed PSNR 54.9 dB.

```
attack        BER     detector
clean         0.000   0.0577
crop-half     0.000   (least-squares detector, raw units)
noise         0.062   0.0243
quantize16    0.000   0.0438
wrong-key     0.375   0.0093 (control, at the noise floor)
```

Crop-half is the holographic property measured: the frame is cut in
half and the whole payload is still recovered. It took three
detector generations to earn — spectral correlator BER 0.469,
mask-aware matched filter 0.312, joint least squares with a
low-frequency nuisance basis 0.000. The failure modes and fixes are
documented in matlab/hydra_wm_extract.m and hydra_wm_extract_ls.m.
Two embedding/detection bugs were found and fixed during the runs
(band-norm gain scaling; erasure-matched detection); the first
published table in this file's history was a failure (BER ~ 0.5)
and is recorded as such in the run logs' lineage.

## 5. Lean specifications

formal/hydra/HydraSpec.lean — checked with Lean 4.12.0 (core only):
exit 0, no errors, no sorry. Proved: convolution length, the
concrete identity cconv [1,2,3] [4,5,6] = [31,31,28] (the case that
exposed the Rust underflow), delta identity and commutativity
instances, serialization round trip, replay rejection, nonce
uniqueness. Log: results/lean_check.txt.

The Mathlib-based files (formal/Convolution.lean,
formal/Correlation.lean, formal/MemoryLaws.lean) are completed
(2026-10-22 completion pass) and checked with Lean 4.36.0-rc1 +
Mathlib (imports narrowed to the modules used; each file checks
in seconds, exit 0, no sorry — log: results/lean_check_formal.txt).
Defects found in the sketches and repaired, labeled in-file: the
convolution index used truncated Nat subtraction (collapsed to 0
instead of wrapping at k < j); the correlation index was
involuted, and its delta example was false as stated for that
index (at d = 3, a = [0, 1, 0], it gives 0 at k = 1, not 1) — with
the corrected index b (j - k) the example's statement holds and
is proved. Proved: distributivity (the sketches' two examples,
verbatim), left distributivity, zero and scalar laws, delta
identity laws, commutativity, associativity, correlation =
convolution with involuted operand, superposition laws.

## 6. Ada/SPARK control logic (GNAT 13.3.0, contracts enabled)

Log: results/ada_run.txt. Fresh challenge accepted; replayed
challenge rejected; nonces issued strictly increasing (1, 2);
counter exhaustion transitions to Rekey_Required and issues no
nonce (no wrap).

## 7. IDL optical pipeline (executed under GDL 1.0.4)

idl/ contains the IDL procedures (phase screen, angular spectrum
propagation, session experiment). They were executed with GNU
Data Language 1.0.4 (log: results/idl_run.txt): all three modules
compile, and the session experiment reproduces the Fortran path's
behavior — propagated mean intensity conserved at 1.00000 across
sessions, same-state variance 0.11506 at t = 0 evolving to 0.12033
at t = 0.35, other-state variance distinct (0.12126).

## 8. Completion pass (owner-ordered: no placeholders)

All four items ordered on 2026-10-22 are complete locally and
land as a follow-up commit (nothing in sections 1–7 depends on
them):

- cuda/: full CUDA kernel implementation (source) with
  self-verifying host driver — §2 note in cuda/README.md; not
  compiled here (the VM's package lock is held by the runtime's
  own replay and the box has no GPU to run it regardless).
- benchmarks/: harness written against the real kernel API and
  executed — §1 table's chirp-z and capacity numbers are its
  output (results/benchmark.txt).
- examples/: runnable associative-memory example, executed,
  3/3 retrievals (results/example_run.txt).
- formal/: full formalization replacing the sketch files — §5.
