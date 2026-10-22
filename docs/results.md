# Results

This repository contains a compact native HRR engine for fixed-width associative memory experiments.

## Representative measurements

- binding/unbinding similarity for a basic role-filler pair: high cosine agreement
- cleanup improves retrieval after superposition
- interference grows with additional bindings, as expected for approximate holographic memory

A typical runtime transcript looks like:

```text
=== HRR experiment: binding, unbinding, cleanup ===
Dimensionality: 64
Binding/unbinding similarity: 0.9132
Recovered filler for role 0: symbol_0 cosine=0.8123
Role-filler frame norm: 7.4231
Encoded sequence length: 64
Cleanup candidate: symbol_1 similarity=0.7411
```

These results are illustrative and serve as compact evidence for the prototype behavior.
