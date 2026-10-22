# PROJECT HYDRA — Water-Modulated Holographic Cryptography

An experimental extension of this repository's Holographic Memory
Engine: a proof of concept that couples a (simulated) water-modulated
optical front end to holographic vector encoding, entropy assessment,
and standard authenticated encryption.

**Honesty contract.** Everything optical in this repository today is
SIMULATED. Simulated statistics describe the pipeline's behavior;
they are never evidence about physical entropy. Keys are never taken
from raw measurements: optical features pass through a cryptographic
conditioning function and HKDF, and the derived length is bounded by
assessed min-entropy. HRR binding is a distributed representation,
not encryption. Confidentiality and integrity come only from the
AEAD layer (ChaCha20-Poly1305, RFC 8439).

## Pipeline

```
coherent source -> modulator -> WATER CHAMBER -> diffraction/phase
-> image sensor -> feature extraction -> HRR encoder -> entropy
assessment -> conditioning (SHA-256) -> HKDF -> AEAD -> ciphertext
```

## Physical design (for the hardware build)

- Source: low-power laser diode or narrowband LED in a fully
  enclosed beam path (interlocked enclosure, no exposed beam;
  design target Class 1 under IEC 60825 with the enclosure closed).
- Modulator: a fixed phase plate or low-cost SLM for challenge
  patterns (the challenge selects illumination configuration).
- Water chamber: sealed optical cuvette, distilled water, one
  free surface driven by a small piezo actuator for repeatable
  surface-wave excitation; temperature logged (refractive index of
  water drifts ~ -1e-4 / degC, a first-order term, not noise to be
  ignored).
- Sensor: monochrome CMOS, fixed exposure/gain during a session
  (auto-exposure would inject the vendor's AGC as a hidden state
  variable — unacceptable for repeatability measurements).
- All electronics outside the beam enclosure except the sensor.

## Optical model and approximations

Phase through the chamber (thin-screen surface-relief model):

  phi(x,y,t) = (2 pi / lambda) * (n_water - n_air) * h(x,y,t)

where h is the surface height, modeled as a finite sum of sinusoidal
modes with gravity-wave dispersion omega^2 = g |k| and amplitudes
decaying exponentially in |k|. The transmitted field is
E_out = A * exp(i phi), propagated to the detector by the angular
spectrum method with evanescent components removed.

Approximations, stated plainly:
1. Surface relief only. Volume refractive-index fluctuations
   (temperature microstructure) are folded into the effective surface
   term; a two-medium integral model is future work.
2. Thin screen: all phase is imparted in one plane.
3. Scalar, monochromatic, paraxial-free propagation (angular
   spectrum is exact for the scalar Helmholtz equation; the scalar
   and monochromatic assumptions are the approximations).
4. Simulated frames contain no sensor read noise model beyond the
   quantization stage; the hardware backend must add measured noise.

## Language architecture (as mandated for this project)

- Rust — this repository's HRR engine (pre-existing).
- Fortran 2018 + BLAS/LAPACK — the low-level kernels: circular
  convolution/correlation (chirp-z DFT at D = 10000), superposition
  (DAXPY), similarity (DDOT/DNRM2), cleanup search (DGEMV), angular
  spectrum propagation, and the full cryptographic protocol
  (SHA-256, HKDF, ChaCha20-Poly1305) in `fortran/`.
- MATLAB — the holographic watermark prototype in `matlab/`
  (frequency-domain global embedding; runs under GNU Octave).
- IDL — the optical imaging pipeline in `idl/` (GDL-compatible).
- Lean 4 — deterministic-logic specifications in `formal/hydra/`.
- Ada/SPARK — bounded control logic (nonce counter, challenge
  registry) in `ada/`.

## What is demonstrated vs hypothesized

Demonstrated (see docs/hydra-results.md for the measured runs):
- HRR binding/unbinding/cleanup at D = 10000 in the Fortran kernels,
  cross-checked against this repo's own Fortran reference.
- End-to-end simulated sessions: frames -> features -> conditioning
  -> HKDF -> AEAD seal/open; replayed challenges rejected; tampered
  ciphertexts rejected.
- Frequency-domain watermark surviving a crop-in-half attack at
  reduced confidence (the holographic property, measured).
- Entropy statistics of the simulated source next to an OS CSPRNG
  baseline, computed by identical code.

Hypotheses (NOT demonstrated): that a physical water chamber yields
entropy an attacker with full knowledge of the apparatus cannot
predict; that responses are unclonable. Both require hardware,
a defined attacker model, and measurements this repository does
not contain. The simulated source is a deterministic generator:
against an attacker who knows the seed it has exactly zero entropy,
and the conditioning pipeline is designed to remain sound hygiene
regardless — it cannot create entropy that is not there.
