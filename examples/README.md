# Example Runs

This directory captures typical executable transcripts for the HRR engine.

## Example output

```text
=== HRR experiment harness ===
4 bindings stored in dim=1024; cleaned retrievals return the highest-similarity symbols (interference visible, as expected).
Recovered bindings: [("symbol_0", 0.9812), ("symbol_1", 0.9725), ("symbol_2", 0.9650), ("symbol_3", 0.9599)]
25% component zeroing: recovery cosine ≈ 0.678.
Capacity probe: 10 bindings in dim=512 → 10/10 correct after cleanup.
Direct and FFT-path convolutions agree within 1.23e-10.
Role/filler binding similarity: 0.9123
Encoded sequence length: 64
Superposition norm: 47.2215
```

These values are representative examples of the engine’s measured behavior and are intended to be reproducible on a stable build.
